import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/config/api_config.dart';
import '../../../../core/di/providers.dart';
import '../../../../core/services/course_progress_remote_sync.dart';
import '../../../../core/services/lesson_slides_bytes_cache.dart';
import '../../../../core/services/media_url_resolver.dart';
import '../../../../core/services/screen_protection.dart';
import '../../../../core/services/video_lesson_position_store.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/state/app_state_providers.dart';
import '../../../../core/state/auth_controller.dart';
import '../../../../core/state/lesson_assets_state.dart';
import '../../../../core/state/lesson_slides_state.dart';
import '../../../../core/data/repositories/course_repository.dart';
import '../../../../core/data/repositories/ranking_repository.dart';
import '../../../../core/state/progress_controller.dart';
import '../../../../widgets/video_player_box.dart';

bool _renderedSlideHasVisual(_RenderedSlide slide) {
  if (slide.imageUrl.trim().isNotEmpty) return true;
  return (slide.assetFileUrl ?? '').trim().isNotEmpty;
}

bool _slideIsPdfAsset(_RenderedSlide slide) {
  return (slide.assetType ?? '').toLowerCase() == 'pdf' &&
      (slide.assetFileUrl ?? '').trim().isNotEmpty;
}

bool _slideIsPptAsset(_RenderedSlide slide) {
  return (slide.assetType ?? '').toLowerCase() == 'ppt' &&
      (slide.assetFileUrl ?? '').trim().isNotEmpty;
}

bool _slideHasCoverImage(_RenderedSlide slide) {
  return slide.imageUrl.trim().isNotEmpty && !_slideIsPdfAsset(slide);
}

/// `lesson_assets` bo‘lsa ham, mirror qilingan `lesson_slides` ko‘proq bo‘lishi mumkin —
/// faqat assetlarni tanlash jami slayd/rasm sonini pasaytirardi.
List<_RenderedSlide> _mergeLessonSlidesAndAssets({
  required List<_RenderedSlide> assetSlides,
  required List<_RenderedSlide> renderedSlides,
  required bool hasLessonAssets,
  required bool hasRemoteLessonSlides,
}) {
  if (!hasLessonAssets) return renderedSlides;
  if (!hasRemoteLessonSlides) return assetSlides;

  final visualsFromSlides =
      renderedSlides.where(_renderedSlideHasVisual).length;
  final visualsFromAssets =
      assetSlides.where(_renderedSlideHasVisual).length;
  final preferRendered =
      renderedSlides.length > assetSlides.length ||
          visualsFromSlides > visualsFromAssets;

  return preferRendered ? renderedSlides : assetSlides;
}

class LessonViewPage extends ConsumerStatefulWidget {
  const LessonViewPage({super.key, required this.lessonId});

  final String lessonId;

  @override
  ConsumerState<LessonViewPage> createState() => _LessonViewPageState();
}

