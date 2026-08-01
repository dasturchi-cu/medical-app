import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../core/config/api_config.dart';
import '../core/data/models/comment_models.dart';
import '../core/services/course_stats_cache.dart';
import '../core/services/guest_identity.dart';
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
  String? _statsUserId;
  bool _feedbackApiMissing = false;
  String? _replyToCommentId;
  bool _statsLoading = true;
  String? _statsError;
  final Map<String, bool> _optimisticLikedByMe = <String, bool>{};
  final Map<String, int> _optimisticLikesCount = <String, int>{};
  final List<AppCommentItem> _optimisticComments = [];

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
    Future.microtask(() => _bootstrapForCurrentUser(forceRefresh: true));
  }

  String _ratingPhone() => (ref.read(authControllerProvider).email ?? '').trim();

  /// Logged-in users use their real id; everyone else uses a stable
  /// per-device guest id (never empty, never shared across devices/courses)
  /// so ratings/comments/likes work — and stay consistent — without login.
  String _effectiveUserId() {
    final raw = (ref.read(authControllerProvider).userId ?? '').trim();
    return raw.isNotEmpty ? raw : GuestIdentity.id;
  }

  Future<int> _resolveMyRating({
    required String userId,
    int? fromServer,
  }) async {
    if (fromServer != null && fromServer >= 1 && fromServer <= 5) {
      return fromServer;
    }
    final memory = CourseStatsCache.peekMyRating(
      key: widget.courseId,
      userId: userId,
      useFeedbackApi: widget.useFeedbackApi,
    );
    if (memory != null && memory >= 1) return memory;
    final persisted = await CourseStatsCache.readPersistedMyRating(
      key: widget.courseId,
      userId: userId,
      useFeedbackApi: widget.useFeedbackApi,
      phone: _ratingPhone(),
    );
    if (persisted != null && persisted >= 1) return persisted;
    if (_myRating >= 1) return _myRating;
    return 0;
  }

  Future<void> _bootstrapForCurrentUser({bool forceRefresh = false}) async {
    final userId = _effectiveUserId();
    if (!forceRefresh && _statsUserId == userId && !_statsLoading) {
      await _hydrateMyRating();
      return;
    }
    _statsUserId = userId;
    await _hydrateMyRating();
    await _loadCourseStats(forceRefresh: forceRefresh);
  }

  Future<void> _hydrateMyRating() async {
    final userId = _effectiveUserId();
    if (userId.isEmpty || widget.courseId.trim().isEmpty) return;
    final memory = CourseStatsCache.peekMyRating(
      key: widget.courseId,
      userId: userId,
      useFeedbackApi: widget.useFeedbackApi,
    );
    final persisted = memory ??
        await CourseStatsCache.readPersistedMyRating(
          key: widget.courseId,
          userId: userId,
          useFeedbackApi: widget.useFeedbackApi,
          phone: _ratingPhone(),
        );
    if (persisted == null || persisted < 1 || persisted > 5 || !mounted) return;
    setState(() => _myRating = persisted);
    CourseStatsCache.putMyRating(
      key: widget.courseId,
      userId: userId,
      myRating: persisted,
      useFeedbackApi: widget.useFeedbackApi,
      phone: _ratingPhone(),
    );
  }

  @override
  void didUpdateWidget(covariant CourseStatsCommentsSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.courseId != widget.courseId) {
      unawaited(_bootstrapForCurrentUser(forceRefresh: true));
    }
  }


  Future<void> _loadCourseStats({bool forceRefresh = false}) async {
    final baseUrl = getApiBaseUrl();
    final userId = _effectiveUserId();
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
        if (cachedMyRating != null && cachedMyRating >= 1) {
          _myRating = cachedMyRating.clamp(1, 5);
        }
        _statsLoading = false;
        _statsError = null;
      });
      if (cachedMyRating == null && userId.isNotEmpty) {
        unawaited(_hydrateMyRating());
      }
    } else if (mounted) {
      setState(() {
        if (cachedMyRating != null && cachedMyRating >= 1) {
          _myRating = cachedMyRating.clamp(1, 5);
        }
        _statsLoading = true;
        _statsError = null;
      });
      if (cachedMyRating == null && userId.isNotEmpty) {
        unawaited(_hydrateMyRating());
      }
    }

    try {
      int? fetchedMyRating;
      int? fetchedEnrolled;
      final stats = await CourseStatsCache.statsOrFetch(
        key: widget.courseId,
        userId: userId,
        useFeedbackApi: widget.useFeedbackApi,
        forceRefresh: forceRefresh,
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
          if (rawMy != null) {
            final parsed = int.tryParse(rawMy.toString());
            if (parsed != null && parsed >= 1 && parsed <= 5) {
              fetchedMyRating = parsed;
            }
          }
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
              phone: _ratingPhone(),
            );
          }
          return stats;
        },
      );
      if (!mounted) return;
      final resolvedMyRating = userId.isEmpty
          ? 0
          : await _resolveMyRating(userId: userId, fromServer: fetchedMyRating);
      if (!mounted) return;
      setState(() {
        _commentsCount = stats.commentsCount;
        _commentersCount = stats.commentersCount;
        _ratingAvg = stats.ratingAvg;
        _ratingCount = stats.ratingCount;
        _myRating = resolvedMyRating;
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
    final userId = _effectiveUserId();
    final baseUrl = getApiBaseUrl();
    if (baseUrl.isEmpty || widget.courseId.trim().isEmpty) return;

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
      phone: _ratingPhone(),
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
      // Optimistic komenti endi serverdan kelgan ma'lumot bilan almashtiriladi
      if (mounted) {
        setState(() => _optimisticComments.clear());
      }
      ref.invalidate(courseCommentsFeedProvider((courseKey: widget.courseId, userId: userId)));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _commentsCount = (_commentsCount - 1).clamp(0, 1 << 30);
        _optimisticComments.clear();
      });
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
      if (mounted) {
        setState(() => _optimisticComments.removeWhere((c) => c.parentId == comment.id));
      }
      ref.invalidate(courseCommentsFeedProvider((courseKey: widget.courseId, userId: userId)));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _commentsCount = (_commentsCount - 1).clamp(0, 1 << 30);
        _optimisticComments.removeWhere((c) => c.parentId == comment.id);
      });
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
    ref.listen<AuthState>(authControllerProvider, (prev, next) {
      final prevId = (prev?.userId ?? '').trim();
      final nextId = (next.userId ?? '').trim();
      if (prevId == nextId) return;
      if (nextId.isEmpty) {
        if (mounted) setState(() => _myRating = 0);
        _statsUserId = null;
      }
      unawaited(_bootstrapForCurrentUser(forceRefresh: true));
    });

    final auth = ref.watch(authControllerProvider);
    final rawUserId = (auth.userId ?? '').trim();
    final userId = rawUserId.isNotEmpty ? rawUserId : GuestIdentity.id;
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
        child: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
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
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 4,
              children: [
                Text(
                  _myRating > 0 ? 'Sizning bahongiz:' : 'Baholash:',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 1; i <= 5; i++)
                      QuickTap(
                        enabled: !_feedbackApiMissing,
                        minSize: 32,
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
                  // Optimistic komentilarni server ro'yxatiga qo'shish (dublikatsiz)
                  final serverIds = {for (final c in comments) c.id};
                  final merged = [
                    ...comments,
                    ..._optimisticComments.where((c) => !serverIds.contains(c.id)),
                  ];
                  final visibleComments = merged;
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
                                              // Optimistic UI: javob darhol ko'rsatish
                                              final replyOptId = 'opt_${DateTime.now().millisecondsSinceEpoch}';
                                              setState(() {
                                                _commentsCount += 1;
                                                _optimisticComments.add(AppCommentItem(
                                                  id: replyOptId,
                                                  courseKey: widget.courseId,
                                                  userId: userId,
                                                  authorName: authorName,
                                                  text: text,
                                                  parentId: c.id,
                                                  repliesCount: 0,
                                                  likesCount: 0,
                                                  likedByMe: false,
                                                  likedByAdmin: false,
                                                  createdAt: DateTime.now(),
                                                ));
                                              });
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
                            // Optimistic UI: komenti darhol ko'rsatish
                            final optimisticId = 'opt_${DateTime.now().millisecondsSinceEpoch}';
                            setState(() {
                              _commentsCount += 1;
                              _optimisticComments.add(AppCommentItem(
                                id: optimisticId,
                                courseKey: widget.courseId,
                                userId: userId,
                                authorName: authorName,
                                text: text,
                                parentId: null,
                                repliesCount: 0,
                                likesCount: 0,
                                likedByMe: false,
                                likedByAdmin: false,
                                createdAt: DateTime.now(),
                              ));
                            });
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
            ),   // Row end
          ],     // Column.children end
        ),       // Column end
      ),         // SingleChildScrollView end
    ),           // Padding end
  );             // SafeArea end
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
