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
      final userVal = prefs.getInt('$_prefix|$storageKey') ?? 0;
      final lessonId = storageKey.contains('|') ? storageKey.split('|').last : storageKey;
      final fallbackVal = prefs.getInt('$_prefix|$lessonId') ?? 0;
      return userVal > fallbackVal ? userVal : fallbackVal;
    } catch (e, st) {
      debugPrint('[VideoLessonPositionStore.load] $e\n$st');
      return 0;
    }
  }

  static Future<void> save(String storageKey, int sec) async {
    if (storageKey.trim().isEmpty || sec <= 0) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final fullKey = '$_prefix|$storageKey';
      final existing = prefs.getInt(fullKey) ?? 0;
      if (sec < 5 && existing > 10) return;
      await prefs.setInt(fullKey, sec);

      final lessonId = storageKey.contains('|') ? storageKey.split('|').last : storageKey;
      if (lessonId.isNotEmpty) {
        final fallbackKey = '$_prefix|$lessonId';
        final existingFallback = prefs.getInt(fallbackKey) ?? 0;
        if (!(sec < 5 && existingFallback > 10)) {
          await prefs.setInt(fallbackKey, sec);
        }
      }
    } catch (e, st) {
      debugPrint('[VideoLessonPositionStore.save] $e\n$st');
    }
  }

}

