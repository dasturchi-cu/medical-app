import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

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
    /// Katalogdan (masalan `duration_uz`); player metadata kelguncha 00:00 o‘rniga.
    this.catalogDurationLabel,
  });

  final String url;
  final double height;
  final int initialWatchedSec;
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
  bool _wasPlayingBeforePause = false;
  bool _wasBuffering = false;
  bool _fullscreenLocked = false;
  DateTime? _lastFullscreenTapAt;
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

  bool _playerReady = false;

  /// Tashqaridan (masalan, orqaga tugmasi) immersive rejimdan chiqish.
  Future<void> exitImmersive() => _closeImmersiveFullscreen();
  bool _isInitialLoading = true;
  bool _isBufferingUi = false;
  bool _loadTimedOut = false;
  bool _pendingPlay = false;
  Timer? _loadTimeoutTimer;
  Timer? _playRecoveryTimer;
  int _playRecoveryAttempts = 0;
  DateTime? _playerReadyAt;

  static const _loadTimeout = Duration(seconds: 10);

  bool get _isYoutube => _youtubeId != null && _ytController != null;
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
    if (widget.initialWatchedSec > 0) {
      _lastKnownPositionSec = widget.initialWatchedSec;
      _lastReportedSec = widget.initialWatchedSec;
    }
    _pendingInitialSeekSec =
        widget.initialWatchedSec > 0 ? widget.initialWatchedSec : null;
    _youtubeId = _extractYouTubeId(widget.url);
    _VideoLog.init(
      videoId: _youtubeId,
      sourceType: _youtubeId != null ? 'youtube' : 'native',
      url: widget.url,
    );
    _VideoLog.mounted(videoId: _youtubeId ?? widget.url);
    _VideoLog.loadStart(videoId: _youtubeId, url: widget.url);
    _startLoadTimeout();
    unawaited(_bootstrapPlayer());
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

  Future<void> _bootstrapPlayer() async {
    _speed = await VideoPlaybackPrefs.loadSpeed();
    if (!mounted) return;

    if (_youtubeId != null) {
      _ytController = YoutubePlayerController(
        initialVideoId: _youtubeId!,
        flags: const YoutubePlayerFlags(
          autoPlay: false,
          mute: false,
          forceHD: false,
          enableCaption: true,
          hideControls: true,
          controlsVisibleAtStart: false,
          hideThumbnail: false,
          disableDragSeek: false,
        ),
      )..addListener(_handleYoutubeProgress);
      if (mounted) setState(() {});
      return;
    }

    _controller = VideoPlayerController.networkUrl(
      Uri.parse(widget.url),
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    )..addListener(_handleVideoProgress);

    try {
      await _controller!.initialize();
      await _controller!.setVolume(_volume);
      await _controller!.setPlaybackSpeed(_speed);
      final dur = _controller!.value.duration.inSeconds;
      _markPlayerReady(durationSec: dur);
      await _applyResumePosition(_pendingInitialSeekSec ?? 0);
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
      _completedReported = false;
      _nativeInitFailed = false;
      _playerReady = false;
      _isInitialLoading = true;
      _isBufferingUi = false;
      _loadTimedOut = false;
      _pendingPlay = false;
      _playRecoveryAttempts = 0;
      _youtubeId = _extractYouTubeId(widget.url);
      _startLoadTimeout();
      unawaited(_bootstrapPlayer());
      return;
    }
    final newSec = widget.initialWatchedSec;
    if (newSec > _lastKnownPositionSec + 1) {
      _lastKnownPositionSec = newSec;
      if (newSec > _lastReportedSec) {
        _lastReportedSec = newSec;
      }
      final current = _currentPositionSec();
      if (current < newSec - 2) {
        unawaited(_applyResumePosition(newSec));
      }
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
    if (!mounted || _immersiveFullscreen) return;
    _snapshotPlayback();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _immersiveFullscreen) return;
      if (_isYoutube) return;
      unawaited(_syncPlaybackAfterLayout(reason: 'metrics'));
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _snapshotPlayback();
      _emitProgressFromCurrent(force: true);
    }
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

  void _snapshotPlayback() {
    final sec = _currentPositionSec();
    if (sec > _lastKnownPositionSec) {
      _lastKnownPositionSec = sec;
    }
  }

  Future<void> _applyResumePosition(int sec) async {
    if (sec <= 0) return;
    final c = _controller;
    if (c != null && c.value.isInitialized) {
      final maxSeek = (c.value.duration.inSeconds - 1).clamp(0, 1 << 30);
      final safe = sec.clamp(0, maxSeek).toInt();
      if (safe <= 0) return;
      final current = c.value.position.inSeconds;
      if ((current - safe).abs() <= 2) return;
      _VideoLog.seekStart(from: current, to: safe);
      await c.seekTo(Duration(seconds: safe));
      _VideoLog.seekComplete(currentTime: safe);
      _lastKnownPositionSec = safe;
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
      _lastKnownPositionSec = safe;
      if (safe > _lastReportedSec) _lastReportedSec = safe;
    }
  }

  void _startLoadTimeout() {
    _loadTimeoutTimer?.cancel();
    _loadTimeoutTimer = Timer(_loadTimeout, () {
      if (!mounted || _playerReady) return;
      _VideoLog.loadingTimeout();
      setState(() {
        _loadTimedOut = true;
        _isInitialLoading = false;
      });
    });
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
    _cachedWatchProgress = null;
    _VideoLog.unmounted(videoId: _youtubeId ?? widget.url);
    WidgetsBinding.instance.removeObserver(this);
    _progressFlushTimer?.cancel();
    _healthCheckTimer?.cancel();
    _uiProgressTimer?.cancel();
    _loadTimeoutTimer?.cancel();
    _playRecoveryTimer?.cancel();
    _emitProgressDisposeSafe();
    unawaited(_restoreAppSystemUi());
    _immersiveNotifier.dispose();
    _disposeControllers();
    super.dispose();
  }

  Future<void> _restoreAppSystemUi() async {
    await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  /// dispose() da parent callback chaqirilmaydi (Riverpod/deactivated xato).
  void _emitProgressDisposeSafe() {
    final watchedSec = _lastKnownPositionSec;
    if (watchedSec <= 0) return;
    debugPrint('[VIDEO_PROGRESS] dispose-safe snapshot seconds=$watchedSec');
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
    if (watchedSec > _lastKnownPositionSec) {
      _lastKnownPositionSec = watchedSec;
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
    if (watchedSec > _lastKnownPositionSec) {
      _lastKnownPositionSec = watchedSec;
    }
    if (watchedSec >= 1 && !_firstProgressReported) {
      _emitProgressFromCurrent(force: false);
    }
    final durationSec = c.metadata.duration.inSeconds;

    if (v.isReady && !_playerReady) {
      _markPlayerReady(durationSec: durationSec > 0 ? durationSec : 1);
      _applyYoutubeSettingsWhenReady();
    }

    final seekSec = _pendingInitialSeekSec;
    if (seekSec != null && durationSec > 0 && watchedSec < seekSec - 1) {
      unawaited(_applyResumePosition(seekSec));
      _pendingInitialSeekSec = null;
    }

    final playing = v.playerState == PlayerState.playing;
    final buffering = v.playerState == PlayerState.buffering;
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
    final url = widget.url;
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

    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    if (!mounted) {
      _fullscreenLocked = false;
      return;
    }

    _immersiveNotifier.value = true;
    _VideoLog.fullscreenEnterDone(currentTime: positionBefore);
    _fullscreenLocked = false;
    debugPrint('[VIDEO_FULLSCREEN] cinema mode (no WebView rebuild)');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onImmersiveModeChanged?.call(true);
      if (wasPlaying && mounted) unawaited(_startPlayback());
    });
  }

  Future<void> _closeImmersiveFullscreen() async {
    if (!_immersiveFullscreen) return;

    _fullscreenLocked = true;
    _snapshotPlayback();
    _emitProgressFromCurrent(force: true);
    final position = _currentPositionSec();
    debugPrint('[VIDEO_FULLSCREEN] immersive close position=$position');

    _immersiveNotifier.value = false;
    await _restoreAppSystemUi();
    widget.onImmersiveModeChanged?.call(false);
    if (_isYoutube) {
      _runYoutubeWhenReady((c) {
        final dur = c.metadata.duration.inSeconds;
        if (dur > 0) {
          final safe = position.clamp(0, dur - 1);
          if ((c.value.position.inSeconds - safe).abs() > 2) {
            c.seekTo(Duration(seconds: safe), allowSeekAhead: true);
          }
        }
      });
    }

    if (!mounted) {
      _fullscreenLocked = false;
      return;
    }

    _fullscreenLocked = false;
    _VideoLog.fullscreenExitDone(currentTime: position);
    debugPrint('[VIDEO_FULLSCREEN] immersive ended');
  }

  Future<void> _openFullscreen() async {
    await _openImmersiveFullscreen();
  }

  Widget _buildShell({required bool immersive}) {
    return RepaintBoundary(
      child: _VideoShell(
        key: const ValueKey<String>('lesson-video-shell'),
        isYoutube: _isYoutube,
        nativeController: _controller,
        ytController: _ytController,
        fillScreen: false,
        isFullscreenMode: immersive,
        catalogDurationLabel: widget.catalogDurationLabel,
        speed: _speed,
        volume: _volume,
        onSpeed: _setSpeed,
        onVolume: _setVolume,
        onFullscreen: immersive
            ? () => unawaited(_closeImmersiveFullscreen())
            : () => unawaited(_openFullscreen()),
        onYoutubeReady: _playerReady
            ? null
            : () {
                final dur = _ytController?.metadata.duration.inSeconds ?? 0;
                if (dur > 0) _markPlayerReady(durationSec: dur);
              },
        onSeekDragStart: () => _userSeeking = true,
        onSeekDragEnd: () {
          _userSeeking = false;
          _snapshotPlayback();
          _emitProgressFromCurrent(force: true);
        },
        onTogglePlay: _handlePlayPause,
        showInitialLoading: _isInitialLoading && !_playerReady,
        showBuffering: _isBufferingUi && _isPlayingNow,
        showLoadError: _loadTimedOut || _nativeInitFailed,
        onRetryLoad: _isYoutube ? null : _retryNativeLoad,
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
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          width: double.infinity,
          height: widget.height,
          child: Stack(
            fit: StackFit.expand,
            children: [
              _buildMediaLayer(),
              ListenableBuilder(
                listenable: _immersiveNotifier,
                builder: (context, _) =>
                    _buildShell(immersive: _immersiveNotifier.value),
              ),
              _freezeRecoveryBanner(),
            ],
          ),
        ),
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
          key: ValueKey<String>('yt-${_youtubeId ?? widget.url}'),
          controller: yc,
          onReady: _playerReady
              ? null
              : () {
                  final dur = yc.metadata.duration.inSeconds;
                  if (dur > 0) _markPlayerReady(durationSec: dur);
                },
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
        if (_isYoutube && _loadTimedOut)
          _VideoErrorPanel(
            onRetry: () {
              setState(() {
                _loadTimedOut = false;
                _isInitialLoading = true;
                _playerReady = false;
                _playerReadyAt = null;
              });
              _disposeControllers();
              _youtubeId = _extractYouTubeId(widget.url);
              _startLoadTimeout();
              unawaited(_bootstrapPlayer());
            },
          ),
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
    this.onYoutubeReady,
    this.onSeekDragStart,
    this.onSeekDragEnd,
    this.fillScreen = false,
    this.isFullscreenMode = false,
  });

  final bool fillScreen;
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
  final VoidCallback? onYoutubeReady;
  final VoidCallback? onSeekDragStart;
  final VoidCallback? onSeekDragEnd;

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
    final c = widget.nativeController;
    if (c != null && c.value.isInitialized) {
      final dur = c.value.duration;
      var target = c.value.position + Duration(seconds: seconds);
      if (target.isNegative) target = Duration.zero;
      if (dur > Duration.zero && target > dur) target = dur;
      unawaited(c.seekTo(target));
    }
    final yc = widget.ytController;
    if (yc != null) {
      var target = yc.value.position + Duration(seconds: seconds);
      if (target.isNegative) target = Duration.zero;
      yc.seekTo(target);
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
    return Container(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // ── video content ──
          if (widget.isYoutube)
            _YoutubeCore(
              controller: widget.ytController!,
              onReady: widget.onYoutubeReady,
            )
          else if (widget.nativeController != null)
            _NativeCore(controller: widget.nativeController!)
          else
            const ColoredBox(color: Colors.black),

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
                  widget.ytController?.seekTo(pos);
                  _keepAlive();
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  VIDEO CORES
// ─────────────────────────────────────────────

class _NativeCore extends StatelessWidget {
  const _NativeCore({super.key, required this.controller});
  final VideoPlayerController controller;

  @override
  Widget build(BuildContext context) {
    final ar = controller.value.aspectRatio > 0
        ? controller.value.aspectRatio
        : 16 / 9;
    return Center(
      child: AspectRatio(
        aspectRatio: ar,
        child: VideoPlayer(controller),
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
    return Center(
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: YoutubePlayer(
          key: const ValueKey<String>('youtube-iframe'),
          controller: controller,
          showVideoProgressIndicator: false,
          progressIndicatorColor: const Color(0xFF1E6BB8),
          topActions: const [],
          bottomActions: const [],
          onReady: onReady,
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
          // ── center play/pause (controller listener — tez yangilanish) ──
          Center(
            child: _PlayPauseListener(
              nativeController: nativeController,
              ytController: ytController,
              fallbackPlaying: isPlaying,
              onTap: onTogglePlay,
            ),
          ),

          // ── bottom bar ──
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _BottomBar(
              isYoutube: isYoutube,
              nativeController: nativeController,
              ytController: ytController,
              catalogDurationLabel: catalogDurationLabel,
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
//  PLAY / PAUSE BUTTONas
// ─────────────────────────────────────────────
//  PLAY / PAUSE BUTTONas
class _PlayPauseListener extends StatelessWidget {
  const _PlayPauseListener({
    this.nativeController,
    this.ytController,
    required this.fallbackPlaying,
    required this.onTap,
  });

  final VideoPlayerController? nativeController;
  final YoutubePlayerController? ytController;
  final bool fallbackPlaying;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final nc = nativeController;
    if (nc != null) {
      return AnimatedBuilder(
        animation: nc,
        builder: (context, _) => _PlayPauseButton(
          isPlaying: nc.value.isInitialized && nc.value.isPlaying,
          onTap: onTap,
        ),
      );
    }
    final yc = ytController;
    if (yc != null) {
      return ListenableBuilder(
        listenable: yc,
        builder: (context, _) => _PlayPauseButton(
          isPlaying: yc.value.isPlaying,
          onTap: onTap,
        ),
      );
    }
    return _PlayPauseButton(isPlaying: fallbackPlaying, onTap: onTap);
  }
}

class _PlayPauseButton extends StatelessWidget {
  const _PlayPauseButton({required this.isPlaying, required this.onTap});
  final bool isPlaying;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
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

  @override
  Widget build(BuildContext context) {
    return _buildBar();
  }

  Widget _buildBar() {
    final pos = _position;
    final dur = _duration;
    final total = dur.inMilliseconds.toDouble();
    final current = _dragValue ?? pos.inMilliseconds.toDouble();
    final fraction = total > 0 ? (current / total).clamp(0.0, 1.0) : 0.0;
    final hint = widget.catalogDurationLabel?.trim() ?? '';
    final showCatalogTotal = dur.inMilliseconds <= 0 && hint.isNotEmpty && hint != '00:00';
    final totalTimeText = showCatalogTotal ? hint : _fmt(dur);

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── seek bar (native only; YT has its own) ──
          if (!widget.isYoutube)
            _SeekBar(
              fraction: fraction,
              onChangeStart: (v) {
                widget.onSeekDragStart?.call();
                setState(() => _dragValue = v * total);
              },
              onChanged: (v) {
                setState(() => _dragValue = v * total);
              },
              onChangeEnd: (v) {
                final target =
                    Duration(milliseconds: (v * total).round().clamp(0, total.round()));
                widget.onSeek(target);
                setState(() => _dragValue = null);
                widget.onSeekDragEnd?.call();
              },
            ),

          // ── time + buttons ──
          Row(
            children: [
              if (!widget.isYoutube) ...[
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
              ],
              if (!widget.isYoutube && widget.onSkip != null) ...[
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