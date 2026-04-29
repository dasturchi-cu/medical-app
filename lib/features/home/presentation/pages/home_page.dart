import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

import '../../../../core/localization/language_provider.dart';
import '../../../../core/di/providers.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/state/app_state_providers.dart';
import '../../../../core/state/banners_state.dart';
import '../../../../core/state/progress_controller.dart';
import '../../../../core/state/slides_state.dart';
import '../../../../core/theme/design_system.dart';
import '../../../../widgets/category_chip.dart';
import '../../../../widgets/course_card.dart';
import '../../../../widgets/course_stats_comments_sheet.dart';
import '../../../course/presentation/widgets/purchase_modal.dart';
import '../providers/home_providers.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  final _pageController = PageController(viewportFraction: 0.92);
  Timer? _timer;
  Timer? _loadingTimer;
  bool _loading = true;
  int _slideCount = 1;

  @override
  void initState() {
    super.initState();
    _loadingTimer = Timer(const Duration(milliseconds: 650), () {
      if (mounted) setState(() => _loading = false);
    });
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!_pageController.hasClients) return;
      final next = (_pageController.page?.round() ?? 0) + 1;
      final index = next % (_slideCount <= 0 ? 1 : _slideCount);
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
    _loadingTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedCat = ref.watch(selectedCategoryIdProvider);
    final query = ref.watch(homeSearchQueryProvider).trim().toLowerCase();
    final repo = ref.watch(courseRepositoryProvider);
    final allCourses = repo.getCourses();
    final slidesAsync = ref.watch(slidesFeedProvider);
    final bannersAsync = ref.watch(bannersFeedProvider);
    final remoteSlides = slidesAsync.valueOrNull ?? const [];
    final slideItems = remoteSlides.isNotEmpty
        ? remoteSlides
            .map(
              (item) => (
                title: item.title,
                courseId: item.courseId ?? '',
                buttonText: item.buttonText,
              ),
            )
            .toList(growable: false)
        : allCourses
            .take(3)
            .map(
              (course) => (
                title: course.titleUz,
                courseId: course.id,
                buttonText: 'Boshlash',
              ),
            )
            .toList(growable: false);
    final effectiveSlides = slideItems.isEmpty
        ? [(title: "Hozircha slayd yo'q", courseId: '', buttonText: 'Kutilmoqda')]
        : slideItems;
    _slideCount = effectiveSlides.length;
    final courses = allCourses.where((c) {
      final matchesCategory = switch (selectedCat) {
        'cat_books' => false,
        'cat_nevralogiya' => true,
        'cat_online' => false,
        _ => false,
      };
      if (!matchesCategory) return false;
      if (query.isEmpty) return true;
      return c.titleUz.toLowerCase().contains(query) ||
          c.authorUz.toLowerCase().contains(query);
    }).toList();
    final remoteBanners = bannersAsync.valueOrNull ?? const [];
    final courseIdByTitle = <String, String>{
      for (final course in allCourses) course.titleUz.trim().toLowerCase(): course.id,
    };
    final newsItems = remoteBanners.isNotEmpty
        ? remoteBanners
            .map(
              (banner) {
                final resolvedCourseId = (banner.courseId ?? '').trim().isNotEmpty
                    ? (banner.courseId ?? '').trim()
                    : (courseIdByTitle[banner.title.trim().toLowerCase()] ?? '');
                return _NewsItem(
                  titleUz: banner.title,
                  summaryUz: banner.message.isEmpty
                      ? 'Kurs bo\'yicha reklama'
                      : banner.message,
                  relatedCourseId: resolvedCourseId,
                  imageUrl: banner.imageUrl.isEmpty
                      ? 'https://picsum.photos/seed/${banner.id}/600/320'
                      : banner.imageUrl,
                  rating: 0,
                  commentCount: 0,
                  priceText: banner.priceLabel.isEmpty
                      ? "299 000 so'm"
                      : banner.priceLabel,
                );
              },
            )
            .toList(growable: false)
        : allCourses
            .where((c) => c.categoryId == 'cat_online')
            .take(8)
            .map(
              (course) => _NewsItem(
                titleUz: course.titleUz,
                summaryUz: course.descriptionUz.isEmpty
                    ? '${course.authorUz} kursi haqida qisqacha ma\'lumot.'
                    : course.descriptionUz,
                relatedCourseId: course.id,
                imageUrl: 'https://picsum.photos/seed/${course.id}/600/320',
                rating: course.rating,
                commentCount: 0,
                priceText: course.priceUz,
              ),
            )
            .toList(growable: false);
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
                      onChanged: (v) =>
                          ref.read(homeSearchQueryProvider.notifier).state = v,
                      decoration: InputDecoration(
                        hintText: context.tr('search_hint'),
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: query.isEmpty
                            ? null
                            : IconButton(
                                onPressed: () =>
                                    ref
                                            .read(
                                              homeSearchQueryProvider.notifier,
                                            )
                                            .state =
                                        '',
                                icon: const Icon(Icons.close),
                              ),
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
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(AppRadius.input),
                      boxShadow: AppShadows.soft,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.notifications_none),
                      onPressed: () {
                        context.push(AppRoutes.notifications);
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
                itemCount: effectiveSlides.length,
                itemBuilder: (context, index) {
                  final courseId = effectiveSlides[index].courseId;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () {
                        if (courseId.isEmpty) return;
                        ref.read(selectedCourseIdProvider.notifier).state =
                            courseId;
                        ref
                            .read(progressControllerProvider.notifier)
                            .enroll(courseId);
                        context.push('${AppRoutes.courseDetail}?id=$courseId');
                      },
                      child: Card(
                        margin: EdgeInsets.zero,
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(AppRadius.card),
                            boxShadow: AppShadows.soft,
                          ),
                          child: Stack(
                            children: [
                              Positioned(
                                right: -24,
                                top: 10,
                                child: Container(
                                  width: 110,
                                  height: 110,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.10),
                                    borderRadius: BorderRadius.circular(
                                      AppRadius.card,
                                    ),
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(AppSpacing.s16),
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
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                    const SizedBox(height: AppSpacing.s8),
                                    Text(
                                      effectiveSlides[index].title,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleLarge
                                          ?.copyWith(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                    const SizedBox(height: AppSpacing.s12),
                                    SizedBox(
                                      height: 36,
                                      child: FilledButton(
                                        style: FilledButton.styleFrom(
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              AppRadius.button,
                                            ),
                                          ),
                                          backgroundColor: Colors.white,
                                          foregroundColor: AppColors.primary,
                                        ),
                                        onPressed: () {
                                          if (courseId.isEmpty) return;
                                          ref
                                                  .read(
                                                    selectedCourseIdProvider
                                                        .notifier,
                                                  )
                                                  .state =
                                              courseId;
                                          ref
                                              .read(
                                                progressControllerProvider
                                                    .notifier,
                                              )
                                              .enroll(courseId);
                                          context.push(
                                            '${AppRoutes.courseDetail}?id=$courseId',
                                          );
                                        },
                                        child: Text(
                                          effectiveSlides[index].buttonText,
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                          ),
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
          if (effectiveSlides.length > 1)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Center(
                  child: SmoothPageIndicator(
                    controller: _pageController,
                    count: effectiveSlides.length,
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
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 44,
              child: Row(
                children: [
                  const SizedBox(width: 16),
                  Expanded(
                    child: CategoryChip(
                      label: 'Nevralogiya',
                      selected: selectedCat == 'cat_nevralogiya',
                      onTap: () =>
                          ref.read(selectedCategoryIdProvider.notifier).state =
                              'cat_nevralogiya',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: CategoryChip(
                      label: 'Kitoblar',
                      selected: selectedCat == 'cat_books',
                      onTap: () =>
                          ref.read(selectedCategoryIdProvider.notifier).state =
                              'cat_books',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: CategoryChip(
                      label: 'Onlayn kurslar',
                      selected: selectedCat == 'cat_online',
                      onTap: () =>
                          ref.read(selectedCategoryIdProvider.notifier).state =
                              'cat_online',
                    ),
                  ),
                  const SizedBox(width: 16),
                ],
              ),
            ),
          ),
          if (selectedCat == 'cat_online') ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: Text(
                  'Kanal yangiliklari',
                  style: Theme.of(
                    context,
                  ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 306,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                  itemCount: newsItems.length,
                  separatorBuilder: (_, index) => const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    final news = newsItems[index];
                    final relatedCourse = repo.getCourseById(news.relatedCourseId);
                    return _NewsCard(
                      item: news,
                      onCommentsTap: () {
                        if (news.relatedCourseId.trim().isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Bu reklama kursga ulanmagan.')),
                          );
                          return;
                        }
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          showDragHandle: false,
                          builder: (_) => CourseStatsCommentsSheet(
                            courseId: news.relatedCourseId,
                            courseTitleUz: news.titleUz,
                          ),
                        );
                      },
                      onBuyTap: () async {
                        await showPurchaseModal(
                          context: context,
                          courseName: news.titleUz,
                          description: news.summaryUz,
                          price: relatedCourse?.priceUz ?? news.priceText,
                          courseId: news.relatedCourseId.isEmpty
                              ? null
                              : news.relatedCourseId,
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          ],
          if (selectedCat != 'cat_online') ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: Text(
                  context.tr('home_section_sections'),
                  style: Theme.of(
                    context,
                  ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
            ),
            SliverList.builder(
              itemCount: courses.length,
              itemBuilder: (context, index) {
                final c = courses[index];
                final p = progress.byCourseId[c.id];
                final totalLessons = repo.getFlattenLessons(c.id).length;
                final completed = p?.completedLessonIds.length ?? 0;
                final progressValue = totalLessons == 0
                    ? 0.0
                    : (completed / totalLessons).toDouble().clamp(0.0, 1.0);

                final buttonText = (p?.enrolled ?? false) || progressValue > 0
                    ? context.tr('btn_continue')
                    : context.tr('btn_start');
                const buttonColor = AppColors.primary;

                if (_loading) {
                  return Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.s16,
                      vertical: AppSpacing.s8,
                    ),
                    child: const SizedBox(height: 116),
                  );
                }

                return CourseCard(
                  animationDelayMs: (index % 8) * 55,
                  visualKind: c.titleUz == 'Xususiy Nevrologiya (Bakalavr uchun)'
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
                  priceText: c.priceUz,
                  progress: progressValue,
                  ratingText: c.rating.toStringAsFixed(1),
                  videoCountText: '$totalLessons ta video',
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
                  onMessagePressed: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      showDragHandle: false,
                      builder: (_) => CourseStatsCommentsSheet(
                        courseId: c.id,
                        courseTitleUz: c.titleUz,
                      ),
                    );
                  },
                );
              },
            ),
          ],
          if (selectedCat == 'cat_books')
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Text(
                  context.tr('books_empty'),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.black54,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 10)),
        ],
      ),
    );
  }
}

class _NewsCard extends StatelessWidget {
  const _NewsCard({
    required this.item,
    required this.onCommentsTap,
    required this.onBuyTap,
  });

  final _NewsItem item;
  final VoidCallback onCommentsTap;
  final VoidCallback onBuyTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 312,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppShadows.soft,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 126,
              width: double.infinity,
              child: Image.network(
                item.imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  final dataImage = _decodeDataImage(item.imageUrl);
                  if (dataImage != null) {
                    return Image.memory(dataImage, fit: BoxFit.cover);
                  }
                  return Container(
                    color: const Color(0xFFE7EEF9),
                    child: const Center(
                      child: Icon(Icons.image_outlined, color: AppColors.primary),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.titleUz,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.summaryUz,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.star, size: 16, color: Colors.amber),
                      const SizedBox(width: 4),
                      Text(
                        item.rating.toStringAsFixed(1),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Icon(
                        Icons.chat_bubble_outline,
                        size: 16,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${item.commentCount} ta sharh',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: onCommentsTap,
                          child: const Text('Sharhlar'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton(
                          onPressed: onBuyTap,
                          child: const Text('Sotib olish'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NewsItem {
  const _NewsItem({
    required this.titleUz,
    required this.summaryUz,
    required this.relatedCourseId,
    required this.imageUrl,
    required this.rating,
    required this.commentCount,
    required this.priceText,
  });

  final String titleUz;
  final String summaryUz;
  final String relatedCourseId;
  final String imageUrl;
  final double rating;
  final int commentCount;
  final String priceText;
}

Uint8List? _decodeDataImage(String value) {
  if (!value.startsWith('data:image')) return null;
  final commaIndex = value.indexOf(',');
  if (commaIndex < 0 || commaIndex >= value.length - 1) return null;
  try {
    return base64Decode(value.substring(commaIndex + 1));
  } catch (_) {
    return null;
  }
}
