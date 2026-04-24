import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class VideoPlayerBox extends StatefulWidget {
  const VideoPlayerBox({
    super.key,
    required this.url,
  });

  final String url;

  @override
  State<VideoPlayerBox> createState() => _VideoPlayerBoxState();
}

class _VideoPlayerBoxState extends State<VideoPlayerBox> {
  VideoPlayerController? _controller;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..initialize().then((_) {
        if (!mounted) return;
        setState(() {});
      });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        color: Colors.black,
        height: 200,
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

