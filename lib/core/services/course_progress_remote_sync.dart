import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../http_request_timeouts.dart';
import '../state/auth_controller.dart';
import '../state/progress_controller.dart';

/// Barcha sahifalardan chaqirish mumkin — video progressni serverdan bir marta olib,
/// [progressControllerProvider]ga qo‘llaydi (dublikat so‘rovlarni birlashtiradi).
final class CourseProgressRemoteSync {
  CourseProgressRemoteSync._();

  static Future<void>? _inFlight;

  /// Serverdan `GET .../courses/progress` — muvaffaqiyatli bo‘lsa state yangilanadi.
  static Future<void> refresh(WidgetRef ref) {
    final existing = _inFlight;
    if (existing != null) return existing;
    final run = _doRefresh(ref);
    _inFlight = run;
    run.whenComplete(() {
      if (identical(_inFlight, run)) _inFlight = null;
    });
    return run;
  }

  static Future<void> _doRefresh(WidgetRef ref) async {
    final auth = ref.read(authControllerProvider);
    final progress = ref.read(progressControllerProvider.notifier);
    final userId = auth.userId ?? '';
    final baseUrl = getApiBaseUrl();
    if (userId.isEmpty || baseUrl.isEmpty) return;
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/api/v1/courses/progress?user_id=$userId'))
          .timeout(
            isLikelyLocalDevBaseUrl(baseUrl)
                ? const Duration(seconds: 10)
                : const Duration(seconds: 15),
          );
      if (response.statusCode < 200 || response.statusCode >= 300) return;
      final body = jsonDecode(response.body);
      if (body is! Map<String, dynamic>) return;
      final items = body['items'];
      if (items is! List) return;
      final completedByCourse = <String, Set<String>>{};
      final watchedByCourse = <String, Set<String>>{};
      for (final raw in items) {
        if (raw is! Map<String, dynamic>) continue;
        final courseId = (raw['course_id'] ?? '').toString();
        final lessonId = (raw['lesson_id'] ?? '').toString();
        if (courseId.isEmpty || lessonId.isEmpty) continue;
        final watchedSec = int.tryParse((raw['watched_sec'] ?? '0').toString()) ?? 0;
        if (watchedSec > 0) {
          watchedByCourse.putIfAbsent(courseId, () => <String>{}).add(lessonId);
        }
        if (raw['completed'] == true) {
          completedByCourse.putIfAbsent(courseId, () => <String>{}).add(lessonId);
        }
      }
      progress.mergeWatchedFromServer(watchedByCourse);
      progress.mergeCompletedFromServer(completedByCourse);
    } catch (e) {
      debugPrint('[CourseProgressRemoteSync] $e');
    }
  }
}
