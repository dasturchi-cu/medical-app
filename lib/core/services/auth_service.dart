import 'dart:math';

class LocalAuthUser {
  const LocalAuthUser({
    required this.id,
    required this.email,
    required this.name,
  });

  final String id;
  final String email;
  final String name;
}

class AuthService {
  static final Map<String, LocalAuthUser> _usersByPhone = <String, LocalAuthUser>{};
  static LocalAuthUser? _currentUser;

  LocalAuthUser? get currentUser => _currentUser;

  Future<LocalAuthUser?> signIn({
    required String phone,
    required String password,
  }) async {
    final normalizedPhone = _normalizePhone(phone);
    if (normalizedPhone.isEmpty) {
      return null;
    }

    _currentUser =
        _usersByPhone[normalizedPhone] ??
        LocalAuthUser(
          id: _makeUid(),
          email: normalizedPhone,
          name: 'User $normalizedPhone',
        );
    _usersByPhone[normalizedPhone] = _currentUser!;
    return _currentUser;
  }

  Future<void> signOut() async {
    _currentUser = null;
  }

  String _makeUid() {
    final rand = Random();
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    return List.generate(16, (_) => chars[rand.nextInt(chars.length)]).join();
  }

  String _normalizePhone(String value) {
    return value.replaceAll(RegExp(r'\D'), '');
  }
}
