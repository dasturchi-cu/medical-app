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
  static final Set<String> _registeredEmails = <String>{'demo@user.com'};
  static LocalAuthUser? _currentUser;

  LocalAuthUser? get currentUser => _currentUser;

  Future<LocalAuthUser?> signIn({
    required String email,
    required String password,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    if (!_registeredEmails.contains(normalizedEmail)) {
      return null;
    }
    _currentUser = LocalAuthUser(
      id: _makeUid(),
      email: normalizedEmail,
      name: normalizedEmail.split('@').first,
    );
    return _currentUser;
  }

  Future<LocalAuthUser?> signUp({
    required String email,
    required String password,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    if (_registeredEmails.contains(normalizedEmail)) {
      throw StateError('Bu email allaqachon mavjud');
    }
    _registeredEmails.add(normalizedEmail);
    _currentUser = LocalAuthUser(
      id: _makeUid(),
      email: normalizedEmail,
      name: normalizedEmail.split('@').first,
    );
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
}
