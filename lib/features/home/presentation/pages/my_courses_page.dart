import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/providers.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/state/progress_controller.dart';
import '../../../../core/theme/design_system.dart';
import '../../../../widgets/course_card.dart';

class MyCoursesPage extends ConsumerWidget {
  const MyCoursesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(courseRepositoryProvider);
    final progress = ref.watch(progressControllerProvider);

    final all = repo.getCourses();
    final enrolled = all.where((c) {
      final p = progress.byCourseId[c.id];
      return (p?.enrolled ?? false);
    }).toList();

    return SafeArea(
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
              child: Text(
                'Kurslarim',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
            ),
          ),
          if (enrolled.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Text(
                  'Hali kursga yozilmagansiz',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.black54,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            )
          else
            SliverList.builder(
              itemCount: enrolled.length,
              itemBuilder: (context, index) {
                final c = enrolled[index];
                final p = progress.byCourseId[c.id];
                final totalLessons = repo.getFlattenLessons(c.id).length;
                final completed = p?.completedLessonIds.length ?? 0;
                final progressValue = totalLessons == 0
                    ? 0.0
                    : (completed / totalLessons).toDouble().clamp(0.0, 1.0);
                final buttonText = 'Davom et';

                return CourseCard(
                  animationDelayMs: (index % 8) * 55,
                  visualKind:
                      c.titleUz == 'Xususiy Nevrologiya (Bakalavr uchun)'
                      ? 'xususiy_bachelor'
                      : c.titleUz == 'Umumiy Nevrologiya (Bakalavr uchun)'
                      ? 'umumiy_bachelor'
                      : c.titleUz == 'Xususiy nevrologiya (shifokorlar uchun)'
                      ? 'xususiy_doctors'
                      : c.titleUz == 'EEG'
                      ? 'eeg_img'
                      : c.titleUz == 'Epileptologiya'
                      ? 'epileptologiya_img'
                      : c.titleUz == 'ENMG'
                      ? 'enmg_img'
                      : 'brain',
                  title: c.titleUz,
                  author: c.authorUz,
                  summary: c.descriptionUz,
                  imageUrl: c.imageUrl,
                  priceText: c.priceUz,
                  progress: progressValue,
                  ratingText: c.rating.toStringAsFixed(1),
                  videoCountText: '$totalLessons ta video',
                  buttonText: buttonText,
                  buttonColor: AppColors.primary,
                  onPressed: () {
                    final firstSection = c.sections.isNotEmpty
                        ? c.sections.first
                        : null;
                    if (firstSection != null) {
                      context.push(
                        '${AppRoutes.lessonList}?courseId=${c.id}&sectionId=${firstSection.id}',
                      );
                      return;
                    }
                    context.push('${AppRoutes.courseDetail}?id=${c.id}');
                  },
                );
              },
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 10)),
        ],
      ),
    );
  }
}
