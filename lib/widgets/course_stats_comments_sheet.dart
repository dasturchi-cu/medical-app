import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../core/config/api_config.dart';
import '../core/state/auth_controller.dart';
import '../core/di/providers.dart';
import '../core/state/comments_state.dart';
import '../core/state/progress_controller.dart';

class CourseStatsCommentsSheet extends ConsumerStatefulWidget {
  const CourseStatsCommentsSheet({
    super.key,
    required this.courseId,
    required this.courseTitleUz,
  });

  final String courseId;
  final String courseTitleUz;

  @override
  ConsumerState<CourseStatsCommentsSheet> createState() => _CourseStatsCommentsSheetState();
}

class _CourseStatsCommentsSheetState extends ConsumerState<CourseStatsCommentsSheet> {
  final _controller = TextEditingController();
  int _enrolledCount = 0;
  int _commentsCount = 0;
  double _ratingAvg = 0;
  int _ratingCount = 0;
  int _myRating = 0;
  bool _sending = false;
  bool _ratingLoading = false;

  @override
  void dispose() {
    _controller.dispose();
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
      _loadCourseStats();
    }
  }

  Future<void> _loadCourseStats() async {
    final baseUrl = getApiBaseUrl();
    if (baseUrl.isEmpty || widget.courseId.trim().isEmpty) return;
    try {
      final auth = ref.read(authControllerProvider);
      final userId = auth.userId ?? '';
      final response = await http.get(Uri.parse('$baseUrl/api/v1/courses/${widget.courseId}/stats?user_id=$userId'));
      if (response.statusCode < 200 || response.statusCode >= 300) return;
      final body = jsonDecode(response.body);
      if (body is! Map<String, dynamic>) return;
      final enrolled = int.tryParse((body['enrolled_count'] ?? '0').toString()) ?? 0;
      final comments = int.tryParse((body['comments_count'] ?? '0').toString()) ?? 0;
      final ratingAvg = double.tryParse((body['rating_avg'] ?? '0').toString()) ?? 0;
      final ratingCount = int.tryParse((body['rating_count'] ?? '0').toString()) ?? 0;
      final myRating = int.tryParse((body['my_rating'] ?? '0').toString()) ?? 0;
      if (!mounted) return;
      setState(() {
        _enrolledCount = enrolled;
        _commentsCount = comments;
        _ratingAvg = ratingAvg;
        _ratingCount = ratingCount;
        _myRating = myRating;
      });
    } catch (_) {}
  }

  Future<void> _submitRating(int stars) async {
    final auth = ref.read(authControllerProvider);
    final userId = auth.userId ?? '';
    final baseUrl = getApiBaseUrl();
    if (userId.isEmpty || baseUrl.isEmpty || widget.courseId.trim().isEmpty) return;
    setState(() => _ratingLoading = true);
    try {
      await http.post(
        Uri.parse('$baseUrl/api/v1/courses/${widget.courseId}/rate'),
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode({'user_id': userId, 'stars': stars}),
      );
      if (!mounted) return;
      setState(() => _myRating = stars);
      await _loadCourseStats();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Yulduzcha bahoda xatolik.")),
      );
    } finally {
      if (mounted) setState(() => _ratingLoading = false);
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
            Row(
              children: [
                _StatChip(
                  icon: Icons.people_alt_outlined,
                  label: '$_enrolledCount talaba',
                ),
                const SizedBox(width: 10),
                _StatChip(
                  icon: Icons.check_circle_outline,
                  label: '$completed yakunlangan',
                ),
                const SizedBox(width: 10),
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
                  IconButton(
                    onPressed: _ratingLoading ? null : () => _submitRating(i),
                    icon: Icon(
                      i <= _myRating ? Icons.star : Icons.star_border,
                      color: Colors.amber,
                    ),
                    visualDensity: VisualDensity.compact,
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
                data: (comments) => ListView.separated(
                  shrinkWrap: true,
                  itemCount: max(1, comments.length),
                  separatorBuilder: (_, index) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    if (comments.isEmpty) {
                      return Text(
                        'Hozircha izoh yo‘q',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.black54,
                            ),
                      );
                    }
                    final c = comments[i];
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
                                IconButton(
                                  onPressed: userId.isEmpty
                                      ? null
                                      : () async {
                                          try {
                                            await ref.read(commentsRepositoryProvider).toggleLike(
                                              commentId: c.id,
                                              userId: userId,
                                            );
                                            ref.invalidate(
                                              courseCommentsFeedProvider((courseKey: widget.courseId, userId: userId)),
                                            );
                                          } catch (_) {}
                                        },
                                  icon: Icon(
                                    c.likedByMe ? Icons.favorite : Icons.favorite_border,
                                    size: 18,
                                    color: c.likedByMe ? Colors.red : Colors.black54,
                                  ),
                                  visualDensity: VisualDensity.compact,
                                  padding: EdgeInsets.zero,
                                ),
                                const SizedBox(width: 4),
                                Text('${c.likesCount}'),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
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
                    onPressed: _sending
                        ? null
                        : () async {
                      final text = _controller.text.trim();
                      if (text.isEmpty || userId.isEmpty) return;
                      setState(() => _sending = true);
                      try {
                        await ref.read(commentsRepositoryProvider).addComment(
                              courseKey: widget.courseId,
                              userId: userId,
                              authorName: auth.name,
                              text: text,
                            );
                        _controller.clear();
                        setState(() => _commentsCount += 1);
                        ref.invalidate(
                          courseCommentsFeedProvider((courseKey: widget.courseId, userId: userId)),
                        );
                      } catch (_) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Izoh yuborishda xatolik.")),
                        );
                      } finally {
                        if (mounted) setState(() => _sending = false);
                      }
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

