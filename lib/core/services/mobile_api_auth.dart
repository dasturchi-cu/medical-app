import 'auth_service.dart';

/// Mobil API so'rovlarida sessiya tasdiqlash uchun header va body maydonlari.
class MobileApiAuth {
  MobileApiAuth._();

  static LocalAuthUser? get storedUser => AuthService.storedUser;

  static LocalAuthUser? get _user => AuthService.storedUser;

  static Map<String, String> headers({Map<String, String>? extra}) {
    final user = _user;
    final token = user?.sessionToken.trim() ?? '';
    final uid = user?.id.trim() ?? '';
    return {
      if (extra != null) ...extra,
      if (uid.isNotEmpty) 'X-User-Id': uid,
      if (token.isNotEmpty) 'X-Session-Token': token,
    };
  }

  static Map<String, dynamic> withSession(Map<String, dynamic> body) {
    final user = _user;
    final token = user?.sessionToken.trim() ?? '';
    if (token.isEmpty) return body;
    return {...body, 'session_token': token};
  }

  static String sessionQuery({required String userId}) {
    final token = _user?.sessionToken.trim() ?? '';
    if (token.isEmpty) return '';
    return '&session_token=${Uri.encodeQueryComponent(token)}';
  }
}
