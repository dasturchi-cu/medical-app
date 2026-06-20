import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../services/catalog_service.dart';
import '../services/course_stats_cache.dart';
import 'auth_controller.dart';

class CourseCardStats {
  const CourseCardStats({
    required this.ratingAvg,
    required this.ratingCount,
    required this.commentsCount,
    required this.commentersCount,
  });

  final double ratingAvg;
  final int ratingCount;
  final int commentsCount;
  final int commentersCount;
}

/// Reyting/sharhlar local optimistic yangilanganda kartalarda darhol ko'rsatish uchun override map.
final courseCardStatsOverrideProvider =
    StateProvider<Map<String, CourseCardStats>>((ref) => const <String, CourseCardStats>{});

/// Online banner/content kartalari uchun optimistic override map (key = content key yoki course id).
final contentCardStatsOverrideProvider =
    StateProvider<Map<String, CourseCardStats>>((ref) => const <String, CourseCardStats>{});

Future<CourseCardStats> _loadCourseCardStats({
  required String courseId,
  required String userId,
  required String baseUrl,
}) async {
  return CourseStatsCache.statsOrFetch(
    key: courseId,
    userId: userId,
    useFeedbackApi: false,
    fetch: () async {
      final hasUser = userId.trim().isNotEmpty;
      final uri = Uri.parse(
        hasUser
            ? '$baseUrl/api/v1/courses/$courseId/stats?user_id=$userId'
            : '$baseUrl/api/v1/courses/$courseId/stats',
      );
      debugPrint('[API][courses.card_stats][request] $uri');
      final response = await http.get(uri).timeout(const Duration(seconds: 8));
      debugPrint('[API][courses.card_stats][response] status=${response.statusCode}');
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('Card stats xatolik (${response.statusCode}).');
      }
      final body = jsonDecode(response.body);
      if (body is! Map<String, dynamic>) {
        throw Exception('Card stats JSON emas.');
      }
      return CourseCardStats(
        ratingAvg: double.tryParse((body['rating_avg'] ?? '0').toString()) ?? 0,
        ratingCount: int.tryParse((body['rating_count'] ?? '0').toString()) ?? 0,
        commentsCount: int.tryParse((body['comments_count'] ?? '0').toString()) ?? 0,
        commentersCount: int.tryParse((body['commenters_count'] ?? '0').toString()) ?? 0,
      );
    },
  );
}

/// Bosh sahifa «Nevrologiya» kartalari — barcha kurslar statistikasi parallel yuklanadi (keshlangan).
final neurologyHomeStatsProvider =
    FutureProvider.family<Map<String, CourseCardStats>, String>((ref, catalogKey) async {
  ref.watch(authControllerProvider);
  final baseUrl = getApiBaseUrl();
  final courseIds = CatalogService.courses
      .map((c) => c.id.trim())
      .where((id) => id.isNotEmpty)
      .toList(growable: false);
  if (baseUrl.isEmpty || courseIds.isEmpty) return const {};
  final userId = ref.read(authControllerProvider).userId ?? '';
  return CourseStatsCache.homeBatchOrFetch(
    catalogIdentity: catalogKey,
    userId: userId,
    fetch: () async {
      final entries = await Future.wait(
        courseIds.map((id) async {
          try {
            final stats = await _loadCourseCardStats(
              courseId: id,
              userId: userId,
              baseUrl: baseUrl,
            );
            return MapEntry(id, stats);
          } catch (_) {
            return MapEntry(
              id,
              const CourseCardStats(
                ratingAvg: 0,
                ratingCount: 0,
                commentsCount: 0,
                commentersCount: 0,
              ),
            );
          }
        }),
      );
      return Map<String, CourseCardStats>.fromEntries(entries);
    },
  );
});

/// Karta statistikasi — keshlangan, sahifa qayta ochilganda tez.
final courseCardStatsProvider = FutureProvider.family<CourseCardStats, String>((ref, courseId) async {
  ref.keepAlive();
  final auth = ref.watch(authControllerProvider);
  final userId = auth.userId ?? '';
  final baseUrl = getApiBaseUrl();
  if (baseUrl.isEmpty || courseId.trim().isEmpty) {
    return const CourseCardStats(ratingAvg: 0, ratingCount: 0, commentsCount: 0, commentersCount: 0);
  }
  try {
    return await _loadCourseCardStats(
      courseId: courseId.trim(),
      userId: userId,
      baseUrl: baseUrl,
    );
  } catch (_) {
    return const CourseCardStats(ratingAvg: 0, ratingCount: 0, commentsCount: 0, commentersCount: 0);
  }
});

Future<CourseCardStats> _loadContentCardStats({
  required String key,
  required bool useFeedbackApi,
  required String userId,
  required String baseUrl,
}) async {
  return CourseStatsCache.statsOrFetch(
    key: key,
    userId: userId,
    useFeedbackApi: useFeedbackApi,
    fetch: () async {
      final hasUser = userId.trim().isNotEmpty;
      final path = useFeedbackApi
          ? (hasUser ? '/api/v1/feedback/$key/stats?user_id=$userId' : '/api/v1/feedback/$key/stats')
          : (hasUser ? '/api/v1/courses/$key/stats?user_id=$userId' : '/api/v1/courses/$key/stats');
      final uri = Uri.parse('$baseUrl$path');
      debugPrint('[API][content.card_stats][request] $uri');
      final response = await http.get(uri).timeout(const Duration(seconds: 8));
      debugPrint('[API][content.card_stats][response] status=${response.statusCode}');
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('Content card stats xatolik (${response.statusCode}).');
      }
      final body = jsonDecode(response.body);
      if (body is! Map<String, dynamic>) {
        throw Exception('Content card stats JSON emas.');
      }
      return CourseCardStats(
        ratingAvg: double.tryParse((body['rating_avg'] ?? '0').toString()) ?? 0,
        ratingCount: int.tryParse((body['rating_count'] ?? '0').toString()) ?? 0,
        commentsCount: int.tryParse((body['comments_count'] ?? '0').toString()) ?? 0,
        commentersCount: int.tryParse((body['commenters_count'] ?? '0').toString()) ?? 0,
      );
    },
  );
}

final contentCardStatsProvider = FutureProvider.family<CourseCardStats, ({String key, bool useFeedbackApi})>((
  ref,
  args,
) async {
  ref.keepAlive();
  final auth = ref.watch(authControllerProvider);
  final userId = auth.userId ?? '';
  final baseUrl = getApiBaseUrl();
  final key = args.key.trim();
  if (baseUrl.isEmpty || key.isEmpty) {
    return const CourseCardStats(ratingAvg: 0, ratingCount: 0, commentsCount: 0, commentersCount: 0);
  }
  try {
    return await _loadContentCardStats(
      key: key,
      useFeedbackApi: args.useFeedbackApi,
      userId: userId,
      baseUrl: baseUrl,
    );
  } catch (_) {
    return const CourseCardStats(ratingAvg: 0, ratingCount: 0, commentsCount: 0, commentersCount: 0);
  }
});
