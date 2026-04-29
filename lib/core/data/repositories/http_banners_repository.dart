import 'dart:convert';

import 'package:http/http.dart' as http;

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

  @override
  Future<List<CourseBannerItem>> fetchBanners() async {
    if (baseUrl.isEmpty) return const [];
    final uri = Uri.parse('$baseUrl/api/v1/banners?active_only=true');
    final response = await _client.get(uri);
    if (response.statusCode < 200 || response.statusCode >= 300) return const [];
    final body = jsonDecode(response.body);
    if (body is! Map<String, dynamic>) return const [];
    final rawItems = body['items'];
    if (rawItems is! List) return const [];
    return rawItems
        .whereType<Map<String, dynamic>>()
        .map(CourseBannerItem.fromJson)
        .toList(growable: false);
  }

  @override
  Stream<List<CourseBannerItem>> watchBanners({
    Duration pollInterval = const Duration(seconds: 8),
  }) async* {
    yield await fetchBanners();
    yield* Stream.periodic(pollInterval).asyncMap((_) => fetchBanners());
  }
}
