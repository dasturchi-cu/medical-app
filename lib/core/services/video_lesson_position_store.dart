import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Dars videosi pozitsiyasi — server javobi kelguncha telefonda saqlanadi.
class VideoLessonPositionStore {
  VideoLessonPositionStore._();

  static const _prefix = 'video_lesson_pos_v1';

  static Future<int> load(String storageKey) async {
    if (storageKey.trim().isEmpty) return 0;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getInt('$_prefix|$storageKey');
      return raw ?? 0;
    } catch (e, st) {
      debugPrint('[VideoLessonPositionStore.load] $e\n$st');
      return 0;
    }
  }

  static Future<void> save(String storageKey, int sec) async {
    if (storageKey.trim().isEmpty || sec <= 0) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('$_prefix|$storageKey', sec);
    } catch (e, st) {
      debugPrint('[VideoLessonPositionStore.save] $e\n$st');
    }
  }
}
