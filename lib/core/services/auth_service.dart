import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';
import '../utils/device_id.dart';
import 'push_messaging.dart';

class AuthServiceError implements Exception {
  AuthServiceError(this.message);
  final String message;
}

class UserAccessStatus {
  const UserAccessStatus({
    required this.userId,
    required this.isBlocked,
    required this.adminContact,
    required this.sessionActive,
    required this.fullName,
    required this.phone,
  });

  final String userId;
  final bool isBlocked;
  final String adminContact;
  final bool sessionActive;
  final String fullName;
  final String phone;
}

class LocalAuthUser {
  const LocalAuthUser({
    required this.id,
    required this.email,
    required this.name,
    required this.sessionToken,
  });

  final String id;
  final String email;
  final String name;
  final String sessionToken;

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'name': name,
        'session_token': sessionToken,
      };

  factory LocalAuthUser.fromJson(Map<String, dynamic> json) => LocalAuthUser(
        id: (json['id'] ?? '').toString(),
        email: (json['email'] ?? '').toString(),
        name: (json['name'] ?? '').toString(),
        sessionToken: (json['session_token'] ?? '').toString(),
      );

  LocalAuthUser copyWith({String? name, String? email, String? sessionToken}) {
    return LocalAuthUser(
      id: id,
      email: email ?? this.email,
      name: name ?? this.name,
      sessionToken: sessionToken ?? this.sessionToken,
    );
  }
}

class AuthService {
  static const _prefsKey = 'auth_user_v1';
  static LocalAuthUser? _currentUser;

  LocalAuthUser? get currentUser => _currentUser;

  static Future<void> bootstrap() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null || raw.isEmpty) {
      _currentUser = null;
      return;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        _currentUser = null;
        return;
      }
      final map = Map<String, dynamic>.from(decoded);
      final restored = LocalAuthUser.fromJson(map);
      final tok = restored.sessionToken.trim();
      final uid = restored.id.trim();
      // Backend `session-status` session_token uchun min uzunlik; yaroqsiz yozuvni tiklamaymiz.
      if (uid.isEmpty || tok.length < 8) {
        await prefs.remove(_prefsKey);
        _currentUser = null;
        return;
      }
      _currentUser = restored;
    } catch (_) {
      _currentUser = null;
    }
  }

  Future<LocalAuthUser?> signIn({
    required String phone,
    required String password,
    String? displayName,
  }) async {
    final baseUrl = getApiBaseUrl();
    final normalizedPhone = _normalizePhone(phone);
    if (normalizedPhone.isEmpty || baseUrl.isEmpty) {
      throw AuthServiceError("API manzili topilmadi.");
    }

    final deviceId = await DeviceId.getStableDeviceId();
    final fcmToken = await getFcmTokenForLogin();
    final payload = <String, dynamic>{
      'phone': normalizedPhone,
      'password': password,
      'display_name': (displayName ?? '').trim(),
      'device_id': deviceId,
      'platform': 'android',
    };
    if (fcmToken != null && fcmToken.isNotEmpty) {
      payload['fcm_token'] = fcmToken;
    }
    final response = await http.post(
      Uri.parse('$baseUrl/api/v1/auth/mobile-login'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      try {
        final body = jsonDecode(response.body);
        if (body is Map<String, dynamic> && body["detail"] != null) {
          throw AuthServiceError(body["detail"].toString());
        }
      } catch (_) {}
      throw AuthServiceError("Kirishda xatolik yuz berdi.");
    }
    final body = jsonDecode(response.body);
    if (body is! Map<String, dynamic>) return null;
    _currentUser = LocalAuthUser(
      id: (body['user_id'] ?? '').toString(),
      email: (body['phone'] ?? normalizedPhone).toString(),
      name: (body['full_name'] ?? '').toString(),
      sessionToken: (body['session_token'] ?? '').toString(),
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, jsonEncode(_currentUser!.toJson()));
    return _currentUser;
  }

  Future<UserAccessStatus?> checkUserAccess(String userId) async {
    final baseUrl = getApiBaseUrl();
    if (baseUrl.isEmpty || userId.trim().isEmpty) return null;
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/api/v1/auth/session-status/$userId?session_token=${Uri.encodeQueryComponent(_currentUser?.sessionToken ?? "")}'))
          .timeout(const Duration(seconds: 8));
      if (response.statusCode < 200 || response.statusCode >= 300) return null;
      final body = jsonDecode(response.body);
      if (body is! Map<String, dynamic>) return null;
      return UserAccessStatus(
        userId: (body['user_id'] ?? userId).toString(),
        isBlocked: body['is_blocked'] == true,
        adminContact: (body['admin_contact'] ?? 'Neuroscienceadmin').toString(),
        sessionActive: body['session_active'] != false,
        fullName: (body['full_name'] ?? '').toString(),
        phone: (body['phone'] ?? '').toString(),
      );
    } catch (_) {
      return null;
    }
  }

  /// Admin panel yoki boshqa qurilmadan ism o‘zgarganda lokal keshni server bilan moslaydi.
  Future<LocalAuthUser?> refreshProfileFromServer() async {
    final current = _currentUser;
    if (current == null) return null;

    final status = await checkUserAccess(current.id);
    if (status == null) return null;

    final serverName = status.fullName.trim();
    final serverPhone = status.phone.trim();
    final nextName = serverName.isNotEmpty ? serverName : current.name;
    final nextEmail = serverPhone.isNotEmpty ? serverPhone : current.email;

    if (nextName == current.name && nextEmail == current.email) {
      return null;
    }

    final updated = current.copyWith(name: nextName, email: nextEmail);
    _currentUser = updated;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, jsonEncode(updated.toJson()));
    return updated;
  }

  Future<LocalAuthUser?> updateCurrentUserName(String name) async {
    final current = _currentUser;
    final baseUrl = getApiBaseUrl();
    final trimmed = name.trim();
    if (current == null || trimmed.isEmpty || baseUrl.isEmpty) return null;

    final response = await http.patch(
      Uri.parse('$baseUrl/api/v1/auth/mobile-profile'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({
        'user_id': current.id,
        'session_token': current.sessionToken,
        'display_name': trimmed,
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      try {
        final body = jsonDecode(response.body);
        if (body is Map<String, dynamic> && body['detail'] != null) {
          throw AuthServiceError(body['detail'].toString());
        }
      } catch (_) {}
      throw AuthServiceError('Ismni serverda yangilab bo‘lmadi (${response.statusCode}).');
    }

    final body = jsonDecode(response.body);
    if (body is! Map<String, dynamic>) return null;
    final updated = LocalAuthUser(
      id: (body['user_id'] ?? current.id).toString(),
      email: (body['phone'] ?? current.email).toString(),
      name: (body['full_name'] ?? trimmed).toString(),
      sessionToken: (body['session_token'] ?? current.sessionToken).toString(),
    );
    _currentUser = updated;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, jsonEncode(updated.toJson()));
    return updated;
  }

  Future<void> signOut() async {
    _currentUser = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
  }

  String _normalizePhone(String value) {
    return value.replaceAll(RegExp(r'\D'), '');
  }
}
