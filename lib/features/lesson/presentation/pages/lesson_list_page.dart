import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/providers.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/state/app_state_providers.dart';
import '../../../../core/state/progress_controller.dart';

class LessonListPage extends ConsumerWidget {
  const LessonListPage({
    super.key,
    required this.courseId,
    required this.sectionId,
  });

  final String courseId;
  final String sectionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(courseRepositoryProvider);
    final section = repo.getSectionById(courseId, sectionId);

    if (section == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Darslar'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.pop(),
          ),
        ),
        body: const Center(child: Text('Bo‘lim topilmadi')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Darslar'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        itemCount: section.lessons.length,
        separatorBuilder: (_, index) => const SizedBox(height: 10),
        itemBuilder: (context, i) {
          final l = section.lessons[i];

          final trailing = l.isLocked
              ? const Icon(Icons.lock, color: Colors.black38)
              : l.isCompleted
                  ? const Icon(Icons.check_circle, color: Color(0xFF1E6BB8))
                  : const Icon(Icons.play_circle, color: Color(0xFF1E6BB8));

          return Card(
            margin: EdgeInsets.zero,
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFE9F0FF),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.menu_book, color: Color(0xFF1E6BB8)),
              ),
              title: Text(
                l.titleUz,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              subtitle: Text(
                l.durationUz,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.black54,
                    ),
              ),
              trailing: trailing,
              onTap: l.isLocked
                  ? null
                  : () {
                      ref.read(selectedCourseIdProvider.notifier).state = courseId;
                      ref
                          .read(progressControllerProvider.notifier)
                          .openedLesson(courseId: courseId, lessonId: l.id);
                      context.push('${AppRoutes.lesson}?id=${l.id}');
                    },
            ),
          );
        },
      ),
    );
  }
}

