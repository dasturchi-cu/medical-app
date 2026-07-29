import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

import '../../../../core/localization/language_provider.dart';
import '../../../../core/config/feature_flags.dart';
import '../../../../core/data/models/slide_models.dart';
import '../../../../core/di/providers.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/models/course_models.dart';
import '../../../../core/services/catalog_service.dart';
import '../../../../core/services/course_progress_local_store.dart';
import '../../../../core/services/course_progress_remote_sync.dart';
import '../../../../core/services/home_feeds_disk_cache.dart';
import '../../../../core/services/home_aggregate_service.dart';
import '../../../../core/state/app_state_providers.dart';
import '../../../../core/state/banners_state.dart';
import '../../../../core/state/books_state.dart';
import '../../../../core/state/course_stats_state.dart';
import '../../../../core/state/notifications_state.dart';
import '../../../../core/state/progress_controller.dart';
import '../../../../core/state/purchase_controller.dart';
import '../../../../core/state/slides_state.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/design_system.dart';
import '../../../../widgets/category_chip.dart';
import '../../../../widgets/course_card.dart';
import '../../../../widgets/course_stats_comments_sheet.dart';
import '../../../course/presentation/widgets/purchase_modal.dart'
    show PurchaseOfferKind, showPurchaseModal;
import '../../../../widgets/cached_remote_image.dart';
import '../providers/home_providers.dart';

/// Yuqori ko'k slayd uchun `home_slides.course_id`; bo'sh bo'lsa sarlavha bo'yicha bitta mos kurs qidiriladi.
String? _resolveSlideCourseId(String title, String apiCourseId, List<Course> courses) {
  final cid = apiCourseId.trim();
  if (cid.isNotEmpty) return cid;
  final needle = title.trim().toLowerCase();
  if (needle.isEmpty) return null;
  final hits = courses.where((c) => c.titleUz.trim().toLowerCase() == needle).toList();
  if (hits.length == 1) return hits.single.id;
  return null;
}

void _openSlideCourse(
  BuildContext context,
  WidgetRef ref, {
  required String slideTitle,
  required String slideCourseIdRaw,
  required List<Course> courses,
}) {
  final resolved = _resolveSlideCourseId(slideTitle, slideCourseIdRaw, courses);
  if (resolved == null || resolved.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Bu slayd uchun kurs ulanmagan. Admin panel → «Bosh sahifa slaydi» bo\'limida «Boshlash» uchun kursni tanlang.',
        ),
      ),
    );
    return;
  }
  ref.read(selectedCourseIdProvider.notifier).state = resolved;
  ref.read(progressControllerProvider.notifier).enroll(resolved);
  context.push('${AppRoutes.courseDetail}?id=$resolved');
}

/// Yuqori slayd fon rasmi (URL yoki admin paneldagi `data:image` Base64).
class _HomeSlideBackdrop extends StatelessWidget {
  const _HomeSlideBackdrop({required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    final u = imageUrl.trim();
    if (u.isEmpty) {
      return const ColoredBox(color: AppColors.primary);
    }
    if (u.startsWith('data:image')) {
      const marker = ';base64,';
      final idx = u.indexOf(marker);
      if (idx >= 0) {
        try {
          final b64 = u.substring(idx + marker.length).trim();
          final bytes = base64Decode(b64);
          return Image.memory(
            bytes,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            gaplessPlayback: true,
            errorBuilder: (context, error, stackTrace) =>
                const ColoredBox(color: AppColors.primary),
          );
        } catch (_) {
          return const ColoredBox(color: AppColors.primary);
        }
      }
    }
    return CachedRemoteImage(
      url: u,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      filterQuality: FilterQuality.low,
      cacheWidth: (MediaQuery.devicePixelRatioOf(context) * 1080).round(),
      errorBuilder: (context, _) => const ColoredBox(color: AppColors.primary),
      loadingBuilder: (context, child, _) => child is Image
          ? child
          : const ColoredBox(color: AppColors.primary),
    );
  }
}

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> with WidgetsBindingObserver {
  final _pageController = PageController(viewportFraction: 0.92);
  Timer? _timer;
  Timer? _catalogRetryTimer;
  int _slideCount = 1;
  int _catalogRetryCount = 0;
  DateTime? _lastResumeSyncAt;
  static const _resumeSyncMinInterval = Duration(seconds: 45);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_hydrateProgressAndSync());
      unawaited(_warmHomeData());
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
    _catalogRetryTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      if (!mounted) return;
      if (CatalogService.courses.isNotEmpty || CatalogService.isLoading) {
        _catalogRetryTimer?.cancel();
        return;
      }
      if (_catalogRetryCount >= 5) {
        _catalogRetryTimer?.cancel();
        return;
      }
      _catalogRetryCount++;
      unawaited(CatalogService.bootstrap(maxAttempts: 1));
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _catalogRetryTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final now = DateTime.now();
      final last = _lastResumeSyncAt;
      if (last != null && now.difference(last) < _resumeSyncMinInterval) {
        return;
      }
      _lastResumeSyncAt = now;
      
      final authState = ref.read(authControllerProvider);
      if (authState.userId != null) {
        unawaited(
          ref
              .read(purchaseControllerProvider.notifier)
              .syncFromBackend(authState.userId!, force: true)
              .catchError((_) {}),
        );
      }

      unawaited(
        _syncRemoteVideoProgress().then((_) {
          if (mounted) setState(() {});
        }),
      );
    }
  }

  Future<void> _refreshCatalog() async {
    final authState = ref.read(authControllerProvider);
    if (authState.userId != null) {
      unawaited(
        ref
            .read(purchaseControllerProvider.notifier)
            .syncFromBackend(authState.userId!, force: true)
            .catchError((_) {}),
      );
    }

    if (HomeAggregateConfig.enabled) {
      final ok = await HomeAggregateService.tryFetchAndSeed(ref);
      if (ok) {
        unawaited(_syncRemoteVideoProgress());
        if (!mounted) return;
        ref.invalidate(slidesFeedProvider);
        ref.invalidate(bannersFeedProvider);
        ref.invalidate(booksFeedProvider);
        unawaited(ref.read(booksRepositoryProvider).fetchBooks());
        setState(() {});
        return;
      }
    }
    await CatalogService.refreshDetailedCatalog(maxAttempts: 2, force: true);
    unawaited(_syncRemoteVideoProgress());
    if (!mounted) return;
    ref.invalidate(slidesFeedProvider);
    ref.invalidate(bannersFeedProvider);
    ref.invalidate(booksFeedProvider);
    unawaited(ref.read(booksRepositoryProvider).fetchBooks());
    setState(() {});
  }

  Future<void> _syncRemoteVideoProgress() => CourseProgressRemoteSync.refresh(ref);

  Future<void> _hydrateProgressAndSync() async {
    final cached = await CourseProgressLocalStore.load();
    if (!mounted) return;
    if (cached.isNotEmpty) {
      ref.read(progressControllerProvider.notifier).hydrateFromLocal(cached);
      setState(() {});
    }
    final authState = ref.read(authControllerProvider);
    final uid = authState.userId;
    if (uid != null && uid.isNotEmpty) {
      unawaited(
        ref
            .read(purchaseControllerProvider.notifier)
            .syncFromBackend(uid, force: true)
            .catchError((_) {}),
      );
      ref.read(purchaseControllerProvider.notifier).bindRealtime(uid);
    }
    await _syncRemoteVideoProgress();
    if (mounted) setState(() {});
  }


  Future<void> _warmHomeData() async {
    if (!mounted) return;
    var seededFromHome = false;
    if (HomeAggregateConfig.enabled) {
      seededFromHome = await HomeAggregateService.tryFetchAndSeed(ref);
    }
    if (!mounted) return;
    ref.read(homeFeedReadyProvider.notifier).state = true;

    if (!seededFromHome && !CatalogService.lastLoadOk && !CatalogService.isLoading) {
      unawaited(CatalogService.bootstrap(maxAttempts: 1));
    }
    if (!mounted) return;
    unawaited(
      Future.wait<void>([
        ref.read(slidesRepositoryProvider).fetchSlides(),
        ref.read(bannersRepositoryProvider).fetchBanners(),
        ref.read(booksRepositoryProvider).fetchBooks(),
      ]),
    );
  }

  void _selectCategory(String cat) {
    ref.read(selectedCategoryIdProvider.notifier).state = cat;
    if (cat == 'cat_books') {
      ref.invalidate(booksFeedProvider);
      unawaited(ref.read(booksRepositoryProvider).fetchBooks());
    } else if (cat == 'cat_online') {
      ref.invalidate(bannersFeedProvider);
      unawaited(ref.read(bannersRepositoryProvider).fetchBanners());
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedCat = ref.watch(selectedCategoryIdProvider);
    final query = ref.watch(homeSearchQueryProvider).trim().toLowerCase();
    final repo = ref.watch(courseRepositoryProvider);
    final lang =
        ref.watch(localizationProvider).valueOrNull?.langCode ?? 'uz';
    final feedReady = ref.watch(homeFeedReadyProvider);
    final deferHomeFeeds = HomeAggregateConfig.enabled && !feedReady;
    final slidesAsync = deferHomeFeeds ? null : ref.watch(slidesFeedProvider);
    final bannersAsync = deferHomeFeeds ? null : ref.watch(bannersFeedProvider);
    final booksAsync = ref.watch(booksFeedProvider);
    final books = booksAsync.valueOrNull ?? HomeFeedsDiskCache.books;
    final paidBookIds = ref.watch(paidBookIdsProvider).valueOrNull ?? const <String>{};
    final remoteSlides = deferHomeFeeds
        ? const <HomeSlideItem>[]
        : (slidesAsync!.valueOrNull ?? HomeFeedsDiskCache.slides);
    final slidesLoading = deferHomeFeeds ||
        ((slidesAsync?.isLoading ?? false) && remoteSlides.isEmpty);
    final slidesFetchError =
        !deferHomeFeeds && (slidesAsync?.hasError ?? false);
    // Faqat serverdagi home_slides — admin bo'sh qoldirsa kurslardan «soxta» slayd chiqmasin.
    final slideItems = remoteSlides
        .map(
          (item) => (
            title: item.title,
            courseId: item.courseId ?? '',
            buttonText: item.buttonText,
            imageUrl: item.imageUrl,
          ),
        )
        .toList(growable: false);
    _slideCount = slideItems.length;
    final remoteBanners = deferHomeFeeds
        ? const []
        : (bannersAsync!.valueOrNull ?? HomeFeedsDiskCache.banners);
    final courseStatsOverrides = ref.watch(courseCardStatsOverrideProvider);
    final contentStatsOverrides = ref.watch(contentCardStatsOverrideProvider);
    final neurologyStatsMap =
        ref.watch(neurologyHomeStatsProvider(CatalogService.courseListIdentityKey)).valueOrNull ??
        const <String, CourseCardStats>{};
    final newsItems = remoteBanners
        .map(
          (banner) {
            final linkedCourseId = (banner.courseId ?? '').trim();
            final externalTelegramOnly = linkedCourseId.isEmpty;
            return _NewsItem(
              id: banner.id,
              titleUz: banner.title,
              summaryUz: banner.message.isEmpty
                  ? (externalTelegramOnly
                      ? context.tr('banner_telegram_external')
                      : context.tr('banner_ad_default'))
                  : banner.message,
              feedbackKey: externalTelegramOnly ? banner.id : linkedCourseId,
              platformCourseId: externalTelegramOnly ? null : linkedCourseId,
              telegramContact: banner.telegram.trim().isEmpty
                  ? 'Neuroscienceadmin'
                  : banner.telegram.trim(),
              useFeedbackApi: externalTelegramOnly,
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
        .toList(growable: false);
    final progress = ref.watch(progressControllerProvider);
    final unreadNotifications = ref.watch(unreadNotificationsCountProvider);

    return ListenableBuilder(
      listenable: CatalogService.catalogRevision,
      builder: (context, _) {
        final allCourses = repo.getCourses();
        final courses = allCourses.where((c) {
          final matchesCategory = switch (selectedCat) {
            'cat_books' => false,
            'cat_nevralogiya' => true,
            'cat_online' => false,
            _ => false,
          };
          if (!matchesCategory) return false;
          if (query.isEmpty) return true;
          return c.localizedTitle(lang).toLowerCase().contains(query) ||
              c.authorUz.toLowerCase().contains(query);
        }).toList();
        final isCatalogStillLoading = (CatalogService.isLoading ||
                CatalogService.isRefreshingDetails) &&
            (allCourses.isEmpty || !CatalogService.hasLessonDetails) &&
            !CatalogService.isLoadingStuck;
        String? catalogLoadError;
        try {
          catalogLoadError = CatalogService.lastLoadError;
        } catch (_) {
          // Hot-reload paytida eski state qolib ketsa build crash bo'lmasin.
          catalogLoadError = null;
        }
        return SafeArea(
      child: RefreshIndicator(
        onRefresh: _refreshCatalog,
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
                      color: context.appColors.surface,
                      borderRadius: BorderRadius.circular(AppRadius.input),
                      boxShadow: AppShadows.soft(context),
                    ),
                    child: Badge(
                      isLabelVisible: unreadNotifications > 0,
                      backgroundColor: const Color(0xFFC62828),
                      label: Text(
                        unreadNotifications > 99 ? '99+' : '$unreadNotifications',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        icon: Icon(
                          unreadNotifications > 0
                              ? Icons.notifications_active_outlined
                              : Icons.notifications_none,
                        ),
                        onPressed: () {
                          context.push(AppRoutes.notifications);
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (slideItems.isNotEmpty)
          SliverToBoxAdapter(
            child: SizedBox(
              height: 154,
              child: PageView.builder(
                controller: _pageController,
                itemCount: slideItems.length,
                itemBuilder: (context, index) {
                  final slide = slideItems[index];
                  final courseId = slide.courseId;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => _openSlideCourse(context, ref,
                          slideTitle: slide.title,
                          slideCourseIdRaw: courseId,
                          courses: allCourses),
                      child: Card(
                        margin: EdgeInsets.zero,
                        clipBehavior: Clip.antiAlias,
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(AppRadius.card),
                            boxShadow: AppShadows.soft(context),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(AppRadius.card),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                Positioned.fill(
                                  child: _HomeSlideBackdrop(imageUrl: slide.imageUrl),
                                ),
                                if (slide.imageUrl.trim().isNotEmpty)
                                  Positioned.fill(
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.centerLeft,
                                          end: Alignment.centerRight,
                                          stops: const [0.0, 0.45, 1.0],
                                          colors: [
                                            AppColors.primary.withValues(alpha: 0.90),
                                            AppColors.primary.withValues(alpha: 0.48),
                                            AppColors.primary.withValues(alpha: 0.12),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                if (slide.imageUrl.trim().isEmpty)
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
                                        slide.title,
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
                                          onPressed: () => _openSlideCourse(
                                            context,
                                            ref,
                                            slideTitle: slide.title,
                                            slideCourseIdRaw: courseId,
                                            courses: allCourses,
                                          ),
                                          child: Text(
                                            slide.buttonText,
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
                    ),
                  );
                },
              ),
            ),
          ),
          if (slideItems.isEmpty && slidesLoading)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Card(
                  margin: EdgeInsets.zero,
                  child: SizedBox(
                    height: 154,
                    child: Container(color: const Color(0xFFE8EEF9)),
                  ),
                ),
              ),
            ),
          if (slideItems.isEmpty && slidesFetchError)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Text(
                  'Slaydlar yuklanmadi. Pastga tortib qayta urinib ko‘ring.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.black54,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
            ),
          if (slideItems.length > 1)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Center(
                  child: SmoothPageIndicator(
                    controller: _pageController,
                    count: slideItems.length,
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
                context.tr('home_categories'),
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
                      label: context.tr('cat_neurology'),
                      selected: selectedCat == 'cat_nevralogiya',
                      onTap: () => _selectCategory('cat_nevralogiya'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: CategoryChip(
                      label: context.tr('cat_books'),
                      selected: selectedCat == 'cat_books',
                      onTap: () => _selectCategory('cat_books'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: CategoryChip(
                      label: context.tr('cat_online_courses'),
                      selected: selectedCat == 'cat_online',
                      onTap: () => _selectCategory('cat_online'),
                    ),
                  ),
                  const SizedBox(width: 16),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: (catalogLoadError != null ||
                      CatalogService.isLoadingStuck ||
                      (!isCatalogStillLoading && allCourses.isEmpty))
                  ? Material(
                      color: const Color(0xFFFFF4E5),
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                catalogLoadError != null
                                    ? 'Kurslar yuklanmadi: $catalogLoadError\nInternetni tekshiring va yangilang.'
                                    : CatalogService.isLoadingStuck
                                        ? 'Kurslar yuklanishi cho‘zildi. Tarmoq sekin bo‘lishi mumkin.\nQayta urinib ko‘ring.'
                                    : 'Kurslar hozircha yuklanmadi. Qayta urinish mumkin.',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: const Color(0xFF92400E),
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            TextButton(
                              onPressed: () => unawaited(_refreshCatalog()),
                              child: const Text('Qayta urinish'),
                            ),
                          ],
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ),
          if (selectedCat == 'cat_online') ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: Text(
                  context.tr('channel_news'),
                  style: Theme.of(
                    context,
                  ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 306,
                child: newsItems.isEmpty
                    ? Center(
                        child: Text(
                          context.tr('channel_news_empty'),
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                color: Colors.black54,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      )
                    : ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                        itemCount: newsItems.length,
                        separatorBuilder: (_, index) => const SizedBox(width: 12),
                        itemBuilder: (context, index) {
                          final news = newsItems[index];
                          final fetchedNewsStats = ref
                              .watch(
                                contentCardStatsProvider(
                                  (key: news.feedbackKey, useFeedbackApi: news.useFeedbackApi),
                                ),
                              )
                              .valueOrNull;
                          final linkedCourseStats = news.platformCourseId == null
                              ? null
                              : neurologyStatsMap[news.platformCourseId!];
                          final newsStats = contentStatsOverrides[news.feedbackKey] ??
                              fetchedNewsStats ??
                              linkedCourseStats;
                          return _NewsCard(
                            item: news,
                            ratingValue: newsStats?.ratingAvg ?? news.rating,
                            commentCountValue: newsStats?.commentsCount ?? news.commentCount,
                            onCommentsTap: () {
                              showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                showDragHandle: false,
                                builder: (_) => CourseStatsCommentsSheet(
                                  courseId: news.feedbackKey,
                                  courseTitleUz: news.titleUz,
                                  useFeedbackApi: news.useFeedbackApi,
                                ),
                              );
                            },
                            onBuyTap: () async {
                              await showPurchaseModal(
                                context: context,
                                courseName: news.titleUz,
                                description: news.summaryUz,
                                price: news.priceText,
                                courseId: news.platformCourseId,
                                telegramRecipient: news.telegramContact,
                                offerKind: news.platformCourseId == null
                                    ? PurchaseOfferKind.externalTelegramChannel
                                    : PurchaseOfferKind.platformPaidCourse,
                              );
                            },
                          );
                        },
                      ),
              ),
            ),
          ],
          if (selectedCat == 'cat_nevralogiya') ...[
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
            if (isCatalogStillLoading)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2.2),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Bo‘limlar yuklanmoqda...',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              )
            else
              SliverList.builder(
                itemCount: courses.length,
                itemBuilder: (context, index) {
                final c = courses[index];
                final cardStats = courseStatsOverrides[c.id] ?? neurologyStatsMap[c.id];
                final p = progress.byCourseId[c.id];
                final totalLessons = c.lessonCount > 0
                    ? c.lessonCount
                    : repo.getFlattenLessons(c.id).length;
                final watched = p?.watchedLessonIds.length ?? 0;
                final progressValue = totalLessons == 0
                    ? 0.0
                    : (watched / totalLessons).toDouble().clamp(0.0, 1.0);

                final buttonText = (p?.enrolled ?? false) || progressValue > 0
                    ? 'Davom et'
                    : context.tr('btn_start');
                const buttonColor = AppColors.primary;

                return CourseCard(
                  animationDelayMs: 0,
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
                  title: c.localizedTitle(lang),
                  author: c.authorUz.trim().isEmpty ? 'Umidjon Mukarramov' : c.authorUz,
                  imageUrl: c.imageUrl,
                  progress: progressValue,
                  ratingText: (cardStats?.ratingAvg ?? c.rating).toStringAsFixed(1),
                  commentCountText: context.tr(
                    'comments_count',
                    params: {
                      'n': '${cardStats?.commentsCount ?? c.commentsCount}',
                    },
                  ),
                  videoCountText: '$totalLessons ta video',
                  buttonText: buttonText,
                  buttonColor: buttonColor,
                  onMessagePressed: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      showDragHandle: false,
                      builder: (_) => CourseStatsCommentsSheet(
                        courseId: c.id,
                        courseTitleUz: c.titleUz,
                        showEnrolledStat: false,
                      ),
                    );
                  },
                  onPressed: () {
                    ref.read(selectedCourseIdProvider.notifier).state = c.id;
                    ref.read(progressControllerProvider.notifier).enroll(c.id);

                    if (buttonText == 'Davom et') {
                      final firstSection = c.sections.isNotEmpty
                          ? c.sections.first
                          : null;
                      if (firstSection != null) {
                        context.push(
                          '${AppRoutes.lessonList}?courseId=${c.id}&sectionId=${firstSection.id}',
                        );
                        return;
                      }
                    }

                    context.push('${AppRoutes.courseDetail}?id=${c.id}');
                  },
                );
                },
              ),
          ],
          if (selectedCat == 'cat_books')
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.tr('books_library_title'),
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          context.tr(
                            'books_total_count',
                            params: {'n': '${books.length}'},
                          ),
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.black54),
                        ),
                        const SizedBox(height: 10),
                        if (books.isNotEmpty) ...[
                          ...(books.take(4).map(
                                (book) => Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: ListTile(
                                    dense: true,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      side: BorderSide(color: Colors.black.withValues(alpha: 0.06)),
                                    ),
                                    leading: const Icon(Icons.menu_book_outlined),
                                    title: Text(
                                      book.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    subtitle: Text(
                                      (!book.isPaid || paidBookIds.contains(book.id))
                                          ? (book.author.isEmpty
                                              ? context.tr('book_author_missing')
                                              : book.author)
                                          : book.isPaid
                                          ? context.tr(
                                              'book_locked_price',
                                              params: {'price': '${book.priceUzs}'},
                                            )
                                          : (book.author.isEmpty
                                              ? context.tr('book_author_missing')
                                              : book.author),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    trailing: (!book.isPaid || paidBookIds.contains(book.id))
                                        ? const Icon(Icons.chevron_right)
                                        : book.isPaid
                                        ? const Icon(Icons.lock_outline, size: 18)
                                        : const Icon(Icons.chevron_right),
                                    onTap: () => context.push('${AppRoutes.bookReader}?id=${book.id}'),
                                  ),
                                ),
                              )),
                        ] else
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text(
                              context.tr('books_empty'),
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.black54),
                            ),
                          ),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: () => context.push(AppRoutes.books),
                            child: Text(
                              books.isEmpty
                                  ? context.tr('books_see_all_pending')
                                  : context.tr('books_see_all'),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 10)),
        ],
      ),
      ),
    );
      },
    );
  }
}

class _NewsCard extends StatelessWidget {
  const _NewsCard({
    required this.item,
    required this.ratingValue,
    required this.commentCountValue,
    required this.onCommentsTap,
    required this.onBuyTap,
  });

  final _NewsItem item;
  final double ratingValue;
  final int commentCountValue;
  final VoidCallback onCommentsTap;
  final VoidCallback onBuyTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 312,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppShadows.soft(context),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 126,
              width: double.infinity,
              child: CachedRemoteImage(
                url: item.imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, _) {
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
                      color: context.appColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.star, size: 16, color: Colors.amber),
                      const SizedBox(width: 4),
                      Text(
                        ratingValue.toStringAsFixed(1),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Icon(
                        Icons.chat_bubble_outline,
                        size: 16,
                        color: context.appColors.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        context.tr(
                          'comments_count',
                          params: {'n': '$commentCountValue'},
                        ),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: context.appColors.textSecondary,
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
                          child: Text(context.tr('btn_comments')),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton(
                          onPressed: onBuyTap,
                          child: Text(context.tr('buy')),
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
    required this.id,
    required this.titleUz,
    required this.summaryUz,
    required this.feedbackKey,
    required this.platformCourseId,
    required this.telegramContact,
    required this.useFeedbackApi,
    required this.imageUrl,
    required this.rating,
    required this.commentCount,
    required this.priceText,
  });

  final String id;
  final String titleUz;
  final String summaryUz;
  /// Sharhlar/statistikada kalit (platforma kursi ID yoki tashqi reklama uchun banner ID).
  final String feedbackKey;
  /// `null` bo‘lsa bu karta ilova ichidagi kursga bog‘lanmaydi (faqat Telegram).
  final String? platformCourseId;
  final String telegramContact;
  final bool useFeedbackApi;
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
