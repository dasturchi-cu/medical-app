import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../core/config/api_config.dart';
import '../core/services/lesson_slides_bytes_cache.dart';
import '../core/services/media_url_resolver.dart';

/// Tarmoq rasmi — bir marta yuklanadi, keyin disk/xotira keshidan o'qiladi.
class CachedRemoteImage extends StatefulWidget {
  const CachedRemoteImage({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.cacheWidth,
    this.cacheHeight,
    this.filterQuality = FilterQuality.low,
    this.gaplessPlayback = true,
    this.errorBuilder,
    this.loadingBuilder,
  });

  final String url;
  final BoxFit fit;
  final double? width;
  final double? height;
  final int? cacheWidth;
  final int? cacheHeight;
  final FilterQuality filterQuality;
  final bool gaplessPlayback;
  final Widget Function(BuildContext context, Object? error)? errorBuilder;
  final Widget Function(BuildContext context, Widget child, ImageChunkEvent? progress)?
      loadingBuilder;

  @override
  State<CachedRemoteImage> createState() => _CachedRemoteImageState();
}

class _CachedRemoteImageState extends State<CachedRemoteImage> {
  late Future<Uint8List?> _bytesFuture;

  @override
  void initState() {
    super.initState();
    _bytesFuture = _load();
  }

  @override
  void didUpdateWidget(covariant CachedRemoteImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url.trim() != widget.url.trim()) {
      setState(() => _bytesFuture = _load());
    }
  }

  Future<Uint8List?> _load() async {
    final raw = widget.url.trim();
    if (raw.isEmpty) return null;
    if (raw.startsWith('data:image')) {
      final comma = raw.indexOf(',');
      if (comma <= 0) return null;
      try {
        return base64Decode(raw.substring(comma + 1).replaceAll(RegExp(r'\s'), ''));
      } catch (_) {
        return null;
      }
    }
    final resolved = MediaUrlResolver.resolveFetchUrl(raw, apiBaseUrl: getApiBaseUrl());
    if (resolved.isEmpty) return null;
    try {
      return await LessonSlidesBytesCache.loadBytes(
        resolved,
        apiBaseUrl: getApiBaseUrl(),
        fetcher: LessonSlidesBytesCache.fetchHttpBytes,
      );
    } catch (_) {
      return null;
    }
  }

  Widget _error(BuildContext context, [Object? error]) {
    if (widget.errorBuilder != null) {
      return widget.errorBuilder!(context, error);
    }
    return const ColoredBox(color: Color(0xFFE9F0FF));
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: _bytesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          if (widget.loadingBuilder != null) {
            return widget.loadingBuilder!(context, const SizedBox.shrink(), null);
          }
          return const ColoredBox(color: Color(0xFFE9F0FF));
        }
        final bytes = snapshot.data;
        if (bytes == null || bytes.isEmpty) {
          return _error(context, snapshot.error);
        }
        final image = Image.memory(
          bytes,
          fit: widget.fit,
          width: widget.width,
          height: widget.height,
          cacheWidth: widget.cacheWidth,
          cacheHeight: widget.cacheHeight,
          filterQuality: widget.filterQuality,
          gaplessPlayback: widget.gaplessPlayback,
          errorBuilder: (context, error, stackTrace) => _error(context, error),
        );
        if (widget.loadingBuilder != null) {
          return widget.loadingBuilder!(context, image, null);
        }
        return image;
      },
    );
  }
}
