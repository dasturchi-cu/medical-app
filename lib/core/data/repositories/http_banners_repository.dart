import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../http_request_timeouts.dart';
import '../../services/home_feeds_disk_cache.dart';
import '../models/banner_models.dart';
import 'banners_repository.dart';

class HttpBannersRepository implements BannersRepository {
  HttpBannersRepository({
    required this.baseUrl,
    this.client,
  });

  final String baseUrl;
  final http.Client? client;

  http.Client get _client => client ?? http.Client();
  List<CourseBannerItem> _cached = const [];
  DateTime? _cachedAt;
  Future<List<CourseBannerItem>>? _inFlight;
  static const Duration _cacheTtl = Duration(seconds: 45);

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

  void _seedFromDiskIfNeeded() {
    if (_cached.isNotEmpty) return;
    final disk = HomeFeedsDiskCache.banners;
    if (disk.isEmpty) return;
    _cached = disk;
    _cachedAt = DateTime.now();
  }

  @override
  Future<List<CourseBannerItem>> fetchBanners({bool forceRefresh = false}) async {
    if (baseUrl.isEmpty) return const [];
    _seedFromDiskIfNeeded();
    final now = DateTime.now();
    if (!forceRefresh &&
        _cachedAt != null &&
        now.difference(_cachedAt!) <= _cacheTtl &&
        _cached.isNotEmpty) {
      return _cached;
    }
    final pending = _inFlight;
    if (pending != null) return pending;
    final future = _fetchBannersNetwork();
    _inFlight = future;
    try {
      return await future;
    } finally {
      if (identical(_inFlight, future)) _inFlight = null;
    }
  }

  Future<List<CourseBannerItem>> _fetchBannersNetwork() async {
    final now = DateTime.now();
    final uri = Uri.parse('$baseUrl/api/v1/banners?active_only=true');
    debugPrint('[API][banners.fetch][request] $uri');
    try {
      final response =
          await _client.get(uri).timeout(apiListFetchTimeoutForBaseUrl(baseUrl));
      debugPrint('[API][banners.fetch][response] status=${response.statusCode}');
      if (response.statusCode < 200 || response.statusCode >= 300) {
        debugPrint('[API][banners.fetch][warn] ${_errorMessage('HTTP', response.body)}');
        return const [];
      }
      final body = jsonDecode(response.body);
      if (body is! Map<String, dynamic>) return const [];
      final rawItems = body['items'];
      if (rawItems is! List) return const [];
      final items = rawItems
          .whereType<Map<String, dynamic>>()
          .map(CourseBannerItem.fromJson)
          .toList(growable: false);
      _cached = items;
      _cachedAt = now;
      if (items.isNotEmpty) {
        unawaited(HomeFeedsDiskCache.saveBanners(items));
      }
      return items;
    } catch (e, st) {
      debugPrint('[API][banners.fetch][error] $e\n$st');
      return _cached;
    }
  }

  /// Seeds cache after `GET /api/v1/home` so `fetchBanners()` skips network on first watch.
  void seedFromHomeBundle(List<CourseBannerItem> items) {
    _cached = List<CourseBannerItem>.from(items);
    _cachedAt = DateTime.now();
    if (items.isNotEmpty) {
      unawaited(HomeFeedsDiskCache.saveBanners(items));
    }
  }

  @override
  Stream<List<CourseBannerItem>> watchBanners({
    Duration pollInterval = const Duration(seconds: 20),
  }) {
    final controller = StreamController<List<CourseBannerItem>>();
    Timer? poller;
    var disposed = false;

    Future<void> push() async {
      if (disposed) return;
      controller.add(await fetchBanners());
    }

    unawaited(push());
    poller = Timer.periodic(pollInterval, (_) => unawaited(push()));
    controller.onCancel = () async {
      disposed = true;
      poller?.cancel();
      await controller.close();
    };
    return controller.stream;
  }
}
