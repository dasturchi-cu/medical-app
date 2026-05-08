import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../di/providers.dart';
import '../services/auth_service.dart';
import 'purchase_controller.dart';

class AuthState {
  final bool isLoggedIn;
  final String name;
  final String? userId;
  final String? email;
  final bool isBlocked;
  final String? blockReason;

  const AuthState({
    required this.isLoggedIn,
    required this.name,
    required this.userId,
    required this.email,
    required this.isBlocked,
    required this.blockReason,
  });

  AuthState copyWith({
    bool? isLoggedIn,
    String? name,
    String? userId,
    String? email,
    bool? isBlocked,
    String? blockReason,
  }) {
    return AuthState(
      isLoggedIn: isLoggedIn ?? this.isLoggedIn,
      name: name ?? this.name,
      userId: userId ?? this.userId,
      email: email ?? this.email,
      isBlocked: isBlocked ?? this.isBlocked,
      blockReason: blockReason ?? this.blockReason,
    );
  }
}

final authControllerProvider =
    NotifierProvider<AuthController, AuthState>(AuthController.new);

class AuthController extends Notifier<AuthState> {
  Timer? _accessTimer;

  @override
  AuthState build() {
    final user = ref.watch(authServiceProvider).currentUser;
    if (user == null) {
      _accessTimer?.cancel();
      return const AuthState(
        isLoggedIn: false,
        name: 'Mehmon',
        userId: null,
        email: null,
        isBlocked: false,
        blockReason: null,
      );
    }
    Future.microtask(() {
      ref.read(purchaseControllerProvider.notifier).bindRealtime(user.id);
      ref.read(purchaseControllerProvider.notifier).syncFromBackend(user.id);
      _verifyUserAccess(user.id);
    });
    _startAccessTimer(user.id);
    return _fromUser(user);
  }

  void _startAccessTimer(String userId) {
    _accessTimer?.cancel();
    _accessTimer = Timer.periodic(const Duration(seconds: 12), (_) async {
      await ref.read(purchaseControllerProvider.notifier).syncFromBackend(userId);
      await _verifyUserAccess(userId);
    });
    ref.onDispose(() {
      _accessTimer?.cancel();
    });
  }

  Future<void> _verifyUserAccess(String userId) async {
    final status = await ref.read(authServiceProvider).checkUserAccess(userId);
    if (status == null) return;
    if (!status.isBlocked && status.sessionActive) return;
    await ref.read(authServiceProvider).signOut();
    ref.read(purchaseControllerProvider.notifier).clear();
    state = AuthState(
      isLoggedIn: false,
      name: 'Mehmon',
      userId: null,
      email: null,
      isBlocked: status.isBlocked,
      blockReason: status.isBlocked
          ? "Siz admin tomonidan bloklangansiz. Admin: @${status.adminContact}"
          : "Sessiya tugatildi. Qaytadan tizimga kiring.",
    );
  }

  AuthState _fromUser(LocalAuthUser user) {
    final guessedName = user.name.trim().isEmpty ? 'Ism yozmagansiz' : user.name;
    return AuthState(
      isLoggedIn: true,
      name: guessedName,
      userId: user.id,
      email: user.email,
      isBlocked: false,
      blockReason: null,
    );
  }

  Future<String?> login({
    required String phone,
    required String password,
    String? displayName,
  }) async {
    try {
      final user = await ref
          .read(authServiceProvider)
          .signIn(
            phone: phone.trim(),
            password: password.trim(),
            displayName: (displayName ?? '').trim(),
          );
      if (user == null) {
        return 'Telefon raqami noto‘g‘ri';
      }
      state = _fromUser(user);
      ref.read(purchaseControllerProvider.notifier).bindRealtime(user.id);
      await ref.read(purchaseControllerProvider.notifier).syncFromBackend(user.id);
      return null;
    } on AuthServiceError catch (error) {
      if (error.message.toLowerCase().contains('blok')) {
        state = const AuthState(
          isLoggedIn: false,
          name: 'Mehmon',
          userId: null,
          email: null,
          isBlocked: true,
          blockReason: null,
        ).copyWith(blockReason: error.message);
      }
      return error.message;
    } catch (_) {
      return 'Xatolik yuz berdi. Qayta urinib ko‘ring';
    }
  }

  Future<void> updateName(String name) async {
    final updated = await ref
        .read(authServiceProvider)
        .updateCurrentUserName(name);
    if (updated != null) {
      state = _fromUser(updated);
    }
  }

  Future<void> logout() async {
    _accessTimer?.cancel();
    await ref.read(authServiceProvider).signOut();
    ref.read(purchaseControllerProvider.notifier).clear();
    state = const AuthState(
      isLoggedIn: false,
      name: 'Mehmon',
      userId: null,
      email: null,
      isBlocked: false,
      blockReason: null,
    );
  }
}
