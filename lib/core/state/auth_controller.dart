import 'package:flutter_riverpod/flutter_riverpod.dart';

class AuthState {
  final bool isLoggedIn;
  final String name;

  const AuthState({
    required this.isLoggedIn,
    required this.name,
  });

  AuthState copyWith({
    bool? isLoggedIn,
    String? name,
  }) {
    return AuthState(
      isLoggedIn: isLoggedIn ?? this.isLoggedIn,
      name: name ?? this.name,
    );
  }
}

final authControllerProvider =
    NotifierProvider<AuthController, AuthState>(AuthController.new);

class AuthController extends Notifier<AuthState> {
  @override
  AuthState build() => const AuthState(isLoggedIn: false, name: 'Mehmon');

  void login({required String name}) {
    state = state.copyWith(isLoggedIn: true, name: name.trim().isEmpty ? 'Foydalanuvchi' : name);
  }

  void logout() {
    state = const AuthState(isLoggedIn: false, name: 'Mehmon');
  }
}

