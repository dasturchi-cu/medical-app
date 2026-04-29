import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/ranking_models.dart';
import 'ranking_repository.dart';

class HttpRankingRepository implements RankingRepository {
  HttpRankingRepository({required this.baseUrl, this.client});

  final String baseUrl;
  final http.Client? client;

  http.Client get _client => client ?? http.Client();

  @override
  Future<List<RankingItemModel>> fetchRanking({int limit = 50}) async {
    if (baseUrl.isEmpty) return const [];
    final response = await _client.get(Uri.parse('$baseUrl/api/v1/ranking?limit=$limit'));
    if (response.statusCode < 200 || response.statusCode >= 300) return const [];
    final body = jsonDecode(response.body);
    if (body is! Map<String, dynamic>) return const [];
    final raw = body['items'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(RankingItemModel.fromJson)
        .toList(growable: false);
  }
}
