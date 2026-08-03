import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

import '../core/config/api_config.dart';
import '../core/services/media_url_resolver.dart';
import '../core/services/video_lesson_position_store.dart';
import '../core/services/video_playback_prefs.dart';
  
// ─────────────────────────────────────────────
//  DEBUG LOGGING
// ─────────────────────────────────────────────

class _VideoLog {
  static void init({
    String? videoId,
    required String sourceType,
    String? url,
  }) {
    debugPrint('[VIDEO] init ${{'videoId': videoId, 'sourceType': sourceType, 'url': url}}');
  }

  static void mounted({String? videoId}) {
    debugPrint('[VIDEO] PLAYER MOUNTED ${{'videoId': videoId}}');
  }

  static void unmounted({String? videoId}) {
    debugPrint('[VIDEO] PLAYER UNMOUNTED ${{'videoId': videoId}}');
  }

  static void loadStart({String? videoId, String? url}) {
    debugPrint('[VIDEO] load start ${{'videoId': videoId, 'url': url}}');
  }

  static void playPressed({required int currentTime}) {
    debugPrint('[VIDEO] play pressed ${{'currentTime': currentTime}}');
  }

  static void actualPlaying({required int currentTime}) {
    debugPrint('[VIDEO] actual playing ${{'currentTime': currentTime}}');
  }

  static void loadingTimeout() {
    debugPrint('[VIDEO] loading timeout');
  }

  static void playStall({required int currentTime}) {
    debugPrint(
      '[VIDEO] play requested but time is not moving ${{'currentTime': currentTime}}',
    );
  }

  static void ready({required int duration}) {
    debugPrint('[VIDEO] ready ${{'duration': duration}}');
  }

  static void play({required int currentTime}) {
    debugPrint('[VIDEO] play ${{'currentTime': currentTime}}');
  }

  static void pause({required int currentTime}) {
    debugPrint('[VIDEO] pause ${{'currentTime': currentTime}}');
  }

  static void bufferingStart({required int currentTime}) {
    debugPrint('[VIDEO] buffering start ${{'currentTime': currentTime}}');
  }

  static void bufferingEnd({required int currentTime}) {
    debugPrint('[VIDEO] buffering end ${{'currentTime': currentTime}}');
  }

  static void progress({required int currentTime, required int duration}) {
    debugPrint('[VIDEO] progress ${{'currentTime': currentTime, 'duration': duration}}');
  }

  static void seekStart({required int from, required int to}) {
    debugPrint('[VIDEO] seek start ${{'from': from, 'to': to}}');
  }

  static void seekComplete({required int currentTime}) {
    debugPrint('[VIDEO] seek complete ${{'currentTime': currentTime}}');
  }

  static void fullscreenEnterStart({required int currentTime, bool? wasPlaying}) {
    debugPrint(
      '[VIDEO] fullscreen enter start ${{'currentTime': currentTime, 'wasPlaying': wasPlaying}}',
    );
  }

  static void fullscreenEnterDone({required int currentTime}) {
    debugPrint('[VIDEO] fullscreen enter done ${{'currentTime': currentTime}}');
  }

  static void fullscreenExitStart({required int currentTime}) {
    debugPrint('[VIDEO] fullscreen exit start ${{'currentTime': currentTime}}');
  }

  static void fullscreenExitDone({required int currentTime}) {
    debugPrint('[VIDEO] fullscreen exit done ${{'currentTime': currentTime}}');
  }

  static void orientationChanged({
    required String orientation,
    required int currentTime,
  }) {
    debugPrint(
      '[VIDEO] orientation changed ${{'orientation': orientation, 'currentTime': currentTime}}',
    );
  }

  static void error(Object error) {
    debugPrint('[VIDEO] error $error');
  }

  static void possibleFreeze({
    required int lastTime,
    required int currentTime,
    required bool isPlaying,
  }) {
    debugPrint(
      '[VIDEO] possible freeze detected ${{'lastTime': lastTime, 'currentTime': currentTime, 'isPlaying': isPlaying}}',
    );
  }

  static void remountWarning(String reason) {
    debugPrint('[VIDEO] player surface remount avoided: $reason');
  }
}

/// Admin analytics: 95%+ yoki oxirgi soniyalar = yakunlangan.
bool _isVideoCompleted(int watchedSec, int durationSec) {
  if (durationSec <= 0) return false;
  if (durationSec <= 15) return watchedSec >= durationSec - 1;
  final nearEnd = watchedSec >= durationSec - 5;
  final pctOk = watchedSec >= (durationSec * 0.95).floor();
  return nearEnd || pctOk;
}

// ─────────────────────────────────────────────
//  PUBLIC WIDGET
// ─────────────────────────────────────────────

class VideoPlayerBox extends StatefulWidget {
  const VideoPlayerBox({
    super.key,
    required this.url,
    required this.height,
    this.initialWatchedSec = 0,
    this.onWatchProgress,
    this.onImmersiveModeChanged,
    /// `userId|lessonId` — ekran qulflanganda pozitsiyani telefonda saqlash.
    this.positionStorageKey,
    /// Katalogdan (masalan `duration_uz`); player metadata kelguncha 00:00 o‘rniga.
    this.catalogDurationLabel,
  });

  final String url;
  final double height;
  final int initialWatchedSec;
  final String? positionStorageKey;
  /// [playbackDeltaSec] — shu xabarda qo‘shilgan ko‘rish soniyasi (kunlik reyting uchun).
  final void Function(int watchedSec, bool completed, int playbackDeltaSec)?
      onWatchProgress;
  /// To‘liq ekran (WebView qayta yaratilmasin — dars sahifasi layoutini o‘zgartiradi).
  final ValueChanged<bool>? onImmersiveModeChanged;
  final String? catalogDurationLabel;

  @override
  State<VideoPlayerBox> createState() => VideoPlayerBoxState();
}

