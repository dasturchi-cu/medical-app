import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final userId = auth.userId ?? '';
    final commentsAsync = ref.watch(
      courseCommentsFeedProvider((courseKey: widget.courseId, userId: userId)),
    );
    final progress = ref.watch(progressControllerProvider).byCourseId[widget.courseId];

    final enrolled = 120 + (widget.courseId.hashCode.abs() % 480);
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
                  label: '$enrolled talaba',
                ),
                const SizedBox(width: 10),
                _StatChip(
                  icon: Icons.check_circle_outline,
                  label: '$completed yakunlangan',
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
                                          await ref.read(commentsRepositoryProvider).toggleLike(
                                            commentId: c.id,
                                            userId: userId,
                                          );
                                          ref.invalidate(
                                            courseCommentsFeedProvider((courseKey: widget.courseId, userId: userId)),
                                          );
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
                    onPressed: () {
                      final text = _controller.text.trim();
                      if (text.isEmpty || userId.isEmpty) return;
                      ref
                          .read(commentsRepositoryProvider)
                          .addComment(
                            courseKey: widget.courseId,
                            userId: userId,
                            authorName: auth.name,
                            text: text,
                          )
                          .then((_) {
                            _controller.clear();
                            ref.invalidate(
                              courseCommentsFeedProvider((courseKey: widget.courseId, userId: userId)),
                            );
                          });
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

