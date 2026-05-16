import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../config/feature_flags.dart';
import '../data/models/banner_models.dart';
import '../data/models/slide_models.dart';
import '../data/repositories/http_banners_repository.dart';
import '../data/repositories/http_slides_repository.dart';
import '../di/providers.dart';
import '../http_request_timeouts.dart';
import 'catalog_service.dart';

/// Fetches optional combined home bundle when [HomeAggregateConfig.enabled] is true.
///
/// Server must set `ENABLE_HOME_AGGREGATE_ENDPOINT=true`; otherwise returns `false`
/// (caller falls back to parallel requests).
class HomeAggregateService {
  HomeAggregateService._();

  static Future<bool> tryFetchAndSeed(WidgetRef ref) async {
    if (!HomeAggregateConfig.enabled) return false;
    final baseUrl = getApiBaseUrl();
    if (baseUrl.isEmpty) return false;

    final uri = Uri.parse('$baseUrl/api/v1/home');
    debugPrint('[API][home.bundle][request] $uri');
    try {
      final response = await http
          .get(uri, headers: const {'Cache-Control': 'no-cache'})
          .timeout(homeAggregateHttpTimeoutForBaseUrl(baseUrl));
      debugPrint('[API][home.bundle][response] status=${response.statusCode}');
      if (response.statusCode == 404) {
        debugPrint('[API][home.bundle][skip] endpoint disabled on server');
        return false;
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return false;
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) return false;

      final slidesRepo = ref.read(slidesRepositoryProvider);
      final bannersRepo = ref.read(bannersRepositoryProvider);

      final slidesRaw = decoded['slides'];
      if (slidesRaw is Map<String, dynamic> && slidesRepo is HttpSlidesRepository) {
        final items = slidesRaw['items'];
        if (items is List) {
          final parsed = items
              .whereType<Map<String, dynamic>>()
              .map(HomeSlideItem.fromJson)
              .toList(growable: false);
          slidesRepo.seedFromHomeBundle(parsed);
        }
      }

      final bannersRaw = decoded['banners'];
      if (bannersRaw is Map<String, dynamic> && bannersRepo is HttpBannersRepository) {
        final items = bannersRaw['items'];
        if (items is List) {
          final parsed = items
              .whereType<Map<String, dynamic>>()
              .map(CourseBannerItem.fromJson)
              .toList(growable: false);
          bannersRepo.seedFromHomeBundle(parsed);
        }
      }

      final coursesRaw = decoded['courses'];
      if (coursesRaw is Map<String, dynamic>) {
        CatalogService.applyCoursesFromHomePayload(coursesRaw);
      }

      return true;
    } catch (e, st) {
      debugPrint('[API][home.bundle][error] $e\n$st');
      return false;
    }
  }
}