class VideoPlayerBoxState extends State<VideoPlayerBox>
    with WidgetsBindingObserver, AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  static const _fullscreenDebounce = Duration(milliseconds: 500);

  VideoPlayerController? _controller;
  YoutubePlayerController? _ytController;
  String? _youtubeId;

  double _speed = 1.0;
  double _volume = 1.0;
  int _lastReportedSec = 0;
  bool _firstProgressReported = false;
  bool _completedReported = false;
  int? _pendingInitialSeekSec;
  int _lastKnownPositionSec = 0;
  final ValueNotifier<bool> _immersiveNotifier = ValueNotifier(false);
  bool get _immersiveFullscreen => _immersiveNotifier.value;
  bool _userSeeking = false;
  bool _nativeInitFailed = false;
  bool _retryViaBackendProxy = false;
  bool _wasPlayingBeforePause = false;
  bool _wasBuffering = false;
  bool _fullscreenLocked = false;
  DateTime? _lastFullscreenTapAt;
  int? _resumePositionAfterFullscreen;
  bool _resumePlayAfterFullscreen = false;
  final GlobalKey _youtubeViewKey = GlobalKey(debugLabel: 'lesson-youtube-view');
  bool _showFreezeRecovery = false;
  int _healthLastPosSec = 0;
  int _healthStallTicks = 0;
  Timer? _progressFlushTimer;
  Timer? _healthCheckTimer;
  Timer? _uiProgressTimer;
  int _lastUiProgressSec = -1;
  void Function(int watchedSec, bool completed, int playbackDeltaSec)?
      _cachedWatchProgress;
  bool _disposing = false;
  bool _initialResumeDone = false;

  bool _playerReady = false;

  /// Tashqaridan (masalan, orqaga tugmasi) immersive rejimdan chiqish.
  Future<void> exitImmersive() => _closeImmersiveFullscreen();

  /// Server/local progress yuklanganda yoki ilova qayta ochilganda pozitsiyani tiklash.
  Future<void> restorePlaybackPosition([int? sec]) async {
    final target = sec ?? _lastKnownPositionSec;
    if (target <= 0) return;
    final current = _actualPlayerPositionSec();
    if (current != null && (current - target).abs() <= 3) {
      _commitPlaybackPosition(target);
      return;
    }
    _pendingInitialSeekSec = target;
    await _applyResumePosition(target);
    await Future<void>.delayed(const Duration(milliseconds: 350));
    if (!mounted) return;
    final now = _actualPlayerPositionSec();
    if (now == null || (now - target).abs() > 3) {
      await _applyResumePosition(target);
    }
    // Only commit once the seek actually landed. _commitPlaybackPosition()
    // clears _pendingInitialSeekSec and sets _initialResumeDone, which is
    // precisely what disables the retry-on-progress-tick path — calling it
    // unconditionally here meant that for YouTube (whose duration is still 0
    // this early, so the seek provably cannot have landed yet) the resume was
    // marked "done" before it ever happened, and the lesson restarted at 0.
    final landed = _actualPlayerPositionSec();
    if (landed != null && (landed - target).abs() <= 3) {
      _commitPlaybackPosition(target);
      return;
    }
    // Not landed yet: keep the pending target so _handleVideoProgress /
    // _handleYoutubeProgress can finish the seek once the player reports a
    // real duration, and remember the position so it still gets persisted.
    _pendingInitialSeekSec = target;
    if (target > _lastKnownPositionSec) _lastKnownPositionSec = target;
  }

  void _commitPlaybackPosition(int sec) {
    if (sec <= 0) return;
    _lastKnownPositionSec = sec;
    _pendingInitialSeekSec = null;
    _initialResumeDone = true;
    _persistLocalPosition();
  }
  bool _isInitialLoading = true;
  bool _isBufferingUi = false;
  bool _loadTimedOut = false;
  bool _pendingPlay = false;
  Timer? _loadTimeoutTimer;
  Timer? _playRecoveryTimer;
  int _playRecoveryAttempts = 0;
  DateTime? _playerReadyAt;

  static const _youtubeLoadTimeout = Duration(seconds: 45);
  static const _nativeLoadTimeout = Duration(seconds: 20);

  bool get _isYoutube => _youtubeId != null && _ytController != null;
  String get _playUrl => MediaUrlResolver.resolveVideoPlayUrl(
        widget.url,
        apiBaseUrl: getApiBaseUrl(),
        useBackendProxy: _retryViaBackendProxy,
      );
  bool get _isPlayingNow {
    final c = _controller;
    if (c != null && c.value.isInitialized) return c.value.isPlaying;
    final yc = _ytController;
    if (yc != null) return yc.value.playerState == PlayerState.playing;
    return false;
  }

  @override
  void initState() {
    super.initState();
    _cachedWatchProgress = widget.onWatchProgress;
    WidgetsBinding.instance.addObserver(this);
    final bootSec = widget.initialWatchedSec;
    if (bootSec > 0) {
      _lastKnownPositionSec = bootSec;
      _lastReportedSec = bootSec;
    }
    _pendingInitialSeekSec = bootSec > 0 ? bootSec : null;
    unawaited(_loadStoredResumePosition());
    if (widget.url.trim().isEmpty) {
      _nativeInitFailed = true;
      _isInitialLoading = false;
      _loadTimeoutTimer?.cancel();
      if (mounted) setState(() {});
      return;
    }
    _youtubeId = _extractYouTubeId(widget.url);
    _VideoLog.init(
      videoId: _youtubeId,
      sourceType: _youtubeId != null ? 'youtube' : 'native',
      url: widget.url,
    );
    _VideoLog.mounted(videoId: _youtubeId ?? widget.url);
    _VideoLog.loadStart(videoId: _youtubeId, url: widget.url);
    _startLoadTimeout();
    if (_youtubeId != null) {
      _createYoutubeController();
      if (mounted) setState(() {});
      unawaited(_loadPlaybackPrefs());
    } else {
      unawaited(_bootstrapNativePlayer());
    }
    _progressFlushTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => _emitProgressFromCurrent(force: false),
    );
    _healthCheckTimer = Timer.periodic(
      const Duration(seconds: 4),
      (_) => _runPlaybackHealthCheck(),
    );
    _uiProgressTimer = Timer.periodic(
      const Duration(milliseconds: 250),
      (_) {
        if (!mounted) return;
        final sec = _currentPositionSec();
        if (sec != _lastUiProgressSec) {
          _lastUiProgressSec = sec;
          setState(() {});
        }
      },
    );
  }

  void _createYoutubeController() {
    final id = _youtubeId;
    if (id == null) return;
    _ytController?.removeListener(_handleYoutubeProgress);
    _ytController?.dispose();
    _ytController = YoutubePlayerController(
      initialVideoId: id,
      flags: const YoutubePlayerFlags(
        autoPlay: false,
        mute: false,
        forceHD: false,
        enableCaption: false,
        hideControls: true,
        controlsVisibleAtStart: false,
        hideThumbnail: true,
        disableDragSeek: false,
        useHybridComposition: true,
      ),
    )..addListener(_handleYoutubeProgress);
  }

  Future<void> _loadPlaybackPrefs() async {
    final loaded = await VideoPlaybackPrefs.loadSpeed();
    if (!mounted) return;
    _speed = loaded;
    _applyYoutubeSettingsWhenReady();
    if (mounted) setState(() {});
  }

  Future<void> _bootstrapNativePlayer() async {
    _speed = await VideoPlaybackPrefs.loadSpeed();
    if (!mounted) return;

    _controller = VideoPlayerController.networkUrl(
      Uri.parse(_playUrl),
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    )..addListener(_handleVideoProgress);

    try {
      await _controller!.initialize();
      await _controller!.setVolume(_volume);
      await _controller!.setPlaybackSpeed(_speed);
      final dur = _controller!.value.duration.inSeconds;
      _markPlayerReady(durationSec: dur);

      int seekSec = _pendingInitialSeekSec ?? 0;
      if (seekSec <= 0) {
        final key = widget.positionStorageKey?.trim() ?? '';
        if (key.isNotEmpty) {
          seekSec = await VideoLessonPositionStore.load(key);
        }
      }
      if (seekSec <= 0 && widget.initialWatchedSec > 0) {
        seekSec = widget.initialWatchedSec;
      }
      if (seekSec > 0 && dur > 0 && seekSec < dur - 3) {
        await _applyResumePosition(seekSec);
      }
      _pendingInitialSeekSec = null;
      _nativeInitFailed = false;
    } catch (e) {

      _nativeInitFailed = true;
      _isInitialLoading = false;
      _VideoLog.error(e);
    }
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(covariant VideoPlayerBox oldWidget) {
    super.didUpdateWidget(oldWidget);
    _cachedWatchProgress = widget.onWatchProgress;
    if (oldWidget.url != widget.url) {
      _disposeControllers();
      _pendingInitialSeekSec =
          widget.initialWatchedSec > 0 ? widget.initialWatchedSec : null;
      _lastReportedSec = 0;
      _firstProgressReported = false;
      _lastKnownPositionSec = 0;
      _initialResumeDone = false;
      _completedReported = false;
      _nativeInitFailed = false;
      _retryViaBackendProxy = false;
      _playerReady = false;
      _isInitialLoading = true;
      _isBufferingUi = false;
      _loadTimedOut = false;
      _pendingPlay = false;
      _playRecoveryAttempts = 0;
      _youtubeId = _extractYouTubeId(widget.url);
      _startLoadTimeout();
      if (_youtubeId != null) {
        _createYoutubeController();
        if (mounted) setState(() {});
        unawaited(_loadPlaybackPrefs());
      } else {
        unawaited(_bootstrapNativePlayer());
      }
      return;
    }
    final newSec = widget.initialWatchedSec;
    if (!_initialResumeDone &&
        newSec > _lastKnownPositionSec + 5 &&
        _currentPositionSec() < newSec - 5) {
      unawaited(restorePlaybackPosition(newSec));
    }
  }

  void _disposeControllers() {
    _controller?.removeListener(_handleVideoProgress);
    _ytController?.removeListener(_handleYoutubeProgress);
    _controller?.dispose();
    _ytController?.dispose();
    _controller = null;
    _ytController = null;
  }

  bool get _youtubeReady =>
      _ytController != null && _ytController!.value.isReady;

  void _runYoutubeWhenReady(void Function(YoutubePlayerController c) fn) {
    final yc = _ytController;
    if (yc == null || !yc.value.isReady) return;
    try {
      fn(yc);
    } catch (e) {
      _VideoLog.error(e);
    }
  }

  void _applyYoutubeSettingsWhenReady() {
    _runYoutubeWhenReady((c) {
      c.unMute();
      c.setVolume(100);
      c.setPlaybackRate(_speed);
    });
  }

  @override
  void didChangeMetrics() {
    if (!mounted) return;
    _snapshotPlayback();
    final resume = _resumePositionAfterFullscreen;
    if (resume != null) {
      final play = _resumePlayAfterFullscreen;
      _resumePositionAfterFullscreen = null;
      _resumePlayAfterFullscreen = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        unawaited(_restorePositionAfterFullscreen(resume, play: play));
      });
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _immersiveFullscreen) return;
      if (_isYoutube) return;
      unawaited(_syncPlaybackAfterLayout(reason: 'metrics'));
    });
  }

  Future<void> _restorePositionAfterFullscreen(int sec, {bool play = false}) async {
    if (sec > 0) {
      _lastKnownPositionSec = sec;
      if (sec > _lastReportedSec) _lastReportedSec = sec;
    }
    await _applyResumePosition(sec);
    if (!mounted) return;
    if (_isYoutube) {
      _runYoutubeWhenReady((c) {
        final dur = c.metadata.duration.inSeconds;
        if (dur > 0) {
          final safe = sec.clamp(0, dur - 1);
          if ((c.value.position.inSeconds - safe).abs() > 2) {
            c.seekTo(Duration(seconds: safe), allowSeekAhead: true);
          }
        }
        if (play) c.play();
      });
    } else if (play) {
      await _startPlayback();
    }
  }

  Future<void> _loadStoredResumePosition() async {
    final key = widget.positionStorageKey?.trim() ?? '';
    if (key.isEmpty) return;
    final stored = await VideoLessonPositionStore.load(key);
    if (!mounted || stored <= 0) return;
    final best = stored > widget.initialWatchedSec ? stored : widget.initialWatchedSec;
    if (best <= 0) return;
    final actual = _actualPlayerPositionSec();
    if (actual != null && actual >= best - 3) {
      _commitPlaybackPosition(best);
      return;
    }
    await restorePlaybackPosition(best);
  }

  void _persistLocalPosition() {
    final key = widget.positionStorageKey?.trim() ?? '';
    if (key.isEmpty) return;
    final current = _currentPositionSec();
    final sec = current > 0 ? current : _lastKnownPositionSec;
    if (sec <= 0) return;
    unawaited(VideoLessonPositionStore.save(key, sec));
  }


  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _snapshotPlayback();
      _persistLocalPosition();
      _emitProgressFromCurrent(force: true);
    } else if (state == AppLifecycleState.resumed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        unawaited(_restoreAfterAppResume());
      });
    }
  }

  Future<void> _restoreAfterAppResume() async {
    final key = widget.positionStorageKey?.trim() ?? '';
    var saved = _lastKnownPositionSec;
    if (key.isNotEmpty) {
      final stored = await VideoLessonPositionStore.load(key);
      if (stored > saved) saved = stored;
    }
    if (saved <= 0) return;
    final current = _currentPositionSec();
    if ((current - saved).abs() <= 5) {
      _commitPlaybackPosition(saved);
      return;
    }
    await restorePlaybackPosition(saved);
  }

  int _currentPositionSec() {
    final c = _controller;
    if (c != null && c.value.isInitialized) {
      return c.value.position.inSeconds;
    }
    final yc = _ytController;
    if (yc != null) return yc.value.position.inSeconds;
    return _lastKnownPositionSec;
  }

  /// Position actually reported by a ready player, or null when none is ready.
  ///
  /// Unlike [_currentPositionSec] this never falls back to
  /// [_lastKnownPositionSec]. That fallback is right for *saving* progress but
  /// catastrophic in the "are we already at the target?" guards that skip the
  /// resume seek: during initState `_lastKnownPositionSec` has already been
  /// seeded with the position we want to resume to, so those guards compared
  /// the target against itself, concluded playback was already there, marked
  /// the resume done and never seeked — leaving the lesson playing from 0.
  int? _actualPlayerPositionSec() {
    final c = _controller;
    if (c != null && c.value.isInitialized) return c.value.position.inSeconds;
    final yc = _ytController;
    if (yc != null && yc.value.isReady) return yc.value.position.inSeconds;
    return null;
  }

  void _snapshotPlayback() {
    _commitPlaybackPosition(_currentPositionSec());
  }

  Future<void> _applyResumePosition(int sec) async {
    if (sec <= 0) return;
    final c = _controller;
    if (c != null) {
      if (!c.value.isInitialized) {
        // Native controller exists but hasn't finished loading yet (network
        // video init is slower than the caller's timing assumptions) — queue
        // it so `_handleVideoProgress` retries once the controller is ready,
        // instead of silently dropping the seek like before.
        _pendingInitialSeekSec = sec;
        return;
      }
      final maxSeek = (c.value.duration.inSeconds - 1).clamp(0, 1 << 30);
      final safe = sec.clamp(0, maxSeek).toInt();
      if (safe <= 0) return;
      final current = c.value.position.inSeconds;
      if ((current - safe).abs() <= 2) return;
      _VideoLog.seekStart(from: current, to: safe);
      await c.seekTo(Duration(seconds: safe));
      _VideoLog.seekComplete(currentTime: safe);
      if (safe > _lastReportedSec) _lastReportedSec = safe;
      return;
    }
    final yc = _ytController;
    if (yc != null) {
      final dur = yc.metadata.duration.inSeconds;
      if (dur <= 0) {
        _pendingInitialSeekSec = sec;
        return;
      }
      final safe = sec.clamp(0, dur - 1).toInt();
      if (safe <= 0) return;
      final current = yc.value.position.inSeconds;
      if ((current - safe).abs() <= 2) return;
      _VideoLog.seekStart(from: current, to: safe);
      yc.seekTo(Duration(seconds: safe), allowSeekAhead: true);
      _VideoLog.seekComplete(currentTime: safe);
      if (safe > _lastReportedSec) _lastReportedSec = safe;
    }
  }

  void _startLoadTimeout() {
    _loadTimeoutTimer?.cancel();
    final timeout =
        _youtubeId != null ? _youtubeLoadTimeout : _nativeLoadTimeout;
    _loadTimeoutTimer = Timer(timeout, () {
      if (!mounted || _playerReady) return;
      final yc = _ytController;
      if (_youtubeId != null && (yc?.value.isReady ?? false)) {
        final dur = yc!.metadata.duration.inSeconds;
        _markPlayerReady(durationSec: dur > 0 ? dur : 1);
        return;
      }
      _VideoLog.loadingTimeout();
      setState(() {
        _loadTimedOut = true;
        _isInitialLoading = false;
      });
    });
  }

  void _onYoutubeIframeReady() {
    _loadTimeoutTimer?.cancel();
    if (_playerReady) return;
    final yc = _ytController;
    if (yc == null || !yc.value.isReady) return;
    final dur = yc.metadata.duration.inSeconds;
    _markPlayerReady(durationSec: dur > 0 ? dur : 1);
    _applyYoutubeSettingsWhenReady();
    final seekSec = _pendingInitialSeekSec;
    if (seekSec != null && seekSec > 0) {
      unawaited(restorePlaybackPosition(seekSec));
    }
  }

  Future<void> _retryYoutubeLoad() async {
    setState(() {
      _loadTimedOut = false;
      _isInitialLoading = true;
      _playerReady = false;
      _playerReadyAt = null;
      _showFreezeRecovery = false;
    });
    _disposeControllers();
    _youtubeId = _extractYouTubeId(widget.url);
    _pendingInitialSeekSec = _lastKnownPositionSec > 0
        ? _lastKnownPositionSec
        : widget.initialWatchedSec;
    _createYoutubeController();
    _startLoadTimeout();
    if (mounted) setState(() {});
    await _loadPlaybackPrefs();
  }

  void _markPlayerReady({required int durationSec}) {
    if (_playerReady) return;
    _playerReady = true;
    _playerReadyAt = DateTime.now();
    _isInitialLoading = false;
    _loadTimedOut = false;
    _showFreezeRecovery = false;
    _healthStallTicks = 0;
    _loadTimeoutTimer?.cancel();
    _VideoLog.ready(duration: durationSec);
    if (_pendingPlay) {
      _pendingPlay = false;
      unawaited(_startPlayback());
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _disposing = true;
    _snapshotPlayback();
    _persistLocalPosition();
    final watchedSec = _lastKnownPositionSec;
    final cb = _cachedWatchProgress;
    if (cb != null && watchedSec > 0) {
      final completed = _isVideoCompleted(watchedSec, _durationSec());
      cb(watchedSec, completed, 1);
    }
    _cachedWatchProgress = null;
    _VideoLog.unmounted(videoId: _youtubeId ?? widget.url);
    WidgetsBinding.instance.removeObserver(this);
    _progressFlushTimer?.cancel();
    _healthCheckTimer?.cancel();
    _uiProgressTimer?.cancel();
    _loadTimeoutTimer?.cancel();
    _playRecoveryTimer?.cancel();
    unawaited(_restoreAppSystemUi());
    _immersiveNotifier.dispose();
    _disposeControllers();
    super.dispose();
  }

  Future<void> _enterLandscapeFullscreen() async {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  Future<void> _restoreAppSystemUi() async {
    await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  bool _syncingLayout = false;

  Future<void> _syncPlaybackAfterLayout({required String reason}) async {
    if (_syncingLayout) return;
    _syncingLayout = true;
    try {
      final saved = _lastKnownPositionSec;
      final wasPlaying = _isPlayingNow;
      await _applyResumePosition(saved);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      if (!mounted) return;
      final now = _currentPositionSec();
      if (saved > 3 && now < 2) {
        _VideoLog.remountWarning('$reason position reset to 0 — recovering');
        await _applyResumePosition(saved);
      }
      if (wasPlaying && !_isPlayingNow) {
        final c = _controller;
        if (c != null && c.value.isInitialized) {
          unawaited(c.play());
          _VideoLog.play(currentTime: _currentPositionSec());
        }
        final yc = _ytController;
        if (yc != null && !yc.value.isPlaying) {
          yc.play();
          _VideoLog.play(currentTime: _currentPositionSec());
        }
      }
    } finally {
      _syncingLayout = false;
    }
  }

  void _runPlaybackHealthCheck() {
    if (!mounted || _userSeeking || _immersiveFullscreen) return;
    if (_isBufferingUi || !_playerReady) return;
    final readyAt = _playerReadyAt;
    if (readyAt != null &&
        DateTime.now().difference(readyAt) < const Duration(seconds: 25)) {
      return;
    }
    final playing = _isPlayingNow;
    final pos = _currentPositionSec();
    if (!playing) {
      _healthStallTicks = 0;
      _healthLastPosSec = pos;
      return;
    }
    if (pos > _healthLastPosSec + 1) {
      _healthStallTicks = 0;
      _healthLastPosSec = pos;
      if (_showFreezeRecovery && mounted) {
        setState(() => _showFreezeRecovery = false);
      }
      return;
    }
    if (pos <= _healthLastPosSec) {
      _healthStallTicks++;
    } else {
      _healthStallTicks = 0;
      _healthLastPosSec = pos;
    }
    if (_healthStallTicks >= 5) {
      _VideoLog.possibleFreeze(
        lastTime: _healthLastPosSec,
        currentTime: pos,
        isPlaying: playing,
      );
      if (mounted && !_showFreezeRecovery) {
        setState(() => _showFreezeRecovery = true);
      }
    }
  }

  Future<void> _softRecoverPlayback() async {
    final saved = _lastKnownPositionSec;
    _VideoLog.remountWarning('soft recovery at $saved');
    _showFreezeRecovery = false;
    _healthStallTicks = 0;
    final c = _controller;
    if (c != null && c.value.isInitialized) {
      await c.seekTo(Duration(seconds: saved));
      if (_isPlayingNow) await c.play();
    } else {
      final yc = _ytController;
      if (yc != null && yc.value.isReady) {
        yc.seekTo(Duration(seconds: saved), allowSeekAhead: true);
        if (_isPlayingNow) yc.play();
      }
    }
    if (mounted) setState(() => _showFreezeRecovery = false);
    _healthLastPosSec = saved;
  }

  void _emitProgressFromCurrent({required bool force}) {
    if (_disposing || !mounted) return;
    if (_userSeeking && !force) return;
    final watchedSec = _currentPositionSec();
    if (watchedSec > _lastKnownPositionSec) {
      _lastKnownPositionSec = watchedSec;
    }
    final durationSec = _durationSec();
    final completed = _isVideoCompleted(watchedSec, durationSec);
    if (watchedSec <= 0) return;

    // Write the resume position to disk on every tick, independently of the
    // server-reporting gates below. It used to be persisted only after those
    // gates (`shouldReport` / `delta <= 0`), so a paused or already-reported
    // position never reached disk — the exact case of "pause, leave, come
    // back" losing the position and restarting the lesson from 0.
    _persistLocalPosition();

    final delta =
        watchedSec > _lastReportedSec ? watchedSec - _lastReportedSec : 0;
    final firstSave = !_firstProgressReported && watchedSec >= 1;
    final throttledSave =
        !firstSave && delta > 0 && watchedSec - _lastReportedSec >= 3;
    final shouldReport = force
        ? watchedSec > 0
        : (completed && !_completedReported) || firstSave || throttledSave;
    if (!shouldReport) return;
    if (!force && delta <= 0 && !completed) return;

    if (firstSave) {
      debugPrint('[VIDEO_PROGRESS] first save second=$watchedSec');
    } else if (throttledSave) {
      debugPrint('[VIDEO_PROGRESS] throttled save second=$watchedSec delta=$delta');
    } else if (force) {
      debugPrint('[VIDEO_PROGRESS] forced save second=$watchedSec delta=$delta');
    }

    _firstProgressReported = _firstProgressReported || watchedSec >= 1;
    _lastReportedSec = watchedSec;
    if (completed) _completedReported = true;
    final reportDelta = delta > 0 ? delta : (force || completed ? 1 : 0);
    if (reportDelta <= 0 && !completed) return;
    _persistLocalPosition();
    final cb = _cachedWatchProgress;
    if (cb == null || _disposing) return;
    cb(watchedSec, completed, reportDelta);
  }

  int _durationSec() {
    final c = _controller;
    if (c != null && c.value.isInitialized) {
      return c.value.duration.inSeconds;
    }
    return _ytController?.metadata.duration.inSeconds ?? 0;
  }

  void _handleVideoProgress() {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    if (c.value.hasError) {
      _VideoLog.error(c.value.errorDescription ?? 'native player error');
      if (mounted) {
        setState(() {
          _nativeInitFailed = true;
          _isInitialLoading = false;
        });
      }
      return;
    }
    if (!_playerReady) {
      _markPlayerReady(durationSec: c.value.duration.inSeconds);
    }
    final watchedSec = c.value.position.inSeconds;
    final durationSec = c.value.duration.inSeconds;
    final pendingSeek = _pendingInitialSeekSec;
    if (!_initialResumeDone &&
        pendingSeek != null &&
        durationSec > 0 &&
        (watchedSec - pendingSeek).abs() > 3) {
      // Controller just became initialized (or an earlier seek attempt was
      // dropped because it ran too early) — retry now that we can actually
      // seek. Mirrors the YouTube player's equivalent retry-on-tick logic.
      unawaited(_applyResumePosition(pendingSeek));
    } else if (pendingSeek != null && (watchedSec - pendingSeek).abs() <= 3) {
      _pendingInitialSeekSec = null;
      _initialResumeDone = true;
    }
    if (!_userSeeking && _pendingInitialSeekSec == null) {
      if (watchedSec > 0 || _initialResumeDone) {
        _lastKnownPositionSec = watchedSec;
      }
    }

    if (watchedSec >= 1 && !_firstProgressReported) {
      _emitProgressFromCurrent(force: false);
    }
    final playing = c.value.isPlaying;
    if (_wasPlayingBeforePause && !playing) {
      _VideoLog.pause(currentTime: watchedSec);
      _emitProgressFromCurrent(force: true);
    } else if (!_wasPlayingBeforePause && playing) {
      _VideoLog.actualPlaying(currentTime: watchedSec);
    }
    _wasPlayingBeforePause = playing;
    final buffering = c.value.isBuffering && playing;
    if (buffering && !_wasBuffering) {
      _VideoLog.bufferingStart(currentTime: watchedSec);
    } else if (!buffering && _wasBuffering) {
      _VideoLog.bufferingEnd(currentTime: watchedSec);
    }
    _wasBuffering = c.value.isBuffering;
    if (buffering != _isBufferingUi) {
      _isBufferingUi = buffering;
      if (mounted) setState(() {});
    }
  }

  void _handleYoutubeProgress() {
    final c = _ytController;
    if (c == null) return;
    final v = c.value;
    final watchedSec = v.position.inSeconds;
    if (!_userSeeking && _pendingInitialSeekSec == null) {
      _lastKnownPositionSec = watchedSec;
    }
    if (watchedSec >= 1 && !_firstProgressReported) {
      _emitProgressFromCurrent(force: false);
    }
    final durationSec = c.metadata.duration.inSeconds;
    final playing = v.playerState == PlayerState.playing;
    final buffering = v.playerState == PlayerState.buffering;

    if (_loadTimedOut && (v.isReady || durationSec > 0 || watchedSec > 0)) {
      _loadTimedOut = false;
      if (mounted) setState(() {});
    }

    if (!_playerReady && v.isReady) {
      _markPlayerReady(durationSec: durationSec > 0 ? durationSec : 1);
      _applyYoutubeSettingsWhenReady();
    }

    final seekSec = _pendingInitialSeekSec;
    if (!_initialResumeDone &&
        seekSec != null &&
        durationSec > 0 &&
        watchedSec < seekSec - 3) {
      unawaited(_applyResumePosition(seekSec));
    } else if (seekSec != null && (watchedSec - seekSec).abs() <= 3) {
      _pendingInitialSeekSec = null;
      _initialResumeDone = true;
    }
    final nextBufferingUi = buffering && (playing || _pendingPlay);
    final bufferingUiChanged = nextBufferingUi != _isBufferingUi;
    if (bufferingUiChanged) {
      _isBufferingUi = nextBufferingUi;
      if (buffering) {
        _VideoLog.bufferingStart(currentTime: watchedSec);
      } else {
        _VideoLog.bufferingEnd(currentTime: watchedSec);
      }
    }

    if (_wasPlayingBeforePause && !playing) {
      _VideoLog.pause(currentTime: watchedSec);
      _emitProgressFromCurrent(force: true);
    } else if (!_wasPlayingBeforePause && playing) {
      _VideoLog.actualPlaying(currentTime: watchedSec);
      _isInitialLoading = false;
      _pendingPlay = false;
    }
    _wasPlayingBeforePause = playing;

    if (mounted && bufferingUiChanged) {
      setState(() {});
    }
  }

  Future<void> _startPlayback() async {
    if (_isYoutube) {
      final yc = _ytController;
      if (yc == null) return;
      if (!yc.value.isReady) {
        _pendingPlay = true;
        if (mounted) setState(() {});
        return;
      }
      yc.play();
      _schedulePlayRecovery();
      return;
    }
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    _isBufferingUi = false;
    try {
      await c.play();
      _schedulePlayRecovery();
    } catch (e) {
      _VideoLog.error(e);
    }
    if (mounted) setState(() {});
  }

  void _handlePlayPause() {
    _VideoLog.playPressed(currentTime: _currentPositionSec());
    if (_isYoutube) {
      final yc = _ytController;
      if (yc == null) return;
      if (yc.value.playerState == PlayerState.playing) {
        yc.pause();
        _pendingPlay = false;
        _snapshotPlayback();
        _persistLocalPosition();
        _emitProgressFromCurrent(force: true);
        if (mounted) setState(() {});
        return;
      }
      _isInitialLoading = false;
      _loadTimedOut = false;
      unawaited(_startPlayback());
      return;
    }
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    if (c.value.isPlaying) {
      c.pause();
      _snapshotPlayback();
      _persistLocalPosition();
      _emitProgressFromCurrent(force: true);
      if (mounted) setState(() {});
      return;
    }
    _isInitialLoading = false;
    unawaited(_startPlayback());
  }

  void _schedulePlayRecovery() {
    _playRecoveryTimer?.cancel();
    final startPos = _currentPositionSec();
    _playRecoveryAttempts = 0;
    _playRecoveryTimer = Timer(const Duration(seconds: 2), () async {
      if (!mounted) return;
      final now = _currentPositionSec();
      final playing = _isPlayingNow;
      if (playing && now > startPos) return;
      if (_playRecoveryAttempts >= 1) {
        _VideoLog.playStall(currentTime: now);
        if (mounted) setState(() => _showFreezeRecovery = true);
        return;
      }
      _playRecoveryAttempts++;
      _VideoLog.playStall(currentTime: now);
      await _startPlayback();
    });
  }

  Future<void> _retryNativeLoad() async {
    if (!_retryViaBackendProxy && MediaUrlResolver.isStorageBacked(widget.url)) {
      _retryViaBackendProxy = true;
    }
    final url = _playUrl;
    _disposeControllers();
    _nativeInitFailed = false;
    _loadTimedOut = false;
    _playerReady = false;
    _isInitialLoading = true;
    _pendingPlay = false;
    _startLoadTimeout();
    _pendingInitialSeekSec = _lastKnownPositionSec > 0
        ? _lastKnownPositionSec
        : widget.initialWatchedSec;
    _controller = VideoPlayerController.networkUrl(
      Uri.parse(url),
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    )..addListener(_handleVideoProgress);
    if (mounted) setState(() {});
    try {
      await _controller!.initialize();
      await _controller!.setVolume(_volume);
      await _controller!.setPlaybackSpeed(_speed);
      await _applyResumePosition(_pendingInitialSeekSec ?? 0);
      _pendingInitialSeekSec = null;
    } catch (_) {
      _nativeInitFailed = true;
    }
    if (mounted) setState(() {});
  }

  void _setSpeed(double speed) {
    if (_isYoutube) {
      _runYoutubeWhenReady((c) => c.setPlaybackRate(speed));
    } else {
      unawaited(_controller?.setPlaybackSpeed(speed));
    }
    unawaited(VideoPlaybackPrefs.saveSpeed(speed));
    _speed = speed;
  }

  void _setVolume(double volume) {
    final v = volume.clamp(0.0, 1.0);
    if (_isYoutube) {
      final pct = (v * 100).round();
      _runYoutubeWhenReady((c) {
        c.setVolume(pct);
        if (pct == 0) {
          c.mute();
        } else {
          c.unMute();
        }
      });
    } else {
      unawaited(_controller?.setVolume(v));
    }
    _volume = v;
  }

  bool _canToggleFullscreen() {
    final now = DateTime.now();
    if (_fullscreenLocked) return false;
    if (_lastFullscreenTapAt != null &&
        now.difference(_lastFullscreenTapAt!) < _fullscreenDebounce) {
      return false;
    }
    _lastFullscreenTapAt = now;
    return true;
  }

  // ── fullscreen: bir xil WebView (route yo‘q — pozitsiya va ovoz saqlanadi) ──

  Future<void> _openImmersiveFullscreen() async {
    if (!_canToggleFullscreen() || _immersiveFullscreen) return;

    if (_isYoutube) {
      if (!_youtubeReady) {
        debugPrint('[VIDEO_FULLSCREEN] YouTube not ready');
        return;
      }
    } else {
      final c = _controller;
      if (c == null || !c.value.isInitialized) return;
    }

    _fullscreenLocked = true;
    _snapshotPlayback();
    final positionBefore = _lastKnownPositionSec;
    final wasPlaying = _isPlayingNow;
    debugPrint('[VIDEO_FULLSCREEN] immersive open position=$positionBefore');

    _VideoLog.fullscreenEnterStart(
      currentTime: positionBefore,
      wasPlaying: wasPlaying,
    );

    _resumePositionAfterFullscreen = positionBefore;
    _resumePlayAfterFullscreen = wasPlaying;

    if (!mounted) {
      _fullscreenLocked = false;
      return;
    }
    _immersiveNotifier.value = true;
    widget.onImmersiveModeChanged?.call(true);

    await _enterLandscapeFullscreen();
    await Future<void>.delayed(const Duration(milliseconds: 400));

    if (!mounted) {
      await _restoreAppSystemUi();
      _immersiveNotifier.value = false;
      widget.onImmersiveModeChanged?.call(false);
      _fullscreenLocked = false;
      return;
    }

    await _restorePositionAfterFullscreen(positionBefore, play: wasPlaying);

    _VideoLog.fullscreenEnterDone(currentTime: positionBefore);
    _fullscreenLocked = false;
    debugPrint('[VIDEO_FULLSCREEN] cinema mode position=$positionBefore');
  }

  Future<void> _closeImmersiveFullscreen() async {
    if (!_immersiveFullscreen) return;

    _fullscreenLocked = true;
    _snapshotPlayback();
    _emitProgressFromCurrent(force: true);
    final position = _currentPositionSec();
    debugPrint('[VIDEO_FULLSCREEN] immersive close position=$position');

    _resumePositionAfterFullscreen = position;
    _resumePlayAfterFullscreen = _isPlayingNow;

    if (!mounted) {
      _fullscreenLocked = false;
      return;
    }
    _immersiveNotifier.value = false;
    widget.onImmersiveModeChanged?.call(false);

    await _restoreAppSystemUi();
    await Future<void>.delayed(const Duration(milliseconds: 400));

    if (!mounted) {
      _fullscreenLocked = false;
      return;
    }

    await _restorePositionAfterFullscreen(position, play: _resumePlayAfterFullscreen);

    _fullscreenLocked = false;
    _VideoLog.fullscreenExitDone(currentTime: position);
    debugPrint('[VIDEO_FULLSCREEN] immersive ended');
  }

  Future<void> _openFullscreen() async {
    await _openImmersiveFullscreen();
  }

  void _onUserSeekCommitted(Duration position) {
    final sec = position.inSeconds;
    _commitPlaybackPosition(sec);
    if (sec > _lastReportedSec) {
      _lastReportedSec = sec;
    }
    _emitProgressFromCurrent(force: true);
  }

  Widget _buildShell({required bool immersive}) {
    return RepaintBoundary(
      child: _VideoShell(
        key: const ValueKey<String>('lesson-video-shell'),
        isYoutube: _isYoutube,
        nativeController: _controller,
        ytController: _ytController,
        isFullscreenMode: immersive,
        catalogDurationLabel: widget.catalogDurationLabel,
        speed: _speed,
        volume: _volume,
        onSpeed: _setSpeed,
        onVolume: _setVolume,
        onFullscreen: immersive
            ? () => unawaited(_closeImmersiveFullscreen())
            : () => unawaited(_openFullscreen()),
        onSeekDragStart: () => _userSeeking = true,
        onSeekDragEnd: () {
          _userSeeking = false;
          _snapshotPlayback();
          _emitProgressFromCurrent(force: true);
        },
        onSeekCommitted: _onUserSeekCommitted,
        onTogglePlay: _handlePlayPause,
        showInitialLoading: !_playerReady &&
            (_isYoutube ? !_youtubeReady : _isInitialLoading),
        showBuffering: _isBufferingUi && _isPlayingNow,
        showLoadError:
            (!_isYoutube && (_loadTimedOut || _nativeInitFailed)) ||
            (_isYoutube && _loadTimedOut && !_playerReady),
        onRetryLoad: _isYoutube ? () => unawaited(_retryYoutubeLoad()) : _retryNativeLoad,
      ),
    );
  }

  Widget _freezeRecoveryBanner() {
    if (!_showFreezeRecovery) return const SizedBox.shrink();
    return Positioned(
      left: 12,
      right: 12,
      top: 12,
      child: Material(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Video yuklashda muammo bo‘ldi',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                ),
              ),
              TextButton(
                onPressed: () => unawaited(_softRecoverPlayback()),
                child: const Text('Qayta urinish'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── build ───────────────────────────────────

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return AnimatedBuilder(
      animation: _immersiveNotifier,
      builder: (context, chrome) {
        return PopScope(
          canPop: !_immersiveNotifier.value,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) unawaited(_closeImmersiveFullscreen());
          },
          child: chrome!,
        );
      },
      child: ListenableBuilder(
        listenable: _immersiveNotifier,
        builder: (context, _) {
          final immersive = _immersiveNotifier.value;
          return ClipRRect(
            borderRadius: immersive ? BorderRadius.zero : BorderRadius.circular(16),
            child: SizedBox(
              width: double.infinity,
              height: immersive ? double.infinity : widget.height,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _buildMediaLayer(),
                  _buildShell(immersive: immersive),
                  _freezeRecoveryBanner(),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMediaLayer() {
    final yc = _ytController;
    final c = _controller;

    final Widget mediaLayer;
    if (_isYoutube) {
      if (yc == null) {
        mediaLayer = const Stack(
          fit: StackFit.expand,
          children: [_LoadingIndicator(isBuffering: false)],
        );
      } else {
        mediaLayer = _PersistentYoutubeView(
          key: _youtubeViewKey,
          controller: yc,
          onReady: _playerReady ? null : _onYoutubeIframeReady,
        );
      }
    } else if (c != null && c.value.isInitialized) {
      mediaLayer = _NativeCore(
        key: const ValueKey<String>('native-view'),
        controller: c,
      );
    } else if (_nativeInitFailed || _loadTimedOut) {
      mediaLayer = _VideoErrorPanel(onRetry: _retryNativeLoad);
    } else {
      mediaLayer = const Stack(
        fit: StackFit.expand,
        children: [_LoadingIndicator(isBuffering: false)],
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        mediaLayer,
        if (_isYoutube && _loadTimedOut && !_playerReady)
          _VideoErrorPanel(onRetry: () => unawaited(_retryYoutubeLoad())),
      ],
    );
  }

}

class _PersistentYoutubeView extends StatelessWidget {
  const _PersistentYoutubeView({
    super.key,
    required this.controller,
    this.onReady,
  });

  final YoutubePlayerController controller;
  final VoidCallback? onReady;

  @override
  Widget build(BuildContext context) {
    return _YoutubeCore(controller: controller, onReady: onReady);
  }
}

// ─────────────────────────────────────────────
//  VIDEO SHELL  (inline player with auto-hide)
// ─────────────────────────────────────────────

class _VideoShell extends StatefulWidget {
  const _VideoShell({
    super.key,
    required this.isYoutube,
    this.nativeController,
    this.ytController,
    this.catalogDurationLabel,
    required this.speed,
    required this.volume,
    required this.onSpeed,
    required this.onVolume,
    required this.onFullscreen,
    required this.onTogglePlay,
    this.showInitialLoading = false,
    this.showBuffering = false,
    this.showLoadError = false,
    this.onRetryLoad,
    this.onSeekDragStart,
    this.onSeekDragEnd,
    this.onSeekCommitted,
    this.isFullscreenMode = false,
  });

  final bool isFullscreenMode;
  final bool isYoutube;
  final VideoPlayerController? nativeController;
  final YoutubePlayerController? ytController;
  final String? catalogDurationLabel;
  final double speed;
  final double volume;
  final ValueChanged<double> onSpeed;
  final ValueChanged<double> onVolume;
  final VoidCallback onFullscreen;
  final VoidCallback onTogglePlay;
  final bool showInitialLoading;
  final bool showBuffering;
  final bool showLoadError;
  final VoidCallback? onRetryLoad;
  final VoidCallback? onSeekDragStart;
  final VoidCallback? onSeekDragEnd;
  final ValueChanged<Duration>? onSeekCommitted;

  @override
  State<_VideoShell> createState() => _VideoShellState();
}

class _VideoShellState extends State<_VideoShell>
    with SingleTickerProviderStateMixin {
  bool _showControls = true;
  Timer? _hideTimer;
  late AnimationController _fadeAnim;
  late Animation<double> _fadeIn;

  // seek-feedback overlay
  bool _showSeekFeedback = false;
  bool _seekForward = true;
  Timer? _seekFeedbackTimer;

  @override
  void initState() {
    super.initState();
    _fadeAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
      value: 1,
    );
    _fadeIn = CurvedAnimation(parent: _fadeAnim, curve: Curves.easeOut);
    _startHideTimer();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _seekFeedbackTimer?.cancel();
    _fadeAnim.dispose();
    super.dispose();
  }

  // ── tap / double-tap ─────────────────────────

  void _onTap() {
    if (!_isPlaying && !widget.showInitialLoading) {
      widget.onTogglePlay();
      _revealControls();
      return;
    }
    if (!_showControls) {
      _revealControls();
    } else {
      _hideControls();
    }
  }

  void _onDoubleTapLeft() => _seekBy(-10);
  void _onDoubleTapRight() => _seekBy(10);

  void _seekBy(int seconds) {
    Duration? committed;
    final c = widget.nativeController;
    if (c != null && c.value.isInitialized) {
      final dur = c.value.duration;
      var target = c.value.position + Duration(seconds: seconds);
      if (target.isNegative) target = Duration.zero;
      if (dur > Duration.zero && target > dur) target = dur;
      unawaited(c.seekTo(target));
      committed = target;
    }
    final yc = widget.ytController;
    if (yc != null) {
      var target = yc.value.position + Duration(seconds: seconds);
      if (target.isNegative) target = Duration.zero;
      yc.seekTo(target, allowSeekAhead: true);
      committed = target;
    }
    if (committed != null) {
      widget.onSeekCommitted?.call(committed);
    }
    setState(() {
      _seekForward = seconds > 0;
      _showSeekFeedback = true;
    });
    _seekFeedbackTimer?.cancel();
    _seekFeedbackTimer =
        Timer(const Duration(milliseconds: 700), () {
      if (mounted) setState(() => _showSeekFeedback = false);
    });
    _revealControls();
  }

  void _revealControls() {
    setState(() => _showControls = true);
    _fadeAnim.forward();
    _startHideTimer();
  }

  void _hideControls() {
    _hideTimer?.cancel();
    setState(() => _showControls = false);
    _fadeAnim.reverse();
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() => _showControls = false);
        _fadeAnim.reverse();
      }
    });
  }

  void _keepAlive() => _startHideTimer();

  // ── play/pause ───────────────────────────────

  bool get _isPlaying {
    final yc = widget.ytController;
    if (yc != null) {
      return yc.value.playerState == PlayerState.playing;
    }
    final nc = widget.nativeController;
    if (nc != null && nc.value.isInitialized) {
      return nc.value.isPlaying;
    }
    return false;
  }

  // ── build ────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Video media qatlamda — fon shaffof, aks holda qora ekran bo‘ladi.
        if (widget.showInitialLoading)
            const _LoadingIndicator(isBuffering: false),
          if (widget.showBuffering)
            const _LoadingIndicator(isBuffering: true),
          if (widget.showLoadError && widget.onRetryLoad != null)
            _VideoErrorPanel(onRetry: widget.onRetryLoad!),

          // ── double-tap zones ──
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: _onTap,
                  onDoubleTap: _onDoubleTapLeft,
                ),
              ),
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: _onTap,
                  onDoubleTap: _onDoubleTapRight,
                ),
              ),
            ],
          ),

          // ── seek feedback ──
          if (_showSeekFeedback)
            Align(
              alignment:
                  _seekForward ? Alignment.centerRight : Alignment.centerLeft,
              child: _SeekFeedback(forward: _seekForward),
            ),

          // ── controls overlay ──
          FadeTransition(
            opacity: _fadeIn,
            child: IgnorePointer(
              ignoring: !_showControls,
              child: _ControlsOverlay(
                isYoutube: widget.isYoutube,
                nativeController: widget.nativeController,
                ytController: widget.ytController,
                catalogDurationLabel: widget.catalogDurationLabel,
                isPlaying: _isPlaying,
                speed: widget.speed,
                volume: widget.volume,
                onTogglePlay: widget.onTogglePlay,
                onSpeed: (s) {
                  widget.onSpeed(s);
                  _keepAlive();
                },
                onVolume: (v) {
                  widget.onVolume(v);
                  _keepAlive();
                },
                onFullscreen: widget.onFullscreen,
                isFullscreenMode: widget.isFullscreenMode,
                onSeekDragStart: widget.onSeekDragStart,
                onSeekDragEnd: widget.onSeekDragEnd,
                onSkip: _seekBy,
                onSeek: (pos) {
                  final nc = widget.nativeController;
                  if (nc != null && nc.value.isInitialized) {
                    unawaited(nc.seekTo(pos));
                  }
                  widget.ytController?.seekTo(pos, allowSeekAhead: true);
                  widget.onSeekCommitted?.call(pos);
                  _keepAlive();
                },
              ),
            ),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
//  VIDEO CORES
// ─────────────────────────────────────────────

class _NativeCore extends StatelessWidget {
  const _NativeCore({
    super.key,
    required this.controller,
    this.fillScreen = false,
  });
  final VideoPlayerController controller;
  final bool fillScreen;

  @override
  Widget build(BuildContext context) {
    final ar = controller.value.aspectRatio > 0
        ? controller.value.aspectRatio
        : 16 / 9;
    final video = VideoPlayer(controller);
    if (fillScreen) {
      final size = controller.value.size;
      final w = size.width > 0 ? size.width : ar * 100;
      final h = size.height > 0 ? size.height : 100.0;
      return SizedBox.expand(
        child: FittedBox(
          fit: BoxFit.contain,
          child: SizedBox(width: w, height: h, child: video),
        ),
      );
    }
    return Center(
      child: AspectRatio(
        aspectRatio: ar,
        child: video,
      ),
    );
  }
}

class _YoutubeCore extends StatelessWidget {
  const _YoutubeCore({
    required this.controller,
    this.onReady,
  });
  final YoutubePlayerController controller;
  final VoidCallback? onReady;

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: Center(
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: YoutubePlayer(
            key: ValueKey<String>('youtube-${controller.initialVideoId}'),
            controller: controller,
            showVideoProgressIndicator: false,
            progressIndicatorColor: const Color(0xFF1E6BB8),
            topActions: const [],
            bottomActions: const [],
            onReady: onReady,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  CONTROLS OVERLAY
// ─────────────────────────────────────────────

class _ControlsOverlay extends StatelessWidget {
  const _ControlsOverlay({
    required this.isYoutube,
    this.nativeController,
    this.ytController,
    this.catalogDurationLabel,
    required this.isPlaying,
    required this.speed,
    required this.volume,
    required this.onTogglePlay,
    required this.onSpeed,
    required this.onVolume,
    required this.onFullscreen,
    required this.onSeek,
    this.isFullscreenMode = false,
    this.onSeekDragStart,
    this.onSeekDragEnd,
    this.onSkip,
  });

  final bool isYoutube;
  final VideoPlayerController? nativeController;
  final YoutubePlayerController? ytController;
  final String? catalogDurationLabel;
  final bool isPlaying;
  final double speed;
  final double volume;
  final VoidCallback onTogglePlay;
  final ValueChanged<double> onSpeed;
  final ValueChanged<double> onVolume;
  final VoidCallback onFullscreen;
  final bool isFullscreenMode;
  final ValueChanged<Duration> onSeek;
  final VoidCallback? onSeekDragStart;
  final VoidCallback? onSeekDragEnd;
  final ValueChanged<int>? onSkip;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0x88000000),
            Colors.transparent,
            Colors.transparent,
            Color(0xCC000000),
          ],
          stops: [0.0, 0.25, 0.65, 1.0],
        ),
      ),
      child: Stack(
        children: [
          // ── bottom bar (play/pause shu yerda — markazda ikkinchi tugma yo‘q) ──
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _BottomBar(
              isYoutube: isYoutube,
              nativeController: nativeController,
              ytController: ytController,
              catalogDurationLabel: catalogDurationLabel,
              isPlaying: isPlaying,
              onTogglePlay: onTogglePlay,
              speed: speed,
              volume: volume,
              onSpeed: onSpeed,
              onVolume: onVolume,
              onFullscreen: onFullscreen,
              isFullscreenMode: isFullscreenMode,
              onSeek: onSeek,
              onSeekDragStart: onSeekDragStart,
              onSeekDragEnd: onSeekDragEnd,
              onSkip: onSkip,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  PLAY / PAUSE BUTTON
// ─────────────────────────────────────────────
class _PlayPauseListener extends StatelessWidget {
  const _PlayPauseListener({
    this.nativeController,
    this.ytController,
    required this.fallbackPlaying,
    required this.onTap,
    this.compact = false,
  });

  final VideoPlayerController? nativeController;
  final YoutubePlayerController? ytController;
  final bool fallbackPlaying;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final nc = nativeController;
    if (nc != null) {
      return AnimatedBuilder(
        animation: nc,
        builder: (context, _) => _PlayPauseButton(
          isPlaying: nc.value.isInitialized && nc.value.isPlaying,
          onTap: onTap,
          compact: compact,
        ),
      );
    }
    final yc = ytController;
    if (yc != null) {
      return ListenableBuilder(
        listenable: yc,
        builder: (context, _) => _PlayPauseButton(
          isPlaying: yc.value.playerState == PlayerState.playing,
          onTap: onTap,
          compact: compact,
        ),
      );
    }
    return _PlayPauseButton(
      isPlaying: fallbackPlaying,
      onTap: onTap,
      compact: compact,
    );
  }
}

class _PlayPauseButton extends StatelessWidget {
  const _PlayPauseButton({
    required this.isPlaying,
    required this.onTap,
    this.compact = false,
  });
  final bool isPlaying;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return IconButton(
        onPressed: onTap,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
        icon: Icon(
          isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
          color: Colors.white,
          size: 26,
        ),
      );
    }
    return GestureDetector(
      onTap: onTap,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: Container(
          key: ValueKey(isPlaying),
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.55),
            shape: BoxShape.circle,
          ),
          child: Icon(
            isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
            color: Colors.white,
            size: 38,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  BOTTOM BAR  (seek + controls)
// ─────────────────────────────────────────────

class _BottomBar extends StatefulWidget {
  const _BottomBar({
    required this.isYoutube,
    this.nativeController,
    this.ytController,
    this.catalogDurationLabel,
    required this.isPlaying,
    required this.onTogglePlay,
    required this.speed,
    required this.volume,
    required this.onSpeed,
    required this.onVolume,
    required this.onFullscreen,
    required this.onSeek,
    this.isFullscreenMode = false,
    this.onSeekDragStart,
    this.onSeekDragEnd,
    this.onSkip,
  });

  final bool isYoutube;
  final VideoPlayerController? nativeController;
  final YoutubePlayerController? ytController;
  final String? catalogDurationLabel;
  final bool isPlaying;
  final VoidCallback onTogglePlay;
  final double speed;
  final double volume;
  final ValueChanged<double> onSpeed;
  final ValueChanged<double> onVolume;
  final VoidCallback onFullscreen;
  final bool isFullscreenMode;
  final ValueChanged<Duration> onSeek;
  final VoidCallback? onSeekDragStart;
  final VoidCallback? onSeekDragEnd;
  final ValueChanged<int>? onSkip;

  @override
  State<_BottomBar> createState() => _BottomBarState();
}

class _BottomBarState extends State<_BottomBar> {
  double? _dragValue; // null = not dragging

  Duration get _position {
    if (widget.nativeController != null) {
      return widget.nativeController!.value.position;
    }
    return widget.ytController?.value.position ?? Duration.zero;
  }

  Duration get _duration {
    if (widget.nativeController != null) {
      return widget.nativeController!.value.duration;
    }
    return widget.ytController?.metadata.duration ?? Duration.zero;
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (d.inHours > 0) {
      return '${d.inHours}:$m:$s';
    }
    return '$m:$s';
  }

  int? _parseCatalogDurationMs(String label) {
    final parts = label.trim().split(':');
    if (parts.isEmpty) return null;
    try {
      if (parts.length == 2) {
        final minutes = int.parse(parts[0]);
        final seconds = int.parse(parts[1]);
        return (minutes * 60 + seconds) * 1000;
      }
      if (parts.length == 3) {
        final hours = int.parse(parts[0]);
        final minutes = int.parse(parts[1]);
        final seconds = int.parse(parts[2]);
        return (hours * 3600 + minutes * 60 + seconds) * 1000;
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final nc = widget.nativeController;
    if (nc != null) {
      return AnimatedBuilder(
        animation: nc,
        builder: (context, _) => _buildBar(),
      );
    }
    final yc = widget.ytController;
    if (yc != null) {
      return ListenableBuilder(
        listenable: yc,
        builder: (context, _) => _buildBar(),
      );
    }
    return _buildBar();
  }

  Widget _buildBar() {
    final pos = _position;
    final dur = _duration;
    final hint = widget.catalogDurationLabel?.trim() ?? '';
    final catalogMs = _parseCatalogDurationMs(hint);
    final totalMs = dur.inMilliseconds > 0
        ? dur.inMilliseconds
        : (catalogMs ?? 0);
    final total = totalMs.toDouble();
    final current = _dragValue ?? pos.inMilliseconds.toDouble();
    final fraction = total > 0 ? (current / total).clamp(0.0, 1.0) : 0.0;
    final showCatalogTotal = dur.inMilliseconds <= 0 && hint.isNotEmpty && hint != '00:00';
    final totalTimeText = showCatalogTotal ? hint : _fmt(dur);

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _SeekBar(
            fraction: fraction,
            onChangeStart: (v) {
              if (total <= 0) return;
              widget.onSeekDragStart?.call();
              setState(() => _dragValue = v * total);
            },
            onChanged: (v) {
              if (total <= 0) return;
              setState(() => _dragValue = v * total);
            },
            onChangeEnd: (v) {
              // Always clear the drag state, even when the duration became
              // unknown mid-drag. Returning early here left `_userSeeking`
              // stuck true, which silently disabled progress saving, position
              // tracking and the playback health check for the rest of the
              // session.
              if (total > 0) {
                final target = Duration(
                  milliseconds: (v * total).round().clamp(0, total.round()),
                );
                widget.onSeek(target);
              }
              setState(() => _dragValue = null);
              widget.onSeekDragEnd?.call();
            },
          ),

          // ── time + buttons ──
          Row(
            children: [
              _PlayPauseListener(
                nativeController: widget.nativeController,
                ytController: widget.ytController,
                fallbackPlaying: widget.isPlaying,
                onTap: widget.onTogglePlay,
                compact: true,
              ),
              const SizedBox(width: 4),
              Text(
                _fmt(Duration(milliseconds: current.round())),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              const Text(
                ' / ',
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
              Text(
                totalTimeText,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              if (widget.onSkip != null) ...[
                _IconBtn(
                  icon: Icons.replay_10_rounded,
                  tooltip: '-10s',
                  onTap: () => widget.onSkip!(-10),
                ),
                _IconBtn(
                  icon: Icons.forward_10_rounded,
                  tooltip: '+10s',
                  onTap: () => widget.onSkip!(10),
                ),
              ],
              const Spacer(),
              _VolumeButton(volume: widget.volume, onVolume: widget.onVolume),
              const SizedBox(width: 4),
              _SpeedButton(speed: widget.speed, onSpeed: widget.onSpeed),
              const SizedBox(width: 4),
              _IconBtn(
                icon: widget.isFullscreenMode
                    ? Icons.fullscreen_exit_rounded
                    : Icons.fullscreen_rounded,
                tooltip: widget.isFullscreenMode
                    ? "Kichiklashtirish"
                    : "Katta ko'rish",
                onTap: widget.onFullscreen,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  SEEK BAR
// ─────────────────────────────────────────────

class _SeekBar extends StatelessWidget {
  const _SeekBar({
    required this.fraction,
    required this.onChangeStart,
    required this.onChanged,
    required this.onChangeEnd,
  });

  final double fraction;
  final ValueChanged<double> onChangeStart;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onChangeEnd;

  @override
  Widget build(BuildContext context) {
    return SliderTheme(
      data: SliderTheme.of(context).copyWith(
        trackHeight: 3,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
        activeTrackColor: const Color(0xFF1E6BB8),
        inactiveTrackColor: Colors.white30,
        thumbColor: Colors.white,
        overlayColor: Colors.white24,
      ),
      child: Slider(
        value: fraction,
        onChangeStart: onChangeStart,
        onChanged: onChanged,
        onChangeEnd: onChangeEnd,
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  SMALL CONTROL BUTTONS
// ─────────────────────────────────────────────

class _IconBtn extends StatelessWidget {
  const _IconBtn({required this.icon, required this.onTap, this.tooltip});
  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip ?? '',
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, color: Colors.white, size: 22),
        ),
      ),
    );
  }
}

class _VolumeButton extends StatelessWidget {
  const _VolumeButton({required this.volume, required this.onVolume});
  final double volume;
  final ValueChanged<double> onVolume;

  IconData get _icon {
    if (volume == 0) return Icons.volume_off_rounded;
    if (volume < 0.5) return Icons.volume_down_rounded;
    return Icons.volume_up_rounded;
  }

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<double>(
      initialValue: volume,
      onSelected: onVolume,
      offset: const Offset(0, -120),
      color: const Color(0xFF1E1E2E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      itemBuilder: (_) => [
        _volItem(0.0, '🔇  0%'),
        _volItem(0.25, '🔉  25%'),
        _volItem(0.5, '🔉  50%'),
        _volItem(0.75, '🔊  75%'),
        _volItem(1.0, '🔊  100%'),
      ],
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Icon(_icon, color: Colors.white, size: 22),
      ),
    );
  }

  PopupMenuItem<double> _volItem(double v, String label) => PopupMenuItem(
        value: v,
        child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 13)),
      );
}

class _SpeedButton extends StatelessWidget {
  const _SpeedButton({required this.speed, required this.onSpeed});
  final double speed;
  final ValueChanged<double> onSpeed;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<double>(
      initialValue: speed,
      onSelected: onSpeed,
      offset: const Offset(0, -180),
      color: const Color(0xFF1E1E2E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      itemBuilder: (_) => VideoPlaybackPrefs.allowedSpeeds
          .map(_speedItem)
          .toList(growable: false),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.speed_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 3),
            Text(
              '${speed}x',
              style: const TextStyle(
                  color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  PopupMenuItem<double> _speedItem(double v) => PopupMenuItem(
        value: v,
        child: Row(
          children: [
            Icon(
              Icons.check,
              size: 16,
              color: v == speed ? const Color(0xFF1E6BB8) : Colors.transparent,
            ),
            const SizedBox(width: 8),
            Text(
              '${v}x',
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: v == speed ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      );
}

// ─────────────────────────────────────────────
//  SEEK FEEDBACK  (+10s / −10s bubble)
// ─────────────────────────────────────────────

class _SeekFeedback extends StatelessWidget {
  const _SeekFeedback({required this.forward});
  final bool forward;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              forward ? Icons.forward_10_rounded : Icons.replay_10_rounded,
              color: Colors.white,
              size: 28,
            ),
            const SizedBox(width: 6),
            Text(
              forward ? '+10s' : '−10s',
              style: const TextStyle(
                  color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  LOADING INDICATOR
// ─────────────────────────────────────────────

class _LoadingIndicator extends StatelessWidget {
  const _LoadingIndicator({this.isBuffering = false});

  final bool isBuffering;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: ColoredBox(
          color: isBuffering
              ? Colors.black.withValues(alpha: 0.35)
              : Colors.black,
          child: const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation(Color(0xFF1E6BB8)),
              strokeWidth: 3,
            ),
          ),
        ),
      ),
    );
  }
}

class _VideoErrorPanel extends StatelessWidget {
  const _VideoErrorPanel({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: Colors.white70, size: 40),
          const SizedBox(height: 12),
          const Text(
            'Video yuklashda muammo bo‘ldi',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Qayta urinish'),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  YOUTUBE ID EXTRACTOR
// ─────────────────────────────────────────────

String? _extractYouTubeId(String input) {
  final value = input.trim();
  if (value.isEmpty) return null;
  final idPattern = RegExp(r'^[a-zA-Z0-9_-]{11}$');
  if (idPattern.hasMatch(value)) return value;
  final uri = Uri.tryParse(value);
  if (uri == null) return null;
  if (uri.host.contains('youtu.be')) {
    final seg = uri.pathSegments.isNotEmpty ? uri.pathSegments.first : '';
    return idPattern.hasMatch(seg) ? seg : null;
  }
  if (uri.host.contains('youtube.com')) {
    final v = uri.queryParameters['v'];
    if (v != null && idPattern.hasMatch(v)) return v;
    for (final prefix in ['embed', 'live', 'shorts']) {
      if (uri.pathSegments.length >= 2 && uri.pathSegments.first == prefix) {
        final id = uri.pathSegments[1];
        if (idPattern.hasMatch(id)) return id;
      }
    }
  }
  return null;
}