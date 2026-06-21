import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Foydalanuvchi bergan kurs bahosi — ilova qayta ochilganda ham yulduzcha to‘liq ko‘rinsin.
class MyRatingLocalStore {
  MyRatingLocalStore._();

  static const _prefsKey = 'course_my_ratings_v1';

  static String _entryKey({
    required String courseKey,
    required String userId,
    required bool useFeedbackApi,
  }) =>
      '${useFeedbackApi ? 'fb' : 'c'}|$courseKey|${userId.trim()}';

  static Future<int?> read({
    required String courseKey,
    required String userId,
    bool useFeedbackApi = false,
  }) async {
    final uid = userId.trim();
    final key = courseKey.trim();
    if (uid.isEmpty || key.isEmpty) return null;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw == null || raw.isEmpty) return null;
      final body = jsonDecode(raw);
      if (body is! Map<String, dynamic>) return null;
      final stars = int.tryParse((body[_entryKey(courseKey: key, userId: uid, useFeedbackApi: useFeedbackApi)] ?? '').toString());
      if (stars == null || stars < 1 || stars > 5) return null;
      return stars;
    } catch (e, st) {
      debugPrint('[MyRatingLocalStore.read][error] $e\n$st');
      return null;
    }
  }

  static Future<void> write({
    required String courseKey,
    required String userId,
    required int stars,
    bool useFeedbackApi = false,
  }) async {
    final uid = userId.trim();
    final key = courseKey.trim();
    if (uid.isEmpty || key.isEmpty) return;
    final safe = stars.clamp(1, 5);
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      final body = raw == null || raw.isEmpty
          ? <String, dynamic>{}
          : (jsonDecode(raw) is Map<String, dynamic> ? Map<String, dynamic>.from(jsonDecode(raw) as Map) : <String, dynamic>{});
      body[_entryKey(courseKey: key, userId: uid, useFeedbackApi: useFeedbackApi)] = safe;
      await prefs.setString(_prefsKey, jsonEncode(body));
    } catch (e, st) {
      debugPrint('[MyRatingLocalStore.write][error] $e\n$st');
    }
  }

  static Future<void> remove({
    required String courseKey,
    required String userId,
    bool useFeedbackApi = false,
  }) async {
    final uid = userId.trim();
    final key = courseKey.trim();
    if (uid.isEmpty || key.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw == null || raw.isEmpty) return;
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return;
      final body = Map<String, dynamic>.from(decoded);
      body.remove(_entryKey(courseKey: key, userId: uid, useFeedbackApi: useFeedbackApi));
      await prefs.setString(_prefsKey, jsonEncode(body));
    } catch (e, st) {
      debugPrint('[MyRatingLocalStore.remove][error] $e\n$st');
    }
  }
}
