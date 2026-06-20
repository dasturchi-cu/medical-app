import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../core/config/api_config.dart';
import '../core/data/models/comment_models.dart';
import '../core/services/course_stats_cache.dart';
import '../core/state/auth_controller.dart';
import '../core/di/providers.dart';
import '../core/state/comments_state.dart';
import '../core/state/course_stats_state.dart';
import '../core/state/progress_controller.dart';
import '../core/widgets/quick_tap.dart';

class CourseStatsCommentsSheet extends ConsumerStatefulWidget {
  const CourseStatsCommentsSheet({
    super.key,
    required this.courseId,
    required this.courseTitleUz,
    this.useFeedbackApi = false,
    this.showEnrolledStat = true,
  });

  final String courseId;
  final String courseTitleUz;
  final bool useFeedbackApi;
  /// Masalan, bosh sahifada «Nevralogiya» bo‘limida ro‘yxatdan o‘tganlar soni ko‘rsatilmasin.
  final bool showEnrolledStat;

  @override
  ConsumerState<CourseStatsCommentsSheet> createState() => _CourseStatsCommentsSheetState();
}

class _CourseStatsCommentsSheetState extends ConsumerState<CourseStatsCommentsSheet> {
  final _controller = TextEditingController();
  final _replyController = TextEditingController();
  int _enrolledCount = 0;
  int _commentsCount = 0;
  int _commentersCount = 0;
  double _ratingAvg = 0;
  int _ratingCount = 0;
  int _myRating = 0;
  bool _feedbackApiMissing = false;
  String? _replyToCommentId;
  bool _statsLoading = true;
  String? _statsError;
  List<AppCommentItem>? _commentsSnapshot;
  final Map<String, bool> _optimisticLikedByMe = <String, bool>{};
  final Map<String, int> _optimisticLikesCount = <String, int>{};

  void _setCardStatsOverride({
    required double ratingAvg,
    required int ratingCount,
    required int commentsCount,
    required int commentersCount,
  }) {
    final stats = CourseCardStats(
      ratingAvg: ratingAvg.clamp(0, 5).toDouble(),
      ratingCount: ratingCount < 0 ? 0 : ratingCount,
      commentsCount: commentsCount < 0 ? 0 : commentsCount,
      commentersCount: commentersCount < 0 ? 0 : commentersCount,
    );
    if (widget.useFeedbackApi) {
      ref.read(contentCardStatsOverrideProvider.notifier).update((state) => {
            ...state,
            widget.courseId: stats,
          });
      CourseStatsCache.putStats(
        key: widget.courseId,
        userId: ref.read(authControllerProvider).userId ?? '',
        stats: stats,
        useFeedbackApi: true,
      );
      return;
    }
    ref.read(courseCardStatsOverrideProvider.notifier).update((state) => {
          ...state,
          widget.courseId: stats,
        });
    CourseStatsCache.putStats(
      key: widget.courseId,
      userId: ref.read(authControllerProvider).userId ?? '',
      stats: stats,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _replyController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadCourseStats();
  }

  @override
  void didUpdateWidget(covariant CourseStatsCommentsSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.courseId != widget.courseId) {
      _commentsSnapshot = null;
      _loadCourseStats();
    }
  }

  Future<void> _refreshCommentsNow(String userId) async {
    try {
      final latest = await ref.read(commentsRepositoryProvider).fetchComments(
            courseKey: widget.courseId,
            userId: userId,
            forceRefresh: true,
          );
      if (!mounted) return;
      final root = latest.where((item) => item.parentId == null || item.parentId!.isEmpty);
      final commenters = {
        for (final item in root) item.userId.trim(),
      }.where((id) => id.isNotEmpty).length;
      setState(() {
        _commentsSnapshot = latest;
        _commentersCount = commenters;
      });
      _setCardStatsOverride(
        ratingAvg: _ratingAvg,
        ratingCount: _ratingCount,
        commentsCount: _commentsCount,
        commentersCount: _commentersCount,
      );
    } catch (_) {}
  }

