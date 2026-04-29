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

  LocalAuthUser copyWith({String? name}) {
    return LocalAuthUser(id: id, email: email, name: name ?? this.name);
  }
}

class AuthService {
  static final Map<String, LocalAuthUser> _usersByPhone = <String, LocalAuthUser>{};
  static LocalAuthUser? _currentUser;

  LocalAuthUser? get currentUser => _currentUser;

  Future<LocalAuthUser?> signIn({
    required String phone,
    required String password,
    String? displayName,
  }) async {
    final normalizedPhone = _normalizePhone(phone);
    if (normalizedPhone.isEmpty) {
      return null;
    }

    final requestedName = (displayName ?? '').trim();
    final existing = _usersByPhone[normalizedPhone];
    if (existing != null) {
      _currentUser = requestedName.isEmpty
          ? existing
          : existing.copyWith(name: requestedName);
    } else {
      _currentUser = LocalAuthUser(
        id: _makeUid(),
        email: normalizedPhone,
        name: requestedName,
      );
    }
    _usersByPhone[normalizedPhone] = _currentUser!;
    return _currentUser;
  }

  Future<LocalAuthUser?> updateCurrentUserName(String name) async {
    final current = _currentUser;
    if (current == null) return null;
    final updated = current.copyWith(name: name.trim());
    _currentUser = updated;
    _usersByPhone[current.email] = updated;
    return updated;
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
