import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/slide_models.dart';
import 'slides_repository.dart';

class HttpSlidesRepository implements SlidesRepository {
  HttpSlidesRepository({
    required this.baseUrl,
    this.client,
  });

  final String baseUrl;
  final http.Client? client;

  http.Client get _client => client ?? http.Client();

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
  Future<List<HomeSlideItem>> fetchSlides() async {
    if (baseUrl.isEmpty) {
      throw Exception('API manzili topilmadi (slides).');
    }
    final uri = Uri.parse('$baseUrl/api/v1/slides?active_only=true');
    debugPrint('[API][slides.fetch][request] $uri');
    final response = await _client.get(uri);
    debugPrint('[API][slides.fetch][response] status=${response.statusCode}');
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        _errorMessage('Slaydlarni olishda xatolik (${response.statusCode}).', response.body),
      );
    }
    final body = jsonDecode(response.body);
    if (body is! Map<String, dynamic>) {
      throw Exception('Slaydlar javobi JSON emas.');
    }
    final rawItems = body['items'];
    if (rawItems is! List) {
      throw Exception("Slaydlar ro'yxati topilmadi.");
    }
    return rawItems
        .whereType<Map<String, dynamic>>()
        .map(HomeSlideItem.fromJson)
        .toList(growable: false);
  }

  @override
  Stream<List<HomeSlideItem>> watchSlides({
    Duration pollInterval = const Duration(seconds: 8),
  }) async* {
    yield await fetchSlides();
    yield* Stream.periodic(pollInterval).asyncMap((_) => fetchSlides());
  }
}
