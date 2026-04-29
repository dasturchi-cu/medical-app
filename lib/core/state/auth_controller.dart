import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../di/providers.dart';
import '../services/auth_service.dart';

class AuthState {
  final bool isLoggedIn;
  final String name;
  final String? userId;
  final String? email;

  const AuthState({
    required this.isLoggedIn,
    required this.name,
    required this.userId,
    required this.email,
  });

  AuthState copyWith({
    bool? isLoggedIn,
    String? name,
    String? userId,
    String? email,
  }) {
    return AuthState(
      isLoggedIn: isLoggedIn ?? this.isLoggedIn,
      name: name ?? this.name,
      userId: userId ?? this.userId,
      email: email ?? this.email,
    );
  }
}

final authControllerProvider =
    NotifierProvider<AuthController, AuthState>(AuthController.new);

class AuthController extends Notifier<AuthState> {
  @override
  AuthState build() {
    final user = ref.watch(authServiceProvider).currentUser;
    if (user == null) {
      return const AuthState(
        isLoggedIn: false,
        name: 'Mehmon',
        userId: null,
        email: null,
      );
    }
    return _fromUser(user);
  }

  AuthState _fromUser(LocalAuthUser user) {
    final guessedName = user.name;
    return AuthState(
      isLoggedIn: true,
      name: guessedName.trim().isEmpty ? 'Foydalanuvchi' : guessedName,
      userId: user.id,
      email: user.email,
    );
  }

  Future<String?> login({
    required String email,
    required String password,
  }) async {
    try {
      final user = await ref
          .read(authServiceProvider)
          .signIn(email: email.trim(), password: password.trim());
      if (user == null) {
        return 'Email yoki parol noto‘g‘ri';
      }
      state = _fromUser(user);
      return null;
    } catch (_) {
      return 'Xatolik yuz berdi. Qayta urinib ko‘ring';
    }
  }

  Future<String?> register({
    required String email,
    required String password,
  }) async {
    try {
      final user = await ref
          .read(authServiceProvider)
          .signUp(email: email.trim(), password: password.trim());
      if (user == null) {
        return 'Ro‘yxatdan o‘tishda xatolik';
      }
      state = _fromUser(user);
      return null;
    } on StateError catch (e) {
      if (e.message.toLowerCase().contains('allaqachon')) {
        return 'Bu email allaqachon mavjud';
      }
      return e.message;
    } catch (_) {
      return 'Xatolik yuz berdi. Qayta urinib ko‘ring';
    }
  }

  Future<void> logout() async {
    await ref.read(authServiceProvider).signOut();
    state = const AuthState(
      isLoggedIn: false,
      name: 'Mehmon',
      userId: null,
      email: null,
    );
  }
}
