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
      final fullKey = '$_prefix|$storageKey';
      final existing = prefs.getInt(fullKey) ?? 0;
      // Agar avval saqlangan joy 10 soniyadan ko'p bo'lsa va yangi sec < 5 bo'lsa,
      // video endi boshlangandagi 1-2 soniya eski o'rnini o'chirib yubormasin!
      if (sec < 5 && existing > 10) return;
      await prefs.setInt(fullKey, sec);
    } catch (e, st) {
      debugPrint('[VideoLessonPositionStore.save] $e\n$st');
    }
  }
}

