import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/state/auth_controller.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  static const _phonePrefix = '+998 ';

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;
  bool _loggedInRedirectScheduled = false;

  @override
  void initState() {
    super.initState();
    _phoneController.text = _phonePrefix;
    _phoneController.selection = TextSelection.collapsed(
      offset: _phoneController.text.length,
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    final auth = ref.read(authControllerProvider.notifier);
    final name = _nameController.text;
    final phone = _phoneController.text;
    final password = _passwordController.text;
    final error = await auth.login(
      phone: phone,
      password: password,
      displayName: name,
    );

    if (!mounted) return;
    setState(() => _loading = false);

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    if (authState.isLoggedIn &&
        !authState.isBlocked &&
        !_loggedInRedirectScheduled) {
      _loggedInRedirectScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (context.canPop()) {
          context.pop();
        } else {
          context.go(AppRoutes.home);
        }
      });
    }
    if (!authState.isLoggedIn) {
      _loggedInRedirectScheduled = false;
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Kirish')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (authState.isBlocked && (authState.blockReason ?? '').isNotEmpty) ...[
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.red.withValues(alpha: 0.35)),
                        ),
                        child: Text(
                          authState.blockReason!,
                          style: const TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                    const Text(
                      'Xush kelibsiz',
                      style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 6),
                    const Text('Telefon raqam orqali kiring'),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _nameController,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Ism (ixtiyoriy)',
                        hintText: 'Masalan: Azizbek',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      inputFormatters: const [_UzPhoneFormatter()],
                      onTap: () {
                        final text = _phoneController.text;
                        if (_phoneController.selection.start < _phonePrefix.length) {
                          _phoneController.selection = TextSelection.collapsed(
                            offset: text.length,
                          );
                        }
                      },
                      decoration: const InputDecoration(
                        labelText: 'Telefon raqam',
                        hintText: '90 123 45 67',
                        prefixIcon: Icon(Icons.phone_outlined),
                      ),
                      validator: (value) {
                        final digits = (value ?? '').replaceAll(RegExp(r'\D'), '');
                        if (digits.length != 12 || !digits.startsWith('998')) {
                          return 'Telefon raqamni to‘g‘ri kiriting';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Parol',
                        prefixIcon: Icon(Icons.lock_outline),
                      ),
                      validator: (value) {
                        final v = value?.trim() ?? '';
                        if (v.length < 6) {
                          return 'Parol kamida 6 ta belgidan iborat bo‘lsin';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 48,
                      child: FilledButton(
                        onPressed: _loading ? null : _submit,
                        child: Text(_loading ? 'Kutilmoqda...' : 'Kirish'),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextButton(
                      onPressed: _loading
                          ? null
                          : () async {
                              await ref.read(authControllerProvider.notifier).logout();
                              if (!context.mounted) return;
                              if (context.canPop()) {
                                context.pop();
                              } else {
                                context.go(AppRoutes.home);
                              }
                            },
                      child: const Text('Mehmon sifatida davom etish'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _UzPhoneFormatter extends TextInputFormatter {
  const _UzPhoneFormatter();

  static const _prefix = '+998 ';

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) {
      return const TextEditingValue(
        text: _prefix,
        selection: TextSelection.collapsed(offset: _prefix.length),
      );
    }
    if (!digits.startsWith('998')) {
      digits = '998$digits';
    }
    var national = digits.length > 3 ? digits.substring(3) : '';
    if (national.length > 9) {
      national = national.substring(0, 9);
    }
    final formatted = _formatNational(national);
    final clampedBaseOffset = newValue.selection.baseOffset.clamp(
      0,
      newValue.text.length,
    );
    var digitsBeforeCursor = newValue.text
        .substring(0, clampedBaseOffset)
        .replaceAll(RegExp(r'\D'), '')
        .length;
    if (digitsBeforeCursor > 12) {
      digitsBeforeCursor = 12;
    }
    final offset = _offsetForDigitIndex(formatted, digitsBeforeCursor);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: offset),
    );
  }

  String _formatNational(String national) {
    if (national.isEmpty) {
      return _prefix;
    }
    final buffer = StringBuffer(_prefix);
    for (var i = 0; i < national.length; i++) {
      buffer.write(national[i]);
      if (i == 1 || i == 4 || i == 6) {
        buffer.write(' ');
      }
    }
    return buffer.toString();
  }

  int _offsetForDigitIndex(String formatted, int digitIndex) {
    if (digitIndex <= 0) return _prefix.length;
    var seenDigits = 0;
    for (var i = 0; i < formatted.length; i++) {
      final char = formatted[i];
      final isDigit = char.codeUnitAt(0) >= 48 && char.codeUnitAt(0) <= 57;
      if (!isDigit) continue;
      seenDigits++;
      if (seenDigits >= digitIndex) {
        return i + 1;
      }
    }
    return formatted.length;
  }
}
