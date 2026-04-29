import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

class VideoPlayerBox extends StatefulWidget {
  const VideoPlayerBox({
    super.key,
    required this.url,
    required this.height,
  });

  final String url;
  final double height;

  @override
  State<VideoPlayerBox> createState() => _VideoPlayerBoxState();
}

class _VideoPlayerBoxState extends State<VideoPlayerBox> {
  VideoPlayerController? _controller;
  YoutubePlayerController? _youtubeController;
  String? _youtubeId;
  double _speed = 1.0;

  @override
  void initState() {
    super.initState();
    _youtubeId = _extractYouTubeId(widget.url);
    if (_youtubeId != null) {
      _youtubeController = YoutubePlayerController(
        initialVideoId: _youtubeId!,
        flags: const YoutubePlayerFlags(
          autoPlay: false,
          forceHD: false,
          enableCaption: true,
        ),
      );
    } else {
      _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url))
        ..initialize().then((_) {
          if (!mounted) return;
          setState(() {});
        });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    _youtubeController?.dispose();
    super.dispose();
  }

  Future<void> _setSpeed(double speed) async {
    final c = _controller;
    if (c == null) return;
    await c.setPlaybackSpeed(speed);
    if (!mounted) return;
    setState(() => _speed = speed);
  }

  Future<void> _openFullscreen() async {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;

    final wasPlaying = c.value.isPlaying;
    final position = c.value.position;
    await c.pause();
    if (!mounted) return;

    await Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        builder: (_) => _FullscreenVideoPage(
          url: widget.url,
          startAt: position,
          speed: _speed,
          autoPlay: wasPlaying,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_youtubeId != null && _youtubeController != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          height: widget.height,
          child: YoutubePlayerBuilder(
            player: YoutubePlayer(
              controller: _youtubeController!,
              showVideoProgressIndicator: true,
              progressIndicatorColor: const Color(0xFF1E6BB8),
              progressColors: const ProgressBarColors(
                playedColor: Color(0xFF1E6BB8),
                handleColor: Color(0xFF1E6BB8),
              ),
            ),
            builder: (context, player) => ColoredBox(
              color: Colors.black,
              child: Center(child: player),
            ),
          ),
        ),
      );
    }

    final c = _controller;
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        color: Colors.black,
        height: widget.height,
        child: c == null || !c.value.isInitialized
            ? const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation(Color(0xFF1E6BB8)),
                ),
              )
            : Stack(
                alignment: Alignment.center,
                children: [
                  AspectRatio(
                    aspectRatio: c.value.aspectRatio,
                    child: VideoPlayer(c),
                  ),
                  Positioned(
                    top: 10,
                    right: 10,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: Material(
                        color: Colors.black.withValues(alpha: 0.35),
                        child: PopupMenuButton<double>(
                          initialValue: _speed,
                          tooltip: 'Tezlik',
                          onSelected: _setSpeed,
                          itemBuilder: (context) => const [
                            PopupMenuItem(value: 0.5, child: Text('0.5x')),
                            PopupMenuItem(value: 1.0, child: Text('1.0x')),
                            PopupMenuItem(value: 1.25, child: Text('1.25x')),
                            PopupMenuItem(value: 1.5, child: Text('1.5x')),
                            PopupMenuItem(value: 2.0, child: Text('2.0x')),
                          ],
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            child: Text(
                              '${_speed.toStringAsFixed(_speed == _speed.roundToDouble() ? 0 : 2)}x',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      ),
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
                  IconButton(
                    iconSize: 56,
                    color: Colors.white,
                    onPressed: () {
                      setState(() {
                        c.value.isPlaying ? c.pause() : c.play();
                      });
                    },
                    icon: Icon(c.value.isPlaying ? Icons.pause_circle : Icons.play_circle),
                  ),
                ],
              ),
      ),
    );
  }
}

