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
    String? phone,
  }) async {
    final uid = userId.trim();
    final key = courseKey.trim();
    if (key.isEmpty) return null;

    if (uid.isNotEmpty) {
      final byUser = await _readRaw(
        courseKey: key,
        userId: uid,
        useFeedbackApi: useFeedbackApi,
      );
      if (byUser != null) return byUser;
    }

    final normalizedPhone = _normalizePhone(phone);
    if (normalizedPhone.isNotEmpty) {
      return _readRaw(
        courseKey: key,
        userId: normalizedPhone,
        useFeedbackApi: useFeedbackApi,
        phoneKey: true,
      );
    }
    return null;
  }

  static String _normalizePhone(String? phone) =>
      (phone ?? '').replaceAll(RegExp(r'\D'), '');

  static Future<int?> _readRaw({
    required String courseKey,
    required String userId,
    required bool useFeedbackApi,
    bool phoneKey = false,
  }) async {
    final uid = userId.trim();
    if (uid.isEmpty) return null;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw == null || raw.isEmpty) return null;
      final body = jsonDecode(raw);
      if (body is! Map<String, dynamic>) return null;
      final entry = phoneKey
          ? _phoneEntryKey(courseKey: courseKey, phone: uid, useFeedbackApi: useFeedbackApi)
          : _entryKey(courseKey: courseKey, userId: uid, useFeedbackApi: useFeedbackApi);
      final stars = int.tryParse((body[entry] ?? '').toString());
      if (stars == null || stars < 1 || stars > 5) return null;
      return stars;
    } catch (e, st) {
      debugPrint('[MyRatingLocalStore.read][error] $e\n$st');
      return null;
    }
  }

  static String _phoneEntryKey({
    required String courseKey,
    required String phone,
    required bool useFeedbackApi,
  }) =>
      '${useFeedbackApi ? 'fb' : 'c'}|p|$courseKey|${_normalizePhone(phone)}';

  static Future<void> write({
    required String courseKey,
    required String userId,
    required int stars,
    bool useFeedbackApi = false,
    String? phone,
  }) async {
    final uid = userId.trim();
    final key = courseKey.trim();
    if (key.isEmpty) return;
    final safe = stars.clamp(1, 5);
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      final body = raw == null || raw.isEmpty
          ? <String, dynamic>{}
          : (jsonDecode(raw) is Map<String, dynamic> ? Map<String, dynamic>.from(jsonDecode(raw) as Map) : <String, dynamic>{});
      if (uid.isNotEmpty) {
        body[_entryKey(courseKey: key, userId: uid, useFeedbackApi: useFeedbackApi)] = safe;
      }
      final normalizedPhone = _normalizePhone(phone);
      if (normalizedPhone.isNotEmpty) {
        body[_phoneEntryKey(courseKey: key, phone: normalizedPhone, useFeedbackApi: useFeedbackApi)] = safe;
      }
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
