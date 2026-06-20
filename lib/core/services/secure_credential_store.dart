import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Session token va boshqa maxfiy ma'lumotlarni xavfsiz saqlash.
class SecureCredentialStore {
  SecureCredentialStore._();

  static const _authKey = 'auth_user_secure_v1';
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static Future<void> writeAuthJson(Map<String, dynamic> json) async {
    final raw = jsonEncode(json);
    try {
      await _storage.write(key: _authKey, value: raw);
      return;
    } catch (e) {
      debugPrint('[secure_store] write fallback: $e');
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_authKey, raw);
  }

  static Future<Map<String, dynamic>?> readAuthJson() async {
    String? raw;
    try {
      raw = await _storage.read(key: _authKey);
    } catch (e) {
      debugPrint('[secure_store] read fallback: $e');
    }
    if (raw == null || raw.isEmpty) {
      final prefs = await SharedPreferences.getInstance();
      raw = prefs.getString(_authKey);
    }
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } catch (_) {}
    return null;
  }

  static Future<void> clearAuth() async {
    try {
      await _storage.delete(key: _authKey);
    } catch (_) {}
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_authKey);
    await prefs.remove('auth_user_v1');
  }
}
