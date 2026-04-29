import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/providers.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/state/app_state_providers.dart';
import '../../../../core/state/purchase_controller.dart';
import '../../../../core/state/progress_controller.dart';
import '../../../../widgets/base_card.dart';
import '../../../../widgets/lesson_item.dart';
import '../widgets/purchase_modal.dart';

class CourseDetailPage extends ConsumerWidget {
  const CourseDetailPage({super.key, required this.courseId});

  final String courseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(courseRepositoryProvider);
    final course = repo.getCourseById(courseId);
    final purchased = ref
        .watch(purchaseControllerProvider)
        .isPurchased(courseId);
    final lessons = course == null
        ? const []
        : repo.getFlattenLessons(courseId);
    final isDoctorCourse = course?.id == 'course_private_neuro';

    if (course == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Kurs')),
        body: const Center(child: Text('Kurs topilmadi')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(course.titleUz),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        children: [
          Card(
            margin: EdgeInsets.zero,
            child: Container(
              height: 170,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: const LinearGradient(
                  colors: [Color(0xFF111827), Color(0xFF0B1220)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Stack(
                children: [
                  Positioned(
                    left: 16,
                    bottom: 16,
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE9F0FF),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: const Icon(
                        Icons.psychology,
                        color: Color(0xFF1E6BB8),
                        size: 30,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            course.titleUz,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Text(
            course.descriptionUz,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.black54,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _ChipInfo(
                icon: Icons.menu_book_outlined,
                label: '${lessons.length} ta dars',
              ),
              _ChipInfo(
                icon: Icons.lock_open_outlined,
                label: purchased ? 'Kurs ochilgan' : '1-dars bepul',
              ),
              _ChipInfo(icon: Icons.person_outline, label: 'Mehmon'),
            ],
          ),
          if (!purchased)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: SizedBox(
                height: 46,
                child: FilledButton.tonal(
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () async {
                    await showPurchaseModal(
                      context: context,
                      courseName: course.titleUz,
                      description: course.descriptionUz,
                      price: '299 000 so\'m',
                    );
                  },
                  child: const Text(
                    'Sotib olish',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 14),
          if (isDoctorCourse) ...[
            Text(
              'Bazalar',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 10),
            ...course.sections.map((s) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: BaseCard(
                  title: s.titleUz,
                  videoCountText: '${s.lessons.length} ta video',
                  onTap: () {
                    ref.read(selectedCourseIdProvider.notifier).state =
                        course.id;
                    ref
                        .read(progressControllerProvider.notifier)
                        .enroll(course.id);
                    context.push(
                      '${AppRoutes.lessonList}?courseId=${course.id}&sectionId=${s.id}',
                    );
                  },
                ),
              );
            }),
          ] else ...[
            Text(
              'Video darslar',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 10),
            ...List.generate(lessons.length, (i) {
              final l = lessons[i];
              final locked = !purchased && i > 0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: LessonItem(
                  index: i + 1,
                  title: l.titleUz,
                  duration: l.durationUz,
                  locked: locked,
                  onTap: () async {
                    if (locked) {
                      await showPurchaseModal(
                        context: context,
                        courseName: course.titleUz,
                        description: course.descriptionUz,
                        price: '299 000 so\'m',
                      );
                      return;
                    }
                    ref.read(selectedCourseIdProvider.notifier).state =
                        course.id;
                    ref
                        .read(progressControllerProvider.notifier)
                        .openedLesson(courseId: course.id, lessonId: l.id);
                    context.push('${AppRoutes.lesson}?id=${l.id}');
                  },
                ),
              );
            }),
          ],
          const SizedBox(height: 8),
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
                ref.read(selectedCourseIdProvider.notifier).state = course.id;
                ref.read(progressControllerProvider.notifier).enroll(course.id);
                final first = repo.getFirstUnlockedLesson(course.id);
                if (first != null) {
                  context.push('${AppRoutes.lesson}?id=${first.id}');
                  return;
                }
                context.push('${AppRoutes.quiz}?id=quiz_1');
              },
              child: const Text(
                'Boshlash',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChipInfo extends StatelessWidget {
  const _ChipInfo({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: const Color(0xFF1E6BB8)),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
