import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

import '../../../../core/di/providers.dart';
import '../../../../core/mock/mock_data.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/state/app_state_providers.dart';
import '../../../../core/state/progress_controller.dart';
import '../../../../widgets/course_card.dart';
import '../providers/home_providers.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  final _pageController = PageController(viewportFraction: 0.92);
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!_pageController.hasClients) return;
      final next = (_pageController.page?.round() ?? 0) + 1;
      final index = next % MockData.homeSlidesUz.length;
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedCat = ref.watch(selectedCategoryIdProvider);
    final repo = ref.watch(courseRepositoryProvider);
    final allCourses = repo.getCourses();
    final courses = allCourses.where((c) {
      if (selectedCat == 'c1') return true; // Barchasi
      return c.categoryId == selectedCat;
    }).toList();
    final progress = ref.watch(progressControllerProvider);

    return SafeArea(
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'Qidirish',
                        prefixIcon: const Icon(Icons.search),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.notifications_none),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Bildirishnomalar yo‘q')),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 154,
              child: PageView.builder(
                controller: _pageController,
                itemCount: MockData.homeSlidesUz.length,
                itemBuilder: (context, index) {
                  final courseId = MockData.bannerCourseIds[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () {
                        ref.read(selectedCourseIdProvider.notifier).state = courseId;
                        ref.read(progressControllerProvider.notifier).enroll(courseId);
                        context.push('${AppRoutes.courseDetail}?id=$courseId');
                      },
                      child: Card(
                        margin: EdgeInsets.zero,
                        child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          gradient: const LinearGradient(
                            colors: [Color(0xFF1E6BB8), Color(0xFF0E4E8B)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: Stack(
                          children: [
                            Positioned(
                              right: -14,
                              top: 14,
                              child: Container(
                                width: 120,
                                height: 120,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(28),
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'Kurs',
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelLarge
                                        ?.copyWith(
                                          color: Colors.white70,
                                          fontWeight: FontWeight.w700,
                                        ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    MockData.homeSlidesUz[index],
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge
                                        ?.copyWith(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w800,
                                        ),
                                  ),
                                  const SizedBox(height: 10),
                                  SizedBox(
                                    height: 34,
                                    child: FilledButton.tonal(
                                      style: FilledButton.styleFrom(
                                        backgroundColor: Colors.white,
                                        foregroundColor: const Color(0xFF0E4E8B),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(999),
                                        ),
                                      ),
                                      onPressed: () {
                                        ref.read(selectedCourseIdProvider.notifier).state =
                                            courseId;
                                        ref
                                            .read(progressControllerProvider.notifier)
                                            .enroll(courseId);
                                        context.push('${AppRoutes.courseDetail}?id=$courseId');
                                      },
                                      child: const Text(
                                        'Boshlash',
                                        style: TextStyle(fontWeight: FontWeight.w800),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Center(
                child: SmoothPageIndicator(
                  controller: _pageController,
                  count: MockData.homeSlidesUz.length,
                  effect: WormEffect(
                    dotWidth: 8,
                    dotHeight: 8,
                    activeDotColor: const Color(0xFF1E6BB8),
                    dotColor: Colors.black.withValues(alpha: 0.14),
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              child: Text(
                'Kategoriyalar',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 44,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                itemBuilder: (context, i) {
                  final cat = MockData.categories[i];
                  final selected = cat.id == selectedCat;
                  return InkWell(
                    borderRadius: BorderRadius.circular(999),
                    onTap: () => ref.read(selectedCategoryIdProvider.notifier).state =
                        cat.id,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: selected ? const Color(0xFF1E6BB8) : Colors.white,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        cat.titleUz,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: selected ? Colors.white : Colors.black87,
                            ),
                      ),
                    ),
                  );
                },
                separatorBuilder: (_, index) => const SizedBox(width: 10),
                itemCount: MockData.categories.length,
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Text(
                'Kurslar',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ),
          ),
          SliverList.builder(
            itemCount: courses.length,
            itemBuilder: (context, index) {
              final c = courses[index];
              final buttonText = c.progress > 0 ? 'Davom etish' : 'Boshlash';
              final buttonColor =
                  c.progress > 0 ? const Color(0xFFFF7A2D) : const Color(0xFF1E6BB8);

              return CourseCard(
                title: c.titleUz,
                author: c.authorUz,
                progress: c.progress,
                ratingText: '${c.rating.toStringAsFixed(1)}/5',
                buttonText: buttonText,
                buttonColor: buttonColor,
                onPressed: () {
                  ref.read(selectedCourseIdProvider.notifier).state = c.id;
                  ref.read(progressControllerProvider.notifier).enroll(c.id);

                  if (buttonText == 'Davom etish') {
                    final last = progress.byCourseId[c.id]?.lastLessonId;
                    if (last != null) {
                      context.push('${AppRoutes.lesson}?id=$last');
                      return;
                    }
                    final first = repo.getFirstUnlockedLesson(c.id);
                    if (first != null) {
                      context.push('${AppRoutes.lesson}?id=${first.id}');
                      return;
                    }
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