class _LessonViewPageState extends ConsumerState<LessonViewPage>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final TabController _tabController;
  late PageController _slidesController;
  int _lastSyncedWatchSec = 0;
  bool _syncingWatch = false;
  int _initialWatchedSec = 0;
  /// Joriy ijro pozitsiyasi — faqat player ichida; parent rebuildda nolga tushmasin.
  int _liveWatchSec = 0;
  int _pendingPlaybackDeltaSec = 0;
  DateTime? _lastProgressSyncAt;
  bool _loadingInitialProgress = false;
  String? _loadedProgressKey;
  bool _progressLoadScheduled = false;
  bool _firstWatchProgressFlushed = false;

  ProgressController? _progressNotifier;
  CourseRepository? _courseRepo;
  String? _cachedUserId;
  String _cachedBaseUrl = '';
  String? _cachedLessonId;
  String? _cachedCourseIdForFlush;
  bool _lessonDisposed = false;
  StateController<bool>? _videoImmersiveCtrl;
  final GlobalKey<VideoPlayerBoxState> _lessonVideoKey =
      GlobalKey<VideoPlayerBoxState>();
  Widget? _pinnedLessonVideo;
  String? _pinnedLessonVideoKey;

  void _onVideoImmersiveChanged(bool immersive) {
    if (!mounted) return;
    _videoImmersiveCtrl?.state = immersive;
  }

  String? _positionStorageKey() {
    final userId = (_cachedUserId ?? '').trim();
    if (userId.isEmpty) return null;
    return '$userId|${widget.lessonId}';
  }

  Widget _pinnedVideoPlayer({
    required double height,
    required String videoUrl,
    required String? catalogDurationLabel,
    required int bootstrapSec,
    required String? courseId,
    required void Function(int watchedSec, bool completed, int playbackDeltaSec)?
        onWatchProgress,
  }) {
    final pinKey = '${widget.lessonId}|$videoUrl';
    if (_pinnedLessonVideoKey != pinKey) {
      _pinnedLessonVideoKey = pinKey;
      _pinnedLessonVideo = VideoPlayerBox(
        key: _lessonVideoKey,
        url: videoUrl,
        height: height,
        catalogDurationLabel: catalogDurationLabel,
        initialWatchedSec: bootstrapSec,
        positionStorageKey: _positionStorageKey(),
        onImmersiveModeChanged: _onVideoImmersiveChanged,
        onWatchProgress: onWatchProgress,
      );
    }
    return _pinnedLessonVideo!;
  }

  void _cacheWatchDependencies() {
    if (!mounted) return;
    _progressNotifier = ref.read(progressControllerProvider.notifier);
    _courseRepo = ref.read(courseRepositoryProvider);
    _cachedUserId = ref.read(authControllerProvider).userId;
    _cachedBaseUrl = getApiBaseUrl();
  }

  @override
  void initState() {
    super.initState();
    unawaited(ScreenProtection.enable());
    _videoImmersiveCtrl = ref.read(videoImmersiveProvider.notifier);
    WidgetsBinding.instance.addObserver(this);
    _tabController = TabController(length: 2, vsync: this);
    _slidesController = PageController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _cacheWatchDependencies();
      unawaited(_loadLocalResumePosition());
    });
  }

  Future<void> _loadLocalResumePosition() async {
    final key = _positionStorageKey();
    if (key == null) return;
    final local = await VideoLessonPositionStore.load(key);
    if (!mounted || local <= 0) return;
    setState(() {
      if (local > _initialWatchedSec) _initialWatchedSec = local;
      if (local > _liveWatchSec) _liveWatchSec = local;
    });
    await _lessonVideoKey.currentState?.restorePlaybackPosition(local);
  }

  @override
  void dispose() {
    unawaited(ScreenProtection.disable());
    _lessonDisposed = true;
    _videoImmersiveCtrl?.state = false;
    WidgetsBinding.instance.removeObserver(this);
    _flushWatchProgressOnDispose();
    _tabController.dispose();
    _slidesController.dispose();
    super.dispose();
  }

  void _onVideoWatchProgress({
    required String courseId,
    required int watchedSec,
    required bool completed,
    required int playbackDeltaSec,
  }) {
    if (_lessonDisposed) return;
    _liveWatchSec = watchedSec;
    final storageKey = _positionStorageKey();
    if (storageKey != null && watchedSec > 0) {
      unawaited(VideoLessonPositionStore.save(storageKey, watchedSec));
    }
    _cachedCourseIdForFlush = courseId;
    if (watchedSec > 0 || completed) {
      _progressNotifier?.noteLessonPlayback(
        courseId,
        widget.lessonId,
        completed: completed,
      );
    }
    _queueWatchProgress(
      courseId: courseId,
      watchedSec: watchedSec,
      completed: completed,
      playbackDeltaSec: playbackDeltaSec,
    );
  }

  /// dispose() da ref/mounted ishlatilmaydi.
  void _flushWatchProgressOnDispose() {
    final userId = _cachedUserId ?? '';
    final baseUrl = _cachedBaseUrl;
    final repo = _courseRepo;
    final lessonId = _cachedLessonId ?? widget.lessonId;
    if (userId.isEmpty || baseUrl.isEmpty || repo == null) return;

    final courseId =
        _cachedCourseIdForFlush ?? repo.getCourseIdForLesson(lessonId);
    if (courseId == null) return;

    final sec = _liveWatchSec > 0 ? _liveWatchSec : _initialWatchedSec;
    final delta = _pendingPlaybackDeltaSec > 0 ? _pendingPlaybackDeltaSec : (sec > 0 ? 1 : 0);
    if (sec <= 0 && delta <= 0) return;

    final pendingDelta = delta;
    final body = jsonEncode({
      'user_id': userId,
      'lesson_id': lessonId,
      'watched_sec': sec,
      'completed': false,
      'playback_delta_sec': pendingDelta,
    });

    debugPrint(
      '[VIDEO_PROGRESS] dispose-safe save lessonId=$lessonId sec=$sec delta=$pendingDelta',
    );

    unawaited(
      http
          .post(
            Uri.parse('$baseUrl/api/v1/courses/$courseId/views'),
            headers: const {'Content-Type': 'application/json'},
            body: body,
          )
          .timeout(const Duration(seconds: 8))
          .then((response) {
        debugPrint(
          '[VIDEO_PROGRESS] dispose-safe done status=${response.statusCode}',
        );
      })
          .catchError((Object e) {
        debugPrint('[VIDEO_PROGRESS] dispose-safe failed $e');
      }),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      unawaited(_flushWatchProgressToServer(force: true));
    }
  }

  @override
  void didUpdateWidget(covariant LessonViewPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.lessonId != widget.lessonId) {
      _slidesController.dispose();
      _slidesController = PageController();
      _pinnedLessonVideo = null;
      _pinnedLessonVideoKey = null;
      _liveWatchSec = 0;
      _initialWatchedSec = 0;
      _lastSyncedWatchSec = 0;
      _firstWatchProgressFlushed = false;
      _pendingPlaybackDeltaSec = 0;
      _loadedProgressKey = null;
      _progressLoadScheduled = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    _cacheWatchDependencies();
    _cachedLessonId = widget.lessonId;
    final repo = ref.watch(courseRepositoryProvider);
    final lesson = repo.getLessonById(widget.lessonId);
    final lessonSlidesAsync = ref.watch(lessonSlidesProvider(widget.lessonId));
    final courseId = repo.getCourseIdForLesson(widget.lessonId);
    final size = MediaQuery.sizeOf(context);
    // 16:9 — balandlikni barqaror tutamiz (aylantirishda player remount bo‘lmasin).
    final mediaHeight = (size.shortestSide * 9 / 16).clamp(200.0, 420.0);

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
    final lessonAssets =
        ref.watch(lessonAssetsProvider(widget.lessonId)).valueOrNull ??
        const [];
    final sortedAssets = [...lessonAssets]
      ..sort((a, b) => a.orderNo.compareTo(b.orderNo));
    final assetSlides = sortedAssets
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
              .map(
                (text) => _RenderedSlide(title: text, body: '', imageUrl: ''),
              )
              .toList(growable: false);
    final mergedSlides = _mergeLessonSlidesAndAssets(
      assetSlides: assetSlides,
      renderedSlides: renderedSlides,
      hasLessonAssets: lessonAssets.isNotEmpty,
      hasRemoteLessonSlides: remoteSlides.isNotEmpty,
    );
    final showLessonTextBlock =
        lesson.transcriptUz.trim().isNotEmpty &&
            !mergedSlides.any(_renderedSlideHasVisual);

    final bootstrapSec =
        _initialWatchedSec > 0 ? _initialWatchedSec : _liveWatchSec;

    final videoImmersive = ref.watch(videoImmersiveProvider);

    Widget buildVideoSlot(double height) {
      final player = _pinnedVideoPlayer(
        height: height,
        videoUrl: lesson.videoUrl,
        catalogDurationLabel: lesson.durationUz,
        bootstrapSec: bootstrapSec,
        courseId: courseId,
        onWatchProgress: courseId == null
            ? null
            : (watchedSec, completed, playbackDeltaSec) {
                _onVideoWatchProgress(
                  courseId: courseId,
                  watchedSec: watchedSec,
                  completed: completed,
                  playbackDeltaSec: playbackDeltaSec,
                );
              },
      );
      return ListenableBuilder(
        listenable: _tabController,
        builder: (context, _) {
          return IndexedStack(
            index: videoImmersive ? 0 : _tabController.index,
            sizing: StackFit.loose,
            children: [
              RepaintBoundary(child: player),
              _SlideViewer(
                slides: mergedSlides,
                controller: _slidesController,
                height: height,
                lessonId: widget.lessonId,
              ),
            ],
          );
        },
      );
    }

    final lessonScrollChildren = <Widget>[
      if (showLessonTextBlock) ...[
        Text(
          'Dars matni',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
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
      ],
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
                    ref.read(selectedCourseIdProvider.notifier).state =
                        courseId;
                    unawaited(_completeLessonAndSync(courseId: courseId));
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
                    ref.read(selectedCourseIdProvider.notifier).state =
                        courseId;
                    unawaited(_completeLessonAndSync(courseId: courseId));
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
    ];

    return PopScope(
      canPop: !videoImmersive,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          ref.read(videoImmersiveProvider.notifier).state = false;
          unawaited(CourseProgressRemoteSync.refresh(ref));
          return;
        }
        if (videoImmersive) {
          unawaited(_lessonVideoKey.currentState?.exitImmersive());
        }
      },
      child: Scaffold(
        backgroundColor: videoImmersive ? Colors.black : null,
        appBar: videoImmersive
            ? null
            : AppBar(
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
                      unselectedLabelColor:
                          Theme.of(context).colorScheme.onSurfaceVariant,
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
        body: LayoutBuilder(
          builder: (context, constraints) {
            final videoLayer = ColoredBox(
              color: Colors.black,
              child: Builder(
                builder: (context) {
                  if (courseId != null && !_progressLoadScheduled) {
                    _progressLoadScheduled = true;
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) {
                        _ensureInitialWatchProgressLoaded(courseId);
                      }
                    });
                  }
                  return buildVideoSlot(mediaHeight);
                },
              ),
            );

            return Stack(
              fit: StackFit.expand,
              children: [
                if (videoImmersive)
                  const Positioned.fill(
                    child: ColoredBox(color: Colors.black),
                  ),
                if (!videoImmersive) ...[
                  Positioned(
                    top: mediaHeight,
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                      children: lessonScrollChildren,
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    top: 0,
                    height: mediaHeight,
                    child: videoLayer,
                  ),
                ],
                if (videoImmersive)
                  Positioned.fill(child: videoLayer),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _completeLessonAndSync({required String courseId}) async {
    ref.read(progressControllerProvider.notifier).completeLesson(
          courseId: courseId,
          lessonId: widget.lessonId,
        );
    final watchedSec =
        _liveWatchSec > 0 ? _liveWatchSec : _initialWatchedSec;
    await _flushWatchProgressToServer(
      courseId: courseId,
      watchedSec: watchedSec,
      completed: true,
      force: true,
    );
  }

  void _queueWatchProgress({
    required String courseId,
    required int watchedSec,
    required bool completed,
    required int playbackDeltaSec,
  }) {
    if (playbackDeltaSec > 0) {
      _pendingPlaybackDeltaSec += playbackDeltaSec;
    }
    debugPrint(
      '[VIDEO_PROGRESS] progress event sec=$watchedSec delta=$playbackDeltaSec pending=$_pendingPlaybackDeltaSec',
    );
    final now = DateTime.now();
    final last = _lastProgressSyncAt;
    final due = last == null || now.difference(last) >= const Duration(seconds: 3);
    final firstSave = !_firstWatchProgressFlushed && _pendingPlaybackDeltaSec > 0;
    if (completed || firstSave || due) {
      if (firstSave) {
        debugPrint('[VIDEO_PROGRESS] immediate first flush sec=$watchedSec');
      }
      unawaited(
        _flushWatchProgressToServer(
          courseId: courseId,
          watchedSec: watchedSec,
          completed: completed,
          force: completed || firstSave,
        ),
      );
    }
  }

  Future<void> _flushWatchProgressToServer({
    String? courseId,
    int? watchedSec,
    bool completed = false,
    bool force = false,
  }) async {
    if (_lessonDisposed || !mounted) return;
    _cacheWatchDependencies();
    final userId = _cachedUserId ?? '';
    final baseUrl =
        _cachedBaseUrl.isNotEmpty ? _cachedBaseUrl : getApiBaseUrl();
    if (userId.isEmpty || baseUrl.isEmpty) return;

    final repo = _courseRepo;
    if (repo == null) return;
    final resolvedCourseId =
        courseId ?? repo.getCourseIdForLesson(widget.lessonId);
    if (resolvedCourseId == null) return;

    final sec = watchedSec ?? (_liveWatchSec > 0 ? _liveWatchSec : _initialWatchedSec);
    if (sec <= 0 && !completed && _pendingPlaybackDeltaSec <= 0) return;
    if (!force &&
        !completed &&
        sec <= _lastSyncedWatchSec &&
        _pendingPlaybackDeltaSec <= 0) {
      return;
    }

    if (_syncingWatch && !force && !completed) return;

    final deltaForServer = _pendingPlaybackDeltaSec > 0
        ? _pendingPlaybackDeltaSec
        : (completed || force ? 1 : 0);
    if (deltaForServer <= 0 && !completed && !force) return;

    _syncingWatch = true;
    final pendingDelta = deltaForServer;
    _lastSyncedWatchSec = sec;
    _pendingPlaybackDeltaSec = 0;
    _lastProgressSyncAt = DateTime.now();
    if (!_firstWatchProgressFlushed && pendingDelta > 0) {
      _firstWatchProgressFlushed = true;
    }

    try {
      debugPrint(
        '[VIDEO_PROGRESS] save start courseId=$resolvedCourseId lessonId=${widget.lessonId} watchedSec=$sec delta=$pendingDelta',
      );
      final response = await http.post(
        Uri.parse('$baseUrl/api/v1/courses/$resolvedCourseId/views'),
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': userId,
          'lesson_id': widget.lessonId,
          'watched_sec': sec,
          'completed': completed,
          'playback_delta_sec': pendingDelta,
        }),
      );
      if (response.statusCode >= 200 && response.statusCode < 300) {
        debugPrint('[VIDEO_PROGRESS] save success status=${response.statusCode}');
        ref.read(rankingRepositoryProvider).invalidateVideoRankingCache();
      } else {
        debugPrint(
          '[VIDEO_PROGRESS] save failed status=${response.statusCode} body=${response.body}',
        );
      }
    } catch (error) {
      debugPrint('[VIDEO_PROGRESS] save failed $error');
    } finally {
      _syncingWatch = false;
    }
  }

  Future<void> _ensureInitialWatchProgressLoaded(String courseId) async {
    _cachedCourseIdForFlush = courseId;
    final userId = _cachedUserId ?? '';
    final baseUrl =
        _cachedBaseUrl.isNotEmpty ? _cachedBaseUrl : getApiBaseUrl();
    if (userId.isEmpty || baseUrl.isEmpty) return;
    final key = '$userId|$courseId|${widget.lessonId}';
    if (_loadedProgressKey == key || _loadingInitialProgress) return;
    _loadingInitialProgress = true;
    try {
      final uri = Uri.parse(
        '$baseUrl/api/v1/courses/progress'
        '?user_id=$userId&course_id=$courseId&lesson_id=${widget.lessonId}',
      );
      final response = await http.get(uri);
      if (response.statusCode < 200 || response.statusCode >= 300) return;
      final body = jsonDecode(response.body);
      if (body is! Map<String, dynamic>) return;
      final items = body['items'];
      if (items is! List || items.isEmpty) {
        _loadedProgressKey = key;
        return;
      }
      final row = items.first;
      if (row is! Map<String, dynamic>) return;
      final watched = int.tryParse((row['watched_sec'] ?? '0').toString()) ?? 0;
      final localKey = _positionStorageKey();
      final local = localKey != null
          ? await VideoLessonPositionStore.load(localKey)
          : 0;
      final best = watched > local ? watched : local;
      if (!mounted) return;
      if (best > _liveWatchSec) {
        _liveWatchSec = best;
      }
      if (best > _initialWatchedSec) {
        _initialWatchedSec = best;
      }
      _lastSyncedWatchSec = best;
      _loadedProgressKey = key;
      if (mounted && best > 0) {
        await _lessonVideoKey.currentState?.restorePlaybackPosition(best);
      }
    } catch (_) {
      // Silent fail: player still starts from 0 if restore failed.
    } finally {
      _loadingInitialProgress = false;
    }
  }
}

/// Qo‘lda surilganda sahifalar tezroq “snap” bo‘lishi uchun qattiq spring.
class _SnappyPageScrollPhysics extends PageScrollPhysics {
  const _SnappyPageScrollPhysics({super.parent});

  @override
  _SnappyPageScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return _SnappyPageScrollPhysics(parent: buildParent(ancestor));
  }

  @override
  SpringDescription get spring => SpringDescription.withDampingRatio(
        mass: 0.42,
        stiffness: 9000,
        ratio: 1.02,
      );
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
  PdfViewerController? _pdfDeckController;
  int? _pdfPageNumber;
  int? _pdfPageCount;
  bool _showControls = true;
  Timer? _controlsTimer;

  @override
  void initState() {
    super.initState();
    _showControlsTemporarily();
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncPageFromController());
  }

  @override
  void didUpdateWidget(covariant _SlideViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    final lessonChanged = oldWidget.lessonId != widget.lessonId;
    final countChanged = oldWidget.slides.length != widget.slides.length;
    final controllerChanged = oldWidget.controller != widget.controller;
    if (controllerChanged) {
      _page = 0;
    }
    if (lessonChanged || countChanged || controllerChanged) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _syncPageFromController());
    }
  }

  void _syncPageFromController() {
    if (!mounted || widget.slides.isEmpty) return;
    final maxIdx = widget.slides.length - 1;
    if (!widget.controller.hasClients) {
      final initial = widget.controller.initialPage.clamp(0, maxIdx);
      if (_page != initial) setState(() => _page = initial);
      return;
    }
    final fromOffset =
        (widget.controller.page ?? widget.controller.initialPage.toDouble())
            .round()
            .clamp(0, maxIdx);
    if (fromOffset != _page) setState(() => _page = fromOffset);
  }

  void _onPageChanged(int index) {
    if (!mounted || widget.slides.isEmpty) return;
    final clamped = index.clamp(0, widget.slides.length - 1);
    if (clamped == _page) return;
    setState(() {
      _page = clamped;
      _pdfDeckController = null;
      _pdfPageNumber = null;
      _pdfPageCount = null;
    });
    _showControlsTemporarily();
  }

  void _onPdfControllerReady(int slideIndex, PdfViewerController c) {
    if (!mounted || slideIndex != _page) return;
    setState(() => _pdfDeckController = c);
  }

  void _onPdfControllerDisposed(PdfViewerController c) {
    if (_pdfDeckController != c) return;
    _pdfDeckController = null;
    if (mounted) setState(() {});
  }

  void _onPdfPaginationFromViewer(int slideIndex, int page, int totalPages) {
    if (!mounted || slideIndex != _page || totalPages <= 0) return;
    final safePage = page.clamp(1, totalPages);
    setState(() {
      _pdfPageNumber = safePage;
      _pdfPageCount = totalPages;
    });
    _showControlsTemporarily();
  }

  void _showControlsTemporarily() {
    _controlsTimer?.cancel();
    if (mounted) {
      setState(() => _showControls = true);
    }
    _controlsTimer = Timer(const Duration(seconds: 1), () {
      if (!mounted) return;
      setState(() => _showControls = false);
    });
  }

  bool _chromePrevEnabled(List<_RenderedSlide> slides) {
    final slide = slides[_page];
    if (_slideIsPdfAsset(slide) &&
        (_pdfPageCount ?? 0) > 1 &&
        _pdfDeckController != null) {
      final pn = _pdfPageNumber ?? 1;
      if (pn > 1) return true;
      return slides.length > 1 && _page > 0;
    }
    return slides.length > 1 && _page > 0;
  }

  bool _chromeNextEnabled(List<_RenderedSlide> slides) {
    final slide = slides[_page];
    if (_slideIsPdfAsset(slide) &&
        (_pdfPageCount ?? 0) > 1 &&
        _pdfDeckController != null) {
      final pn = _pdfPageNumber ?? 1;
      final tc = _pdfPageCount!;
      if (pn < tc) return true;
      return slides.length > 1 && _page < slides.length - 1;
    }
    return slides.length > 1 && _page < slides.length - 1;
  }

  void _chromePrev(PageController carousel) {
    final slides = widget.slides;
    final slide = slides[_page];
    if (_slideIsPdfAsset(slide) &&
        (_pdfPageCount ?? 0) > 1 &&
        _pdfDeckController != null) {
      final pn = _pdfPageNumber ?? 1;
      if (pn > 1) {
        _pdfDeckController!.previousPage();
        _showControlsTemporarily();
        return;
      }
    }
    if (slides.length > 1 && _page > 0) {
      _showControlsTemporarily();
      carousel.previousPage(
        duration: const Duration(milliseconds: 65),
        curve: Curves.easeOut,
      );
    }
  }

  void _chromeNext(PageController carousel) {
    final slides = widget.slides;
    final slide = slides[_page];
    if (_slideIsPdfAsset(slide) &&
        (_pdfPageCount ?? 0) > 1 &&
        _pdfDeckController != null) {
      final pn = _pdfPageNumber ?? 1;
      final tc = _pdfPageCount!;
      if (pn < tc) {
        _pdfDeckController!.nextPage();
        _showControlsTemporarily();
        return;
      }
    }
    if (slides.length > 1 && _page < slides.length - 1) {
      _showControlsTemporarily();
      carousel.nextPage(
        duration: const Duration(milliseconds: 65),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  void dispose() {
    _controlsTimer?.cancel();
    super.dispose();
  }

  Future<void> _openFullscreen() async {
    if (widget.slides.isEmpty) return;
    await Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            _FullscreenSlidePage(slides: widget.slides, initialIndex: _page),
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

    final deckSlide = slides[_page];
    final pdfPaginationKnown = _slideIsPdfAsset(deckSlide) &&
        (_pdfPageCount != null && _pdfPageCount! > 0);
    final chromeNumerator =
        pdfPaginationKnown ? (_pdfPageNumber ?? 1) : (_page + 1);
    final chromeDenominator =
        pdfPaginationKnown ? _pdfPageCount! : slides.length;

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: widget.height,
        width: double.infinity,
        child: Stack(
          clipBehavior: Clip.hardEdge,
          fit: StackFit.expand,
          children: [
            PageView.builder(
              controller: controller,
              scrollDirection: Axis.horizontal,
              physics: const _SnappyPageScrollPhysics().applyTo(
                ClampingScrollPhysics(),
              ),
              itemCount: slides.length,
              onPageChanged: _onPageChanged,
              itemBuilder: (context, index) {
                    final slide = slides[index];
                    final isPdf = _slideIsPdfAsset(slide);
                    final isPpt = _slideIsPptAsset(slide);
                    final cover = _slideHasCoverImage(slide);

                    late final Widget layer;
                    if (cover) {
                      layer = ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: _SlideImage(
                          imageUrl: slide.imageUrl,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                          placeholderHeight: widget.height,
                        ),
                      );
                    } else if (isPdf) {
                      layer = Padding(
                        padding: const EdgeInsets.all(6),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: _InlinePdfPreview(
                            key: ValueKey(slide.assetFileUrl),
                            url: slide.assetFileUrl!,
                            slideIndex: index,
                            isActiveDeckSlide: index == _page,
                            onControllerReady: _onPdfControllerReady,
                            onControllerDisposed: _onPdfControllerDisposed,
                            onPaginationFromPdf: _onPdfPaginationFromViewer,
                          ),
                        ),
                      );
                    } else if (isPpt) {
                      layer = Center(
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor:
                                Colors.white.withValues(alpha: 0.22),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 14,
                            ),
                          ),
                          onPressed: () async {
                            final resolved = MediaUrlResolver.resolveFetchUrl(
                              slide.assetFileUrl!,
                              apiBaseUrl: getApiBaseUrl(),
                            );
                            final uri = Uri.tryParse(resolved);
                            if (uri == null) return;
                            await launchUrl(
                              uri,
                              mode: LaunchMode.externalApplication,
                            );
                          },
                          icon: const Icon(Icons.open_in_new),
                          label: const Text('PPT ni ochish'),
                        ),
                      );
                    } else {
                      layer = Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                slide.title,
                                textAlign: TextAlign.center,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleLarge
                                    ?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                    ),
                              ),
                              if (slide.body.trim().isNotEmpty) ...[
                                const SizedBox(height: 10),
                                Text(
                                  slide.body,
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(
                                        color: Colors.white.withValues(
                                          alpha: 0.9,
                                        ),
                                      ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    }

                    return Stack(
                      fit: StackFit.expand,
                      children: [
                        const ColoredBox(color: Color(0xFF1E6BB8)),
                        Positioned.fill(child: layer),
                      ],
                    );
                  },
                ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton.filledTonal(
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black.withValues(alpha: 0.4),
                  foregroundColor: Colors.white,
                ),
                onPressed: _openFullscreen,
                icon: const Icon(Icons.fullscreen),
                tooltip: 'Katta ko‘rish',
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: IgnorePointer(
                ignoring: !_showControls,
                child: AnimatedOpacity(
                  opacity: _showControls ? 1 : 0,
                  duration: const Duration(milliseconds: 220),
                  child: SafeArea(
                    top: false,
                    minimum: const EdgeInsets.only(bottom: 6),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                      child: Row(
                        children: [
                          IconButton(
                            iconSize: 20,
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.black.withValues(alpha: 0.35),
                              foregroundColor: Colors.white,
                              minimumSize: const Size(36, 36),
                              padding: EdgeInsets.zero,
                            ),
                            onPressed: _chromePrevEnabled(slides) ? () => _chromePrev(controller) : null,
                            icon: const Icon(Icons.chevron_left),
                          ),
                          Expanded(
                            child: Center(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.4),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  '$chromeNumerator / $chromeDenominator',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          IconButton(
                            iconSize: 20,
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.black.withValues(alpha: 0.35),
                              foregroundColor: Colors.white,
                              minimumSize: const Size(36, 36),
                              padding: EdgeInsets.zero,
                            ),
                            onPressed: _chromeNextEnabled(slides) ? () => _chromeNext(controller) : null,
                            icon: const Icon(Icons.chevron_right),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
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
  int? _fullscreenPdfPage;
  int? _fullscreenPdfTotal;
  bool _showControls = true;
  Timer? _controlsTimer;

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
    _showControlsTemporarily();
    _lockLandscape();
  }

  void _showControlsTemporarily() {
    _controlsTimer?.cancel();
    if (mounted) setState(() => _showControls = true);
    _controlsTimer = Timer(const Duration(seconds: 1), () {
      if (!mounted) return;
      setState(() => _showControls = false);
    });
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
    _controlsTimer?.cancel();
    _unlockOrientation();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fsSlides = widget.slides;
    final fsDeck = fsSlides.isEmpty
        ? null
        : fsSlides[_index.clamp(0, fsSlides.length - 1)];
    final fsPdfKnown = fsDeck != null &&
        _slideIsPdfAsset(fsDeck) &&
        (_fullscreenPdfTotal != null && _fullscreenPdfTotal! > 0);
    final fsNum = fsPdfKnown ? (_fullscreenPdfPage ?? 1) : (_index + 1);
    final fsDenom =
        fsPdfKnown ? _fullscreenPdfTotal! : fsSlides.length.clamp(1, 1 << 30);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _controller,
            scrollDirection: Axis.horizontal,
            physics: const _SnappyPageScrollPhysics().applyTo(
              ClampingScrollPhysics(),
            ),
            itemCount: widget.slides.length,
            onPageChanged: (v) {
              setState(() {
                _index = v;
                _fullscreenPdfPage = null;
                _fullscreenPdfTotal = null;
              });
              _showControlsTemporarily();
            },
            itemBuilder: (context, i) {
              final slide = widget.slides[i];
              final isPdf = _slideIsPdfAsset(slide);
              final isPpt = _slideIsPptAsset(slide);
              final cover = _slideHasCoverImage(slide);

              late final Widget body;
              if (cover) {
                body = _SlideImage(
                  imageUrl: slide.imageUrl,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                  placeholderHeight: MediaQuery.sizeOf(context).shortestSide,
                );
              } else if (isPdf) {
                body = Padding(
                  padding: const EdgeInsets.all(12),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: _InlinePdfPreview(
                      key: ValueKey(slide.assetFileUrl),
                      url: slide.assetFileUrl!,
                      slideIndex: i,
                      isActiveDeckSlide: i == _index,
                      onPaginationFromPdf: (slideIndex, page, totalPages) {
                        if (!mounted ||
                            slideIndex != _index ||
                            totalPages <= 0) {
                          return;
                        }
                        setState(() {
                          _fullscreenPdfPage = page.clamp(1, totalPages);
                          _fullscreenPdfTotal = totalPages;
                        });
                        _showControlsTemporarily();
                      },
                    ),
                  ),
                );
              } else if (isPpt) {
                body = Center(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: Colors.white.withValues(alpha: 0.2),
                    ),
                    onPressed: () async {
                      final resolved = MediaUrlResolver.resolveFetchUrl(
                        slide.assetFileUrl!,
                        apiBaseUrl: getApiBaseUrl(),
                      );
                      final uri = Uri.tryParse(resolved);
                      if (uri == null) return;
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    },
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('PPT ni ochish'),
                  ),
                );
              } else {
                body = Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          slide.title,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        if (slide.body.trim().isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Text(
                            slide.body,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyLarge
                                ?.copyWith(color: Colors.white70),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }

              return Container(
                color: Colors.black,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    const ColoredBox(color: Color(0xFF1E6BB8)),
                    Positioned.fill(child: body),
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
            bottom: 8,
            left: 0,
            right: 0,
            child: IgnorePointer(
              ignoring: !_showControls,
              child: AnimatedOpacity(
                opacity: _showControls ? 1 : 0,
                duration: const Duration(milliseconds: 220),
                child: SafeArea(
                  top: false,
                  minimum: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      const SizedBox(width: 10),
                      IconButton(
                        iconSize: 20,
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.black.withValues(alpha: 0.35),
                          foregroundColor: Colors.white,
                          minimumSize: const Size(36, 36),
                          padding: EdgeInsets.zero,
                        ),
                        onPressed: _index > 0
                            ? () {
                                _showControlsTemporarily();
                                _controller.previousPage(
                                  duration: const Duration(milliseconds: 140),
                                  curve: Curves.easeOut,
                                );
                              }
                            : null,
                        icon: const Icon(Icons.chevron_left),
                      ),
                      Expanded(
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.4),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              '$fsNum / $fsDenom',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        iconSize: 20,
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.black.withValues(alpha: 0.35),
                          foregroundColor: Colors.white,
                          minimumSize: const Size(36, 36),
                          padding: EdgeInsets.zero,
                        ),
                        onPressed: _index < fsSlides.length - 1
                            ? () {
                                _showControlsTemporarily();
                                _controller.nextPage(
                                  duration: const Duration(milliseconds: 140),
                                  curve: Curves.easeOut,
                                );
                              }
                            : null,
                        icon: const Icon(Icons.chevron_right),
                      ),
                      const SizedBox(width: 10),
                    ],
                  ),
                ),
              ),
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
  const _InlinePdfPreview({
    super.key,
    required this.url,
    this.slideIndex = 0,
    this.isActiveDeckSlide = true,
    this.onControllerReady,
    this.onControllerDisposed,
    this.onPaginationFromPdf,
  });

  final String url;
  final int slideIndex;
  final bool isActiveDeckSlide;
  final void Function(int slideIndex, PdfViewerController controller)?
      onControllerReady;
  final void Function(PdfViewerController controller)? onControllerDisposed;
  final void Function(int slideIndex, int page, int totalPages)?
      onPaginationFromPdf;

  @override
  State<_InlinePdfPreview> createState() => _InlinePdfPreviewState();
}

class _InlinePdfPreviewState extends State<_InlinePdfPreview> {
  late final Future<Uint8List> _bytesFuture;
  late final PdfViewerController _pdfViewerController = PdfViewerController();

  @override
  void initState() {
    super.initState();
    _bytesFuture = _loadBytes(widget.url);
    if (widget.isActiveDeckSlide) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        widget.onControllerReady?.call(widget.slideIndex, _pdfViewerController);
      });
    }
  }

  @override
  void didUpdateWidget(covariant _InlinePdfPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.isActiveDeckSlide && widget.isActiveDeckSlide) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        widget.onControllerReady?.call(widget.slideIndex, _pdfViewerController);
        _syncPaginationFromController();
      });
    }
    if (oldWidget.isActiveDeckSlide && !widget.isActiveDeckSlide) {
      widget.onControllerDisposed?.call(_pdfViewerController);
    }
  }

  void _syncPaginationFromController() {
    if (!widget.isActiveDeckSlide || !mounted) return;
    final total = _pdfViewerController.pageCount;
    if (total <= 0) return;
    final pn = _pdfViewerController.pageNumber;
    final cur = pn <= 0 ? 1 : pn.clamp(1, total);
    widget.onPaginationFromPdf?.call(widget.slideIndex, cur, total);
  }

  @override
  void dispose() {
    widget.onControllerDisposed?.call(_pdfViewerController);
    _pdfViewerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List>(
      future: _bytesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.white),
          );
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return _error(
            snapshot.error is Exception
                ? (snapshot.error as Exception).toString().replaceFirst(
                    'Exception: ',
                    '',
                  )
                : "PDF ni ochib bo'lmadi",
          );
        }
        return SfPdfViewer.memory(
          snapshot.data!,
          controller: _pdfViewerController,
          canShowScrollHead: false,
          canShowScrollStatus: false,
          pageLayoutMode: PdfPageLayoutMode.single,
          scrollDirection: PdfScrollDirection.horizontal,
          enableDoubleTapZooming: true,
          onDocumentLoaded: (details) {
            if (!widget.isActiveDeckSlide) return;
            final total = details.document.pages.count;
            if (total <= 0) return;
            final pn = _pdfViewerController.pageNumber;
            final cur = pn <= 0 ? 1 : pn.clamp(1, total);
            widget.onPaginationFromPdf?.call(widget.slideIndex, cur, total);
          },
          onPageChanged: (details) {
            if (!widget.isActiveDeckSlide) return;
            final total = _pdfViewerController.pageCount;
            if (total <= 0) return;
            widget.onPaginationFromPdf?.call(
              widget.slideIndex,
              details.newPageNumber.clamp(1, total),
              total,
            );
          },
        );
      },
    );
  }

  Future<Uint8List> _loadBytes(String raw) {
    return LessonSlidesBytesCache.loadBytes(
      raw,
      apiBaseUrl: getApiBaseUrl(),
      fetcher: LessonSlidesBytesCache.fetchPdfBytes,
    );
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

class _SlideImage extends StatefulWidget {
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
  State<_SlideImage> createState() => _SlideImageState();
}

class _SlideImageState extends State<_SlideImage> {
  late Future<Uint8List?> _bytesFuture;

  @override
  void initState() {
    super.initState();
    _bytesFuture = _loadImageBytes();
  }

  @override
  void didUpdateWidget(covariant _SlideImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      setState(() => _bytesFuture = _loadImageBytes());
    }
  }

  Future<Uint8List?> _loadImageBytes() async {
    final raw = widget.imageUrl.trim();
    if (raw.isEmpty) return null;
    try {
      return await LessonSlidesBytesCache.loadBytes(
        raw,
        apiBaseUrl: getApiBaseUrl(),
        fetcher: LessonSlidesBytesCache.fetchHttpBytes,
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: _bytesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return _placeholder(showSpinner: true);
        }
        final bytes = snapshot.data;
        if (bytes == null || bytes.isEmpty) {
          return _placeholder();
        }
        return Image.memory(
          bytes,
          fit: widget.fit,
          width: widget.width,
          height: widget.height,
          errorBuilder: (_, _, _) => _placeholder(),
        );
      },
    );
  }

  Widget _placeholder({bool showSpinner = false}) {
    final bg = ColoredBox(
      color: Colors.white.withValues(alpha: 0.16),
      child: Center(
        child: showSpinner
            ? const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              )
            : const Text(
                'Rasmni yuklab bo\'lmadi',
                style: TextStyle(color: Colors.white),
              ),
      ),
    );
    if (widget.height != null && widget.height!.isFinite) {
      return SizedBox(
        width: widget.width ?? double.infinity,
        height: widget.height,
        child: bg,
      );
    }
    return SizedBox.expand(child: bg);
  }
}
