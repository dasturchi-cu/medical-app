import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/state/auth_controller.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit({required bool isRegister}) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    final auth = ref.read(authControllerProvider.notifier);
    final email = _emailController.text;
    final password = _passwordController.text;
    final error = isRegister
        ? await auth.register(email: email, password: password)
        : await auth.login(email: email, password: password);

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
                    const Text(
                      'Xush kelibsiz',
                      style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 6),
                    const Text('Kurs sotib olish uchun akkauntga kiring'),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                      validator: (value) {
                        final v = value?.trim() ?? '';
                        if (v.isEmpty || !v.contains('@')) {
                          return 'Email kiriting';
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
                        onPressed: _loading ? null : () => _submit(isRegister: false),
                        child: Text(_loading ? 'Kutilmoqda...' : 'Kirish'),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextButton(
                      onPressed: _loading ? null : () => _submit(isRegister: true),
                      child: const Text('Ro‘yxatdan o‘tish'),
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