String? _extractYouTubeId(String input) {
  final value = input.trim();
  if (value.isEmpty) return null;
  final idPattern = RegExp(r'^[a-zA-Z0-9_-]{11}$');
  if (idPattern.hasMatch(value)) return value;

  final uri = Uri.tryParse(value);
  if (uri == null) return null;
  if (uri.host.contains('youtu.be')) {
    final segment = uri.pathSegments.isNotEmpty ? uri.pathSegments.first : '';
    return idPattern.hasMatch(segment) ? segment : null;
  }
  if (uri.host.contains('youtube.com')) {
    final v = uri.queryParameters['v'];
    if (v != null && idPattern.hasMatch(v)) return v;
    if (uri.pathSegments.length >= 2 && uri.pathSegments.first == 'embed') {
      final embedId = uri.pathSegments[1];
      if (idPattern.hasMatch(embedId)) return embedId;
    }
    if (uri.pathSegments.length >= 2 && uri.pathSegments.first == 'live') {
      final liveId = uri.pathSegments[1];
      if (idPattern.hasMatch(liveId)) return liveId;
    }
    if (uri.pathSegments.length >= 2 && uri.pathSegments.first == 'shorts') {
      final shortsId = uri.pathSegments[1];
      if (idPattern.hasMatch(shortsId)) return shortsId;
    }
  }
  return null;
}

class _FullscreenVideoPage extends StatefulWidget {
  const _FullscreenVideoPage({
    required this.url,
    required this.startAt,
    required this.speed,
    required this.autoPlay,
  });

  final String url;
  final Duration startAt;
  final double speed;
  final bool autoPlay;

  @override
  State<_FullscreenVideoPage> createState() => _FullscreenVideoPageState();
}

class _FullscreenVideoPageState extends State<_FullscreenVideoPage> {
  VideoPlayerController? _controller;
  late double _speed;

  @override
  void initState() {
    super.initState();
    _speed = widget.speed;
    _lockLandscape();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..initialize().then((_) async {
        final c = _controller;
        if (c == null) return;
        await c.seekTo(widget.startAt);
        await c.setPlaybackSpeed(_speed);
        if (widget.autoPlay) await c.play();
        if (!mounted) return;
        setState(() {});
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
    _unlockOrientation();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (c == null || !c.value.isInitialized)
              const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation(Colors.white),
                ),
              )
            else
              SizedBox.expand(
                child: FittedBox(
                  fit: BoxFit.contain,
                  child: SizedBox(
                    width: c.value.size.width,
                    height: c.value.size.height,
                    child: VideoPlayer(c),
                  ),
                ),
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
              top: 8,
              right: 8,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: Material(
                  color: Colors.black.withValues(alpha: 0.35),
                  child: PopupMenuButton<double>(
                    initialValue: _speed,
                    tooltip: 'Tezlik',
                    onSelected: (speed) async {
                      final ctrl = _controller;
                      if (ctrl == null) return;
                      await ctrl.setPlaybackSpeed(speed);
                      if (!mounted) return;
                      setState(() => _speed = speed);
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(value: 0.5, child: Text('0.5x')),
                      PopupMenuItem(value: 1.0, child: Text('1.0x')),
                      PopupMenuItem(value: 1.25, child: Text('1.25x')),
                      PopupMenuItem(value: 1.5, child: Text('1.5x')),
                      PopupMenuItem(value: 2.0, child: Text('2.0x')),
                    ],
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      child: Text(
                        '${_speed.toStringAsFixed(_speed == _speed.roundToDouble() ? 0 : 2)}x',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (c != null && c.value.isInitialized)
              IconButton(
                iconSize: 72,
                color: Colors.white,
                onPressed: () {
                  setState(() {
                    c.value.isPlaying ? c.pause() : c.play();
                  });
                },
                icon: Icon(c.value.isPlaying ? Icons.pause_circle : Icons.play_circle),
              ),
          ],
        ),
      ),
    );
  }
}

