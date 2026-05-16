import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../state/progress_controller.dart';

/// Video kurs progressi — server javobidan oldin kartalarda ko‘rinsin.
class CourseProgressLocalStore {
  CourseProgressLocalStore._();

  static const _prefsKey = 'course_progress_local_v1';

  static Future<Map<String, CourseProgress>> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw == null || raw.isEmpty) return const {};
      final body = jsonDecode(raw);
      if (body is! Map<String, dynamic>) return const {};
      final byCourse = body['by_course'];
      if (byCourse is! Map) return const {};
      final out = <String, CourseProgress>{};
      for (final entry in byCourse.entries) {
        final courseId = entry.key.toString();
        final row = entry.value;
        if (row is! Map<String, dynamic>) continue;
        final watched = row['watched'];
        final completed = row['completed'];
        out[courseId] = CourseProgress(
          courseId: courseId,
          lastLessonId: row['last_lesson_id']?.toString(),
          watchedLessonIds: watched is List
              ? watched.map((e) => e.toString()).where((id) => id.isNotEmpty).toSet()
              : <String>{},
          completedLessonIds: completed is List
              ? completed.map((e) => e.toString()).where((id) => id.isNotEmpty).toSet()
              : <String>{},
          enrolled: row['enrolled'] == true,
        );
      }
      return out;
    } catch (e, st) {
      debugPrint('[CourseProgressLocalStore.load][error] $e\n$st');
      return const {};
    }
  }

  static Future<void> save(ProgressState state) async {
    if (state.byCourseId.isEmpty) return;
    try {
      final byCourse = <String, dynamic>{};
      for (final entry in state.byCourseId.entries) {
        final p = entry.value;
        byCourse[entry.key] = {
          'last_lesson_id': p.lastLessonId,
          'watched': p.watchedLessonIds.toList(growable: false),
          'completed': p.completedLessonIds.toList(growable: false),
          'enrolled': p.enrolled,
        };
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, jsonEncode({'by_course': byCourse}));
    } catch (e, st) {
      debugPrint('[CourseProgressLocalStore.save][error] $e\n$st');
    }
  }
}
