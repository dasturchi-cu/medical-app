import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase/supabase.dart';

import '../../http_request_timeouts.dart';
import '../../services/home_feeds_disk_cache.dart';
import '../models/slide_models.dart';
import 'slides_repository.dart';

class HttpSlidesRepository implements SlidesRepository {
  HttpSlidesRepository({
    required this.baseUrl,
    this.client,
    this.realtimeClient,
  });

  final String baseUrl;
  final http.Client? client;
  final SupabaseClient? realtimeClient;

  http.Client get _client => client ?? http.Client();
  List<HomeSlideItem> _cached = const [];
  DateTime? _cachedAt;
  Future<List<HomeSlideItem>>? _inFlight;
  static const Duration _cacheTtl = Duration(seconds: 90);
  DateTime? _lastTimeoutLogAt;

  String _errorMessage(String fallback, String body) {
    try {
      final parsed = jsonDecode(body);
      if (parsed is Map<String, dynamic>) {
        final detail = parsed['detail']?.toString().trim() ?? '';
        if (detail.isNotEmpty) return detail;
      }
    } catch (_) {}
    return fallback;
  }

  @override
  Future<List<HomeSlideItem>> fetchSlides({bool forceRefresh = false}) async {
    if (baseUrl.isEmpty) return const [];
    if (_cached.isEmpty) {
      final disk = HomeFeedsDiskCache.slides;
      if (disk.isNotEmpty) {
        _cached = disk;
        _cachedAt = DateTime.now();
      }
    }
    final now = DateTime.now();
    if (!forceRefresh &&
        _cachedAt != null &&
        now.difference(_cachedAt!) <= _cacheTtl &&
        _cached.isNotEmpty) {
      return _cached;
    }
    final pending = _inFlight;
    if (pending != null) return pending;
    final future = _fetchSlidesNetwork();
    _inFlight = future;
    try {
      return await future;
    } finally {
      if (identical(_inFlight, future)) _inFlight = null;
    }
  }

  Future<List<HomeSlideItem>> _fetchSlidesNetwork() async {
    final now = DateTime.now();
    final uri = Uri.parse('$baseUrl/api/v1/slides?active_only=true');
    debugPrint('[API][slides.fetch][request] $uri');
    try {
      final response =
          await _client.get(uri).timeout(apiListFetchTimeoutForBaseUrl(baseUrl));
      debugPrint('[API][slides.fetch][response] status=${response.statusCode}');
      if (response.statusCode < 200 || response.statusCode >= 300) {
        debugPrint('[API][slides.fetch][warn] ${_errorMessage('HTTP', response.body)}');
        return const [];
      }
      final body = jsonDecode(response.body);
      if (body is! Map<String, dynamic>) return const [];
      final rawItems = body['items'];
      if (rawItems is! List) return const [];
      final items = rawItems
          .whereType<Map<String, dynamic>>()
          .map(HomeSlideItem.fromJson)
          .toList(growable: false);
      _cached = items;
      _cachedAt = now;
      if (items.isNotEmpty) {
        unawaited(HomeFeedsDiskCache.saveSlides(items));
      }
      return items;
    } catch (e) {
      final hasCached = _cached.isNotEmpty || HomeFeedsDiskCache.slides.isNotEmpty;
      if (e is TimeoutException || e is SocketException) {
        final now = DateTime.now();
        final shouldLog = _lastTimeoutLogAt == null ||
            now.difference(_lastTimeoutLogAt!) > const Duration(minutes: 1);
        if (shouldLog) {
          _lastTimeoutLogAt = now;
          debugPrint(
            hasCached
                ? '[API][slides.fetch][timeout] server sekin (cache ishlatilmoqda)'
                : '[API][slides.fetch][timeout] server javob bermadi',
          );
        }
      } else {
        debugPrint('[API][slides.fetch][error] $e');
      }
      if (_cached.isNotEmpty) return _cached;
      final disk = HomeFeedsDiskCache.slides;
      if (disk.isNotEmpty) {
        _cached = disk;
        _cachedAt = DateTime.now();
        return disk;
      }
      return const [];
    }
  }

  /// Seeds cache after `GET /api/v1/home` so `fetchSlides()` skips network on first watch.
  void seedFromHomeBundle(List<HomeSlideItem> items) {
    _cached = List<HomeSlideItem>.from(items);
    _cachedAt = DateTime.now();
    if (items.isNotEmpty) {
      unawaited(HomeFeedsDiskCache.saveSlides(items));
    }
  }

  @override
  Stream<List<HomeSlideItem>> watchSlides({
    Duration pollInterval = const Duration(seconds: 120),
  }) {
    final controller = StreamController<List<HomeSlideItem>>();
    RealtimeChannel? channel;
    Timer? poller;
    var disposed = false;
    var pushInFlight = false;

    Future<void> push() async {
      if (disposed || pushInFlight) return;
      pushInFlight = true;
      try {
        final items = await fetchSlides();
        if (!disposed && !controller.isClosed) {
          controller.add(items);
        }
      } finally {
        pushInFlight = false;
      }
    }

    Future<void> boot() async {
      await push();
      final client = realtimeClient;
      if (client != null) {
        channel = client
            .channel('app-home-slides')
            .onPostgresChanges(
              event: PostgresChangeEvent.all,
              schema: 'public',
              table: 'home_slides',
              callback: (_) => unawaited(push()),
            )
            .subscribe();
      }
      poller = Timer.periodic(pollInterval, (_) => unawaited(push()));
    }

    unawaited(boot());
    controller.onCancel = () async {
      disposed = true;
      poller?.cancel();
      if (channel != null) await realtimeClient?.removeChannel(channel!);
      await controller.close();
    };
    return controller.stream;
  }
}
