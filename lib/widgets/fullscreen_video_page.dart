import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

/// Natija: fullscreen yopilganda pozitsiya va ijro holati.
class FullscreenVideoResult {
  const FullscreenVideoResult({
    required this.positionSec,
    required this.wasPlaying,
  });

  final int positionSec;
  final bool wasPlaying;
}

/// To‘liq ekran video (root navigator — pastki menyu / app bar yo‘q).
class FullscreenVideoPage extends StatefulWidget {
  const FullscreenVideoPage({
    super.key,
    required this.isYoutube,
    this.nativeController,
    this.ytController,
    required this.initialPositionSec,
    required this.initialWasPlaying,
    required this.speed,
    required this.volume,
    required this.onSpeed,
    required this.onVolume,
    required this.onTogglePlay,
    required this.onSeekDragStart,
    required this.onSeekDragEnd,
    required this.onSnapshotPosition,
    this.catalogDurationLabel,
    this.showBuffering = false,
    required this.shellBuilder,
  });

  /// [requestClose] — fullscreen tugmasi / orqaga.
  final Widget Function(BuildContext context, VoidCallback requestClose)
      shellBuilder;

  final bool isYoutube;
  final VideoPlayerController? nativeController;
  final YoutubePlayerController? ytController;
  final int initialPositionSec;
  final bool initialWasPlaying;
  final double speed;
  final double volume;
  final ValueChanged<double> onSpeed;
  final ValueChanged<double> onVolume;
  final VoidCallback onTogglePlay;
  final VoidCallback onSeekDragStart;
  final VoidCallback onSeekDragEnd;
  final VoidCallback onSnapshotPosition;
  final String? catalogDurationLabel;
  final bool showBuffering;

  @override
  State<FullscreenVideoPage> createState() => _FullscreenVideoPageState();
}

class _FullscreenVideoPageState extends State<FullscreenVideoPage> {
  bool _uiReady = false;

  @override
  void initState() {
    super.initState();
    debugPrint('[VIDEO_FULLSCREEN] route opened');
    _uiReady = !widget.isYoutube;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _restorePlaybackAfterOpen();
      if (mounted) setState(() => _uiReady = true);
    });
  }

  Future<void> _restorePlaybackAfterOpen() async {
    final sec = widget.initialPositionSec;
    debugPrint('[VIDEO_FULLSCREEN] seek after open position=$sec');
    final c = widget.nativeController;
    if (c != null && c.value.isInitialized && sec > 0) {
      final maxSeek = (c.value.duration.inSeconds - 1).clamp(0, 1 << 30);
      final safe = sec.clamp(0, maxSeek).toInt();
      if (safe > 0 && (c.value.position.inSeconds - safe).abs() > 2) {
        await c.seekTo(Duration(seconds: safe));
      }
    }
    final yc = widget.ytController;
    if (yc != null && sec > 0) {
      final dur = yc.metadata.duration.inSeconds;
      if (dur > 0) {
        final safe = sec.clamp(0, dur - 1).toInt();
        if (safe > 0 && (yc.value.position.inSeconds - safe).abs() > 2) {
          yc.seekTo(Duration(seconds: safe), allowSeekAhead: true);
        }
      }
    }
    if (widget.initialWasPlaying) {
      final c2 = widget.nativeController;
      if (c2 != null && c2.value.isInitialized) {
        await c2.play();
      }
      widget.ytController?.play();
    }
  }

  Future<void> _exitFullscreenUi() async {
    await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    debugPrint('[VIDEO_FULLSCREEN] orientation restored portrait');
  }

  int _currentPositionSec() {
    final c = widget.nativeController;
    if (c != null && c.value.isInitialized) {
      return c.value.position.inSeconds;
    }
    return widget.ytController?.value.position.inSeconds ?? widget.initialPositionSec;
  }

  bool get _isPlaying {
    final yc = widget.ytController;
    if (yc != null) {
      return yc.value.playerState == PlayerState.playing;
    }
    final c = widget.nativeController;
    return c != null && c.value.isInitialized && c.value.isPlaying;
  }

  Future<void> _close() async {
    widget.onSnapshotPosition();
    final position = _currentPositionSec();
    final wasPlaying = _isPlaying;
    debugPrint('[VIDEO_FULLSCREEN] route closing position=$position');
    final c = widget.nativeController;
    if (c != null && c.value.isInitialized) {
      await c.pause();
    }
    widget.ytController?.pause();
    if (!mounted) return;
    Navigator.of(context).pop(
      FullscreenVideoResult(positionSec: position, wasPlaying: wasPlaying),
    );
  }

  @override
  void dispose() {
    unawaited(_exitFullscreenUi());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_close());
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            SizedBox.expand(
              child: widget.shellBuilder(context, () => unawaited(_close())),
            ),
            if (!_uiReady && !widget.isYoutube)
              const Center(child: CircularProgressIndicator(color: Colors.white54)),
            Positioned(
              top: MediaQuery.paddingOf(context).top + 8,
              left: 8,
              child: IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
                onPressed: () => unawaited(_close()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
