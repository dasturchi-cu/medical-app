import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/config/api_config.dart';
import '../../../../core/di/providers.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/state/app_state_providers.dart';
import '../../../../core/state/auth_controller.dart';
import '../../../../core/state/lesson_assets_state.dart';
import '../../../../core/state/lesson_slides_state.dart';
import '../../../../core/state/progress_controller.dart';
import '../../../../widgets/video_player_box.dart';

class LessonViewPage extends ConsumerStatefulWidget {
  const LessonViewPage({super.key, required this.lessonId});

  final String lessonId;

  @override
  ConsumerState<LessonViewPage> createState() => _LessonViewPageState();
}

class _LessonViewPageState extends ConsumerState<LessonViewPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _slidesController = PageController();
  int _lastSyncedWatchSec = 0;
  bool _syncingWatch = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _slidesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(courseRepositoryProvider);
    final lesson = repo.getLessonById(widget.lessonId);
    final lessonSlidesAsync = ref.watch(lessonSlidesProvider(widget.lessonId));
    final courseId = repo.getCourseIdForLesson(widget.lessonId);
    final orientation = MediaQuery.orientationOf(context);
    final size = MediaQuery.sizeOf(context);
    final mediaHeight = orientation == Orientation.landscape
        ? size.height * 0.78
        : size.height * 0.38;

    if (lesson == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Dars'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.pop(),
          ),
        ),
        body: const Center(child: Text('Dars topilmadi')),
      );
    }

    final remoteSlides = lessonSlidesAsync.valueOrNull ?? const [];
    final lessonAssets = ref.watch(lessonAssetsProvider(widget.lessonId)).valueOrNull ?? const [];
    final assetSlides = lessonAssets
        .map(
          (asset) => _RenderedSlide(
            title: asset.title,
            body: asset.description,
            imageUrl: asset.previewImageUrl,
            assetType: asset.fileType,
            assetFileUrl: asset.fileUrl,
          ),
        )
        .toList(growable: false);
    final renderedSlides = remoteSlides.isNotEmpty
        ? remoteSlides
            .map(
              (item) => _RenderedSlide(
                title: item.title,
                body: item.body,
                imageUrl: item.imageUrl,
              ),
            )
            .toList(growable: false)
        : lesson.slides
            .map((text) => _RenderedSlide(title: text, body: '', imageUrl: ''))
            .toList(growable: false);
    final mergedSlides = [...renderedSlides, ...assetSlides];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dars tafsiloti'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(44),
          child: Container(
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: TabBar(
              controller: _tabController,
              labelColor: const Color(0xFF1E6BB8),
              unselectedLabelColor: Colors.black54,
              indicatorColor: const Color(0xFF1E6BB8),
              labelStyle: const TextStyle(fontWeight: FontWeight.w800),
              tabs: const [
                Tab(text: 'Video'),
                Tab(text: 'Slaydshou'),
              ],
            ),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        children: [
          AnimatedBuilder(
            animation: _tabController,
            builder: (context, _) {
              if (_tabController.index == 0) {
                return VideoPlayerBox(
                  url: lesson.videoUrl,
                  height: mediaHeight,
                  onWatchProgress: (watchedSec, completed) {
                    if (!mounted) return;
                    if (courseId == null) return;
                    _syncWatchProgress(
                      courseId: courseId,
                      watchedSec: watchedSec,
                      completed: completed,
                    );
                  },
                );
              }
              return _SlideViewer(
                slides: mergedSlides,
                controller: _slidesController,
                height: mediaHeight,
                lessonId: widget.lessonId,
              );
            },
          ),
          const SizedBox(height: 12),
          Text(
            'Dars matni',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 8),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Text(
                lesson.transcriptUz,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      height: 1.35,
                      color: Colors.black87,
                    ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: () {
                      if (courseId != null) {
                        ref.read(selectedCourseIdProvider.notifier).state = courseId;
                        ref
                            .read(progressControllerProvider.notifier)
                            .completeLesson(courseId: courseId, lessonId: widget.lessonId);
                        final course = repo.getCourseById(courseId);
                        String? sectionId;
                        if (course != null) {
                          for (final section in course.sections) {
                            final hasLesson = section.lessons.any(
                              (lessonItem) => lessonItem.id == widget.lessonId,
                            );
                            if (hasLesson) {
                              sectionId = section.id;
                              break;
                            }
                          }
                        }
                        if (sectionId != null && sectionId.isNotEmpty) {
                          context.pushReplacement(
                            '${AppRoutes.lessonList}?courseId=$courseId&sectionId=$sectionId',
                          );
                          return;
                        }
                      }
                      context.pop();
                    },
                    child: const Text(
                      'Darsni yakunlash',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF1E6BB8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: () {
                      if (courseId != null) {
                        ref.read(selectedCourseIdProvider.notifier).state = courseId;
                        ref
                            .read(progressControllerProvider.notifier)
                            .completeLesson(courseId: courseId, lessonId: widget.lessonId);
                      }
                      context.push('${AppRoutes.quiz}?id=${widget.lessonId}');
                    },
                    child: const Text(
                      'Testga o‘tish',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _syncWatchProgress({
    required String courseId,
    required int watchedSec,
    required bool completed,
  }) async {
    if (!mounted) return;
    final auth = ref.read(authControllerProvider);
    final userId = auth.userId ?? '';
    final baseUrl = getApiBaseUrl();
    if (userId.isEmpty || baseUrl.isEmpty) return;
    final shouldSync = completed || watchedSec >= _lastSyncedWatchSec + 20;
    if (!shouldSync || _syncingWatch) return;
    _syncingWatch = true;
    _lastSyncedWatchSec = watchedSec;
    try {
      debugPrint(
        '[API][courses.view][request] courseId=$courseId lessonId=${widget.lessonId} userId=$userId watchedSec=$watchedSec completed=$completed',
      );
      final response = await http.post(
        Uri.parse('$baseUrl/api/v1/courses/$courseId/views'),
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': userId,
          'lesson_id': widget.lessonId,
          'watched_sec': watchedSec,
          'completed': completed,
        }),
      );
      debugPrint('[API][courses.view][response] status=${response.statusCode}');
    } catch (error) {
      debugPrint('[API][courses.view][error] $error');
    } finally {
      _syncingWatch = false;
    }
  }
}

class _SlideViewer extends StatefulWidget {
  const _SlideViewer({
    required this.slides,
    required this.controller,
    required this.height,
    required this.lessonId,
  });

  final List<_RenderedSlide> slides;
  final PageController controller;
  final double height;
  final String lessonId;

  @override
  State<_SlideViewer> createState() => _SlideViewerState();
}

class _SlideViewerState extends State<_SlideViewer> {
  int _page = 0;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(covariant _SlideViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onScroll);
      widget.controller.addListener(_onScroll);
      _page = (widget.controller.page ?? 0).round();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onScroll);
    super.dispose();
  }

  void _onScroll() {
    final next = (widget.controller.page ?? 0).round();
    if (next == _page) return;
    setState(() => _page = next);
  }

  Future<void> _openFullscreen() async {
    if (widget.slides.isEmpty) return;
    await Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        builder: (_) => _FullscreenSlidePage(
          slides: widget.slides,
          initialIndex: _page,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final slides = widget.slides;
    final controller = widget.controller;
    if (slides.isEmpty) {
      return Container(
        height: widget.height,
        width: double.infinity,
        decoration: BoxDecoration(
          color: const Color(0xFF1E6BB8),
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.center,
        child: const Text(
          'Slaydlar hali qo\'shilmagan',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
      );
    }

    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: [
              SizedBox(
                height: widget.height,
                child: PageView.builder(
                  controller: controller,
                  itemCount: slides.length,
                  itemBuilder: (context, index) {
                    final slide = slides[index];
                    return Container(
                      color: const Color(0xFF1E6BB8),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Test slayd ${index + 1}',
                              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                    color: Colors.white70,
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              slide.title,
                              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                  ),
                            ),
                            if (slide.body.trim().isNotEmpty) ...[
                              const SizedBox(height: 10),
                              Text(
                                slide.body,
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: Colors.white.withValues(alpha: 0.88),
                                      height: 1.35,
                                    ),
                              ),
                            ],
                            if (slide.imageUrl.trim().isNotEmpty) ...[
                              const SizedBox(height: 12),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: _SlideImage(
                                  imageUrl: slide.imageUrl,
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                  height: widget.height * 0.38,
                                  placeholderHeight: widget.height * 0.28,
                                ),
                              ),
                            ],
                            if ((slide.assetType ?? '').toLowerCase() == 'pdf' && (slide.assetFileUrl ?? '').trim().isNotEmpty) ...[
                              const SizedBox(height: 10),
                              SizedBox(
                                height: widget.height * 0.38,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: _InlinePdfPreview(url: slide.assetFileUrl!),
                                ),
                              ),
                            ],
                            if ((slide.assetType ?? '').toLowerCase() == 'ppt' && (slide.assetFileUrl ?? '').trim().isNotEmpty) ...[
                              const SizedBox(height: 10),
                              FilledButton.icon(
                                style: FilledButton.styleFrom(
                                  backgroundColor: Colors.white.withValues(alpha: 0.18),
                                  foregroundColor: Colors.white,
                                ),
                                onPressed: () async {
                                  final uri = Uri.tryParse(slide.assetFileUrl!);
                                  if (uri == null) return;
                                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                                },
                                icon: const Icon(Icons.open_in_new),
                                label: const Text('PPT ni ochish'),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              Positioned(
                bottom: 10,
                right: 10,
                child: IconButton.filledTonal(
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.black.withValues(alpha: 0.35),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: _openFullscreen,
                  icon: const Icon(Icons.fullscreen),
                  tooltip: 'Katta ko‘rish',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        if (slides.length > 1)
          SmoothPageIndicator(
            controller: controller,
            count: slides.length,
            effect: WormEffect(
              dotWidth: 8,
              dotHeight: 8,
              activeDotColor: const Color(0xFF1E6BB8),
              dotColor: Colors.black.withValues(alpha: 0.14),
            ),
          ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              iconSize: 28,
              onPressed: () => controller.previousPage(
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOut,
              ),
              icon: const Icon(Icons.chevron_left),
            ),
            Text(
              '${_page + 1} / ${slides.length}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            IconButton(
              iconSize: 28,
              onPressed: () => controller.nextPage(
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOut,
              ),
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
      ],
    );
  }
}

class _FullscreenSlidePage extends StatefulWidget {
  const _FullscreenSlidePage({
    required this.slides,
    required this.initialIndex,
  });

  final List<_RenderedSlide> slides;
  final int initialIndex;

  @override
  State<_FullscreenSlidePage> createState() => _FullscreenSlidePageState();
}

class _FullscreenSlidePageState extends State<_FullscreenSlidePage> {
  late final PageController _controller;
  late int _index;

  @override
  void initState() {
    super.initState();
    if (widget.slides.isEmpty) {
      _index = 0;
      _controller = PageController(initialPage: 0);
      return;
    }
    _index = widget.initialIndex.clamp(0, widget.slides.length - 1);
    _controller = PageController(initialPage: _index);
    _lockLandscape();
  }

  Future<void> _lockLandscape() async {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  Future<void> _unlockOrientation() async {
    await SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  @override
  void dispose() {
    _unlockOrientation();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _controller,
            itemCount: widget.slides.length,
            onPageChanged: (v) => setState(() => _index = v),
            itemBuilder: (context, i) {
              final slide = widget.slides[i];
              return Container(
                color: const Color(0xFF1E6BB8),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (slide.imageUrl.trim().isNotEmpty)
                      _SlideImage(
                        imageUrl: slide.imageUrl,
                        fit: BoxFit.cover,
                        placeholderHeight: double.infinity,
                      ),
                    if (slide.title.trim().isNotEmpty || slide.body.trim().isNotEmpty)
                      Align(
                        alignment: Alignment.topLeft,
                        child: Container(
                          margin: const EdgeInsets.fromLTRB(18, 18, 18, 0),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.32),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Test slayd ${i + 1}',
                                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                      color: Colors.white70,
                                      fontWeight: FontWeight.w800,
                                    ),
                              ),
                              if (slide.title.trim().isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Text(
                                  slide.title,
                                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w900,
                                      ),
                                ),
                              ],
                              if (slide.body.trim().isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Text(
                                  slide.body,
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                        color: Colors.white.withValues(alpha: 0.9),
                                      ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
          Positioned(
            top: 8,
            left: 8,
            child: IconButton.filledTonal(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close_fullscreen),
              tooltip: 'Chiqish',
            ),
          ),
          Positioned(
            bottom: 12,
            right: 12,
            child: IconButton.filledTonal(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.fullscreen_exit),
              tooltip: 'Kichraytirish',
            ),
          ),
          Positioned(
            bottom: 12,
             left: 0,
            right: 0,
            child: Column(
              children: [
                AnimatedSmoothIndicator(
                  activeIndex: _index,
                  count: widget.slides.length,
                  effect: const WormEffect(
                    dotWidth: 8,
                    dotHeight: 8,
                    activeDotColor: Colors.white,
                    dotColor: Color(0x80FFFFFF),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${_index + 1} / ${widget.slides.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RenderedSlide {
  const _RenderedSlide({
    required this.title,
    required this.body,
    required this.imageUrl,
    this.assetType,
    this.assetFileUrl,
  });

  final String title;
  final String body;
  final String imageUrl;
  final String? assetType;
  final String? assetFileUrl;
}

class _InlinePdfPreview extends StatefulWidget {
  const _InlinePdfPreview({required this.url});

  final String url;

  @override
  State<_InlinePdfPreview> createState() => _InlinePdfPreviewState();
}

class _InlinePdfPreviewState extends State<_InlinePdfPreview> {
  late final Future<Uint8List> _bytesFuture;

  @override
  void initState() {
    super.initState();
    _bytesFuture = _loadBytes(widget.url);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List>(
      future: _bytesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator(color: Colors.white));
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return _error(
            snapshot.error is Exception
                ? (snapshot.error as Exception).toString().replaceFirst('Exception: ', '')
                : "PDF ni ochib bo'lmadi",
          );
        }
        return SfPdfViewer.memory(snapshot.data!);
      },
    );
  }

  Future<Uint8List> _loadBytes(String raw) async {
    final value = raw.trim();
    if (value.startsWith('data:application/pdf')) {
      final comma = value.indexOf(',');
      if (comma <= 0) throw Exception("PDF formati noto'g'ri.");
      try {
        return base64Decode(value.substring(comma + 1).replaceAll(RegExp(r'\s'), ''));
      } catch (_) {
        throw Exception("PDF ni o'qib bo'lmadi.");
      }
    }
    final uri = Uri.tryParse(value);
    if (uri == null) throw Exception("PDF URL noto'g'ri.");
    final response = await http.get(uri);
    if (response.statusCode != 200) {
      final body = response.body.toLowerCase();
      if (body.contains('bucket not found')) {
        throw Exception("Storage bucket topilmadi.");
      }
      throw Exception("PDF yuklanmadi (status: ${response.statusCode}).");
    }
    return response.bodyBytes;
  }

  Widget _error(String message) {
    return Container(
      color: const Color(0xFF0E4E8E),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(12),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.white),
      ),
    );
  }
}

class _SlideImage extends StatelessWidget {
  const _SlideImage({
    required this.imageUrl,
    required this.fit,
    this.width,
    this.height,
    required this.placeholderHeight,
  });

  final String imageUrl;
  final BoxFit fit;
  final double? width;
  final double? height;
  final double placeholderHeight;

  @override
  Widget build(BuildContext context) {
    final raw = imageUrl.trim();
    if (raw.isEmpty) return _placeholder();

    if (raw.startsWith('data:image')) {
      final commaIndex = raw.indexOf(',');
      if (commaIndex > 0) {
        final payload = raw.substring(commaIndex + 1).replaceAll(RegExp(r'\s'), '');
        try {
          final bytes = base64Decode(payload);
          return Image.memory(
            bytes,
            fit: fit,
            width: width,
            height: height,
            errorBuilder: (_, _, _) => _placeholder(),
          );
        } catch (_) {
          return _placeholder();
        }
      }
      return _placeholder();
    }

    final normalized = _normalizeImageUrl(raw);
    return Image.network(
      normalized,
      fit: fit,
      width: width,
      height: height,
      errorBuilder: (_, _, _) => _placeholder(),
    );
  }

  String _normalizeImageUrl(String value) {
    if (value.startsWith('http://') || value.startsWith('https://')) return value;
    final base = getApiBaseUrl().replaceAll(RegExp(r'/+$'), '');
    final path = value.startsWith('/') ? value : '/$value';
    return '$base$path';
  }

  Widget _placeholder() {
    return Container(
      height: placeholderHeight,
      alignment: Alignment.center,
      color: Colors.white.withValues(alpha: 0.16),
      child: const Text(
        'Rasmni yuklab bo\'lmadi',
        style: TextStyle(color: Colors.white),
      ),
    );
  }
}