  Future<void> _loadCourseStats() async {
    final baseUrl = getApiBaseUrl();
    final userId = (ref.read(authControllerProvider).userId ?? '').trim();
    if (baseUrl.isEmpty || widget.courseId.trim().isEmpty) {
      if (mounted) setState(() => _statsLoading = false);
      return;
    }

    final cached = CourseStatsCache.peekStats(
      key: widget.courseId,
      userId: userId,
      useFeedbackApi: widget.useFeedbackApi,
    );
    final cachedMyRating = CourseStatsCache.peekMyRating(
      key: widget.courseId,
      userId: userId,
      useFeedbackApi: widget.useFeedbackApi,
    );
    if (cached != null && mounted) {
      setState(() {
        _commentsCount = cached.commentsCount;
        _commentersCount = cached.commentersCount;
        _ratingAvg = cached.ratingAvg;
        _ratingCount = cached.ratingCount;
        if (cachedMyRating != null) {
          _myRating = cachedMyRating.clamp(0, 5);
        }
        _statsLoading = false;
        _statsError = null;
      });
    } else if (mounted) {
      setState(() {
        if (cachedMyRating != null) {
          _myRating = cachedMyRating.clamp(0, 5);
        }
        _statsLoading = true;
        _statsError = null;
      });
    }

    try {
      int? fetchedMyRating;
      int? fetchedEnrolled;
      final stats = await CourseStatsCache.statsOrFetch(
        key: widget.courseId,
        userId: userId,
        useFeedbackApi: widget.useFeedbackApi,
        fetch: () async {
          final statsUri = widget.useFeedbackApi
              ? Uri.parse('$baseUrl/api/v1/feedback/${widget.courseId}/stats').replace(
                  queryParameters: userId.isEmpty ? null : {'user_id': userId},
                )
              : Uri.parse('$baseUrl/api/v1/courses/${widget.courseId}/stats').replace(
                  queryParameters: userId.isEmpty ? null : {'user_id': userId},
                );
          debugPrint('[API][courses.stats][request] uri=$statsUri');
          final response = await http.get(statsUri).timeout(const Duration(seconds: 12));
          debugPrint('[API][courses.stats][response] status=${response.statusCode}');
          if (widget.useFeedbackApi && response.statusCode == 404) {
            throw _FeedbackApiMissingException();
          }
          if (response.statusCode < 200 || response.statusCode >= 300) {
            throw Exception('Kurs statistikasi yuklanmadi (${response.statusCode}).');
          }
          final body = jsonDecode(response.body);
          if (body is! Map<String, dynamic>) {
            throw Exception("Statistika JSON emas.");
          }
          final rawMy = body['my_rating'] ?? body['myRating'];
          fetchedMyRating = rawMy == null ? 0 : (int.tryParse(rawMy.toString()) ?? 0);
          if (!widget.useFeedbackApi) {
            fetchedEnrolled = int.tryParse((body['enrolled_count'] ?? '0').toString()) ?? 0;
          }
          final stats = CourseCardStats(
            ratingAvg: double.tryParse((body['rating_avg'] ?? '0').toString()) ?? 0,
            ratingCount: int.tryParse((body['rating_count'] ?? '0').toString()) ?? 0,
            commentsCount: int.tryParse((body['comments_count'] ?? '0').toString()) ?? 0,
            commentersCount: int.tryParse((body['commenters_count'] ?? '0').toString()) ?? 0,
          );
          if (fetchedMyRating != null) {
            CourseStatsCache.putMyRating(
              key: widget.courseId,
              userId: userId,
              myRating: fetchedMyRating!,
              useFeedbackApi: widget.useFeedbackApi,
            );
          }
          return stats;
        },
      );
      if (!mounted) return;
      setState(() {
        _commentsCount = stats.commentsCount;
        _commentersCount = stats.commentersCount;
        _ratingAvg = stats.ratingAvg;
        _ratingCount = stats.ratingCount;
        if (fetchedMyRating != null) _myRating = fetchedMyRating!;
        if (fetchedEnrolled != null) _enrolledCount = fetchedEnrolled!;
        _statsLoading = false;
        _statsError = null;
        _feedbackApiMissing = false;
      });
    } on _FeedbackApiMissingException {
      if (!mounted) return;
      setState(() {
        _statsLoading = false;
        _statsError = null;
        _feedbackApiMissing = true;
      });
    } catch (error) {
      debugPrint('[API][courses.stats][error] $error');
      if (!mounted) return;
      setState(() {
        _statsLoading = false;
        _statsError = error.toString();
      });
    }
  }

  Future<void> _onStarTap(int stars) async {
    if (_feedbackApiMissing) return;
    final auth = ref.read(authControllerProvider);
    final userId = (auth.userId ?? '').trim();
    final baseUrl = getApiBaseUrl();
    if (userId.isEmpty || baseUrl.isEmpty || widget.courseId.trim().isEmpty) return;

    final prevMy = _myRating;
    final prevCount = _ratingCount;
    final prevAvg = _ratingAvg;
    _applyRatingOptimistic(stars, userId: userId);

    try {
      final ratePath = widget.useFeedbackApi
          ? '/api/v1/feedback/${widget.courseId}/rate'
          : '/api/v1/courses/${widget.courseId}/rate';
      final response = await http
          .post(
            Uri.parse('$baseUrl$ratePath'),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({'user_id': userId, 'stars': stars}),
          )
          .timeout(const Duration(seconds: 12));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        if (widget.useFeedbackApi && response.statusCode == 404) {
          throw Exception('Feedback API hali backendda yoq. Backendni yangilang.');
        }
        var msg = 'Baholash rad etildi (${response.statusCode}).';
        try {
          final b = jsonDecode(response.body);
          if (b is Map && b['detail'] != null) msg = b['detail'].toString();
        } catch (_) {}
        throw Exception(msg);
      }
    } catch (e) {
      if (!mounted) return;
      _applyRatingOptimistic(prevMy, userId: userId, count: prevCount, avg: prevAvg);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  void _applyRatingOptimistic(
    int stars, {
    required String userId,
    int? count,
    double? avg,
  }) {
    final int nextCount;
    final double nextAvg;
    if (count != null && avg != null) {
      nextCount = count;
      nextAvg = avg;
    } else {
      final prevMy = _myRating;
      final prevCount = _ratingCount;
      final prevAvg = _ratingAvg;
      final isNewVote = prevMy == 0 && stars > 0;
      nextCount = isNewVote ? prevCount + 1 : prevCount;
      nextAvg = nextCount == 0
          ? stars.toDouble()
          : (((prevAvg * prevCount) - prevMy + stars) / nextCount);
    }

    setState(() {
      _myRating = stars;
      _ratingCount = nextCount;
      _ratingAvg = nextAvg.clamp(0, 5).toDouble();
    });
    CourseStatsCache.putMyRating(
      key: widget.courseId,
      userId: userId,
      myRating: stars,
      useFeedbackApi: widget.useFeedbackApi,
    );
    _setCardStatsOverride(
      ratingAvg: nextAvg,
      ratingCount: nextCount,
      commentsCount: _commentsCount,
      commentersCount: _commentersCount,
    );
  }

  Future<void> _toggleLike({
    required AppCommentItem comment,
    required String userId,
    required bool likedByMe,
    required int likesCount,
  }) async {
    final nextLiked = !likedByMe;
    final nextCount = nextLiked ? likesCount + 1 : (likesCount > 0 ? likesCount - 1 : 0);
    setState(() {
      _optimisticLikedByMe[comment.id] = nextLiked;
      _optimisticLikesCount[comment.id] = nextCount;
    });
    try {
      await ref.read(commentsRepositoryProvider).toggleLike(
            commentId: comment.id,
            userId: userId,
            courseKey: widget.courseId,
            likedByMe: nextLiked,
            likesCount: nextCount,
          );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _optimisticLikedByMe.remove(comment.id);
        _optimisticLikesCount.remove(comment.id);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().contains('SocketException') ||
                    e.toString().contains('ClientException') ||
                    e.toString().contains('TimeoutException')
                ? 'Like saqlanmadi. Internet ulanishini tekshiring.'
                : 'Like saqlanmadi: ${e.toString()}',
          ),
        ),
      );
    }
  }

  Future<void> _sendComment({
    required String text,
    required String userId,
    required String authorName,
  }) async {
    try {
      await ref.read(commentsRepositoryProvider).addComment(
            courseKey: widget.courseId,
            userId: userId,
            authorName: authorName,
            text: text,
          );
      await _refreshCommentsNow(userId);
    } catch (e) {
      if (!mounted) return;
      setState(() => _commentsCount = (_commentsCount - 1).clamp(0, 1 << 30));
      _setCardStatsOverride(
        ratingAvg: _ratingAvg,
        ratingCount: _ratingCount,
        commentsCount: _commentsCount,
        commentersCount: _commentersCount,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  Future<void> _sendReply({
    required AppCommentItem comment,
    required String text,
    required String userId,
    required String authorName,
  }) async {
    _replyController.clear();
    if (mounted) setState(() => _replyToCommentId = null);
    try {
      await ref.read(commentsRepositoryProvider).addReply(
            commentId: comment.id,
            userId: userId,
            authorName: authorName,
            text: text,
          );
      await _refreshCommentsNow(userId);
    } catch (e) {
      if (!mounted) return;
      setState(() => _commentsCount = (_commentsCount - 1).clamp(0, 1 << 30));
      _setCardStatsOverride(
        ratingAvg: _ratingAvg,
        ratingCount: _ratingCount,
        commentsCount: _commentsCount,
        commentersCount: _commentersCount,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final userId = auth.userId ?? '';
    final hasCourseId = widget.courseId.trim().isNotEmpty;

    if (!hasCourseId) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.courseTitleUz,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 10),
              const Text("Bu reklama kursga ulanmagan. Izoh va baholash uchun kurs tanlangan bo'lishi kerak."),
            ],
          ),
        ),
      );
    }

    final commentsAsync = ref.watch(
      courseCommentsFeedProvider((courseKey: widget.courseId, userId: userId)),
    );
    final progress = ref.watch(progressControllerProvider).byCourseId[widget.courseId];
    final completed = progress?.completedLessonIds.length ?? 0;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 12,
          bottom: 16 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              widget.courseTitleUz,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 10),
            if (_statsLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))),
              )
            else if (_statsError != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  _statsError!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.red.shade800, fontWeight: FontWeight.w600),
                ),
              )
            else if (widget.useFeedbackApi)
              Wrap(
                spacing: 10,
                runSpacing: 8,
                children: [
                  _StatChip(
                    icon: Icons.chat_bubble_outline,
                    label: '$_commentsCount izoh',
                  ),
                  _StatChip(
                    icon: Icons.star_border,
                    label: '$_ratingCount baho',
                  ),
                ],
              )
            else
              Wrap(
                spacing: 10,
                runSpacing: 8,
                children: [
                  if (widget.showEnrolledStat)
                    _StatChip(
                      icon: Icons.people_alt_outlined,
                      label: '$_enrolledCount kishi',
                    ),
                  _StatChip(
                    icon: Icons.check_circle_outline,
                    label: '$completed yakunlangan',
                  ),
                  _StatChip(
                    icon: Icons.chat_bubble_outline,
                    label: '$_commentsCount izoh',
                  ),
                ],
              ),
            const SizedBox(height: 10),
            Row(
              children: [
                Text(
                  'Baholash:',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(width: 8),
                for (var i = 1; i <= 5; i++)
                  QuickTap(
                    enabled: !_feedbackApiMissing,
                    minSize: 40,
                    splashColor: Colors.amber.withValues(alpha: 0.18),
                    highlightColor: Colors.amber.withValues(alpha: 0.1),
                    onTap: () => unawaited(_onStarTap(i)),
                    child: Icon(
                      i <= _myRating ? Icons.star_rounded : Icons.star_border_rounded,
                      color: i <= _myRating ? Colors.amber.shade700 : Colors.amber.shade600,
                      size: 24,
                    ),
                  ),
                const SizedBox(width: 4),
                Text(
                  '${_ratingAvg.toStringAsFixed(1)} ($_ratingCount)',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.black54,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
            if (_feedbackApiMissing)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'Yulduzcha baholash backendga hali deploy qilinmagan (feedback endpoint 404).',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.red.shade800,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
            const SizedBox(height: 12),
            Text(
              'Izohlar',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 260),
              child: commentsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, _) => const Center(child: Text('Izohlarni yuklashda xatolik.')),
                data: (comments) {
                  final visibleComments = _commentsSnapshot ?? comments;
                  final rootComments = visibleComments.where((item) => item.parentId == null || item.parentId!.isEmpty).toList(growable: true)
                    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
                  final repliesByParent = <String, List<AppCommentItem>>{};
                  for (final item in visibleComments.where((item) => item.parentId != null && item.parentId!.isNotEmpty)) {
                    repliesByParent.putIfAbsent(item.parentId!, () => <AppCommentItem>[]).add(item);
                  }
                  for (final list in repliesByParent.values) {
                    list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
                  }
                  if (rootComments.isEmpty) {
                    return Text(
                      'Hozircha izoh yo‘q',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.black54,
                          ),
                    );
                  }
                  return ListView.separated(
                    shrinkWrap: true,
                    itemCount: rootComments.length,
                    separatorBuilder: (_, index) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final c = rootComments[i];
                      final replies = repliesByParent[c.id] ?? const <AppCommentItem>[];
                      final showReplyInput = _replyToCommentId == c.id;
                      final likedByMe = _optimisticLikedByMe[c.id] ?? c.likedByMe;
                      final likesCount = _optimisticLikesCount[c.id] ?? c.likesCount;
                      return Card(
                        margin: EdgeInsets.zero,
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                c.authorName,
                                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                      fontWeight: FontWeight.w900,
                                    ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                c.text,
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  QuickTap(
                                    enabled: userId.isNotEmpty,
                                    minSize: 40,
                                    splashColor: Colors.red.withValues(alpha: 0.12),
                                    onTap: () => unawaited(
                                      _toggleLike(
                                        comment: c,
                                        userId: userId,
                                        likedByMe: likedByMe,
                                        likesCount: likesCount,
                                      ),
                                    ),
                                    child: Icon(
                                      likedByMe ? Icons.favorite : Icons.favorite_border,
                                      size: 20,
                                      color: likedByMe ? Colors.red.shade600 : Colors.black45,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text('$likesCount'),
                                  if (c.likedByAdmin) ...[
                                    const SizedBox(width: 10),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.blue.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(999),
                                      ),
                                      child: Text(
                                        'Admin like bosdi',
                                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                              color: Colors.blue.shade700,
                                              fontWeight: FontWeight.w700,
                                            ),
                                      ),
                                    ),
                                  ],
                                  const SizedBox(width: 12),
                                  TextButton(
                                    onPressed: userId.isEmpty
                                        ? null
                                        : () {
                                            setState(() {
                                              _replyToCommentId = showReplyInput ? null : c.id;
                                              if (!showReplyInput) {
                                                _replyController.clear();
                                              }
                                            });
                                          },
                                    child: Text('Javob (${c.repliesCount})'),
                                  ),
                                ],
                              ),
                              if (showReplyInput) ...[
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: _replyController,
                                        decoration: const InputDecoration(
                                          hintText: 'Javob yozing...',
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    FilledButton(
                                      onPressed: userId.isEmpty
                                          ? null
                                          : () {
                                              final text = _replyController.text.trim();
                                              if (text.isEmpty) return;
                                              final authorName = auth.name.trim().isEmpty
                                                  ? 'Foydalanuvchi'
                                                  : auth.name.trim();
                                              setState(() => _commentsCount += 1);
                                              _setCardStatsOverride(
                                                ratingAvg: _ratingAvg,
                                                ratingCount: _ratingCount,
                                                commentsCount: _commentsCount,
                                                commentersCount: _commentersCount,
                                              );
                                              unawaited(
                                                _sendReply(
                                                  comment: c,
                                                  text: text,
                                                  userId: userId,
                                                  authorName: authorName,
                                                ),
                                              );
                                            },
                                      child: const Text('Javob'),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                              ],
                              if (replies.isNotEmpty)
                                Container(
                                  margin: const EdgeInsets.only(top: 6),
                                  padding: const EdgeInsets.only(left: 10),
                                  decoration: BoxDecoration(
                                    border: Border(
                                      left: BorderSide(color: Colors.black.withValues(alpha: 0.12)),
                                    ),
                                  ),
                                  child: Column(
                                    children: replies
                                        .map(
                                          (reply) => Padding(
                                            padding: const EdgeInsets.only(bottom: 8),
                                            child: Row(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(
                                                        reply.authorName,
                                                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                                              fontWeight: FontWeight.w800,
                                                            ),
                                                      ),
                                                      const SizedBox(height: 2),
                                                      Text(reply.text),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        )
                                        .toList(growable: false),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      hintText: 'Izoh yozing...',
                      prefixIcon: Icon(Icons.edit_outlined),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  height: 48,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF1E6BB8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: userId.isEmpty
                        ? null
                        : () {
                            final text = _controller.text.trim();
                            if (text.isEmpty) return;
                            final authorName = auth.name.trim().isEmpty
                                ? 'Foydalanuvchi'
                                : auth.name.trim();
                            _controller.clear();
                            setState(() => _commentsCount += 1);
                            _setCardStatsOverride(
                              ratingAvg: _ratingAvg,
                              ratingCount: _ratingCount,
                              commentsCount: _commentsCount,
                              commentersCount: _commentersCount,
                            );
                            unawaited(
                              _sendComment(
                                text: text,
                                userId: userId,
                                authorName: authorName,
                              ),
                            );
                          },
                    child: const Text(
                      'Yuborish',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: const Color(0xFF1E6BB8)),
          const SizedBox(width: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
        ],
      ),
    );
  }
}

class _FeedbackApiMissingException implements Exception {}
