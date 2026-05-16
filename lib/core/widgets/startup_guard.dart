import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../theme/design_system.dart';

class StartupGuard extends StatefulWidget {
  const StartupGuard({super.key, required this.child});

  final Widget child;

  @override
  State<StartupGuard> createState() => _StartupGuardState();
}

class _StartupGuardState extends State<StartupGuard> {
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<dynamic>? _subscription;
  bool _hasInternet = true;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    await _checkInternet();
    await _requestNotificationPermission();
    _subscription = _connectivity.onConnectivityChanged.listen((result) {
      final next = _hasNetwork(result);
      if (!mounted || next == _hasInternet) return;
      setState(() => _hasInternet = next);
    });
  }

  bool _hasNetwork(dynamic result) {
    if (result is List<ConnectivityResult>) {
      return !result.contains(ConnectivityResult.none);
    }
    if (result is ConnectivityResult) {
      return result != ConnectivityResult.none;
    }
    return true;
  }

  Future<void> _checkInternet() async {
    final result = await _connectivity.checkConnectivity();
    if (!mounted) return;
    setState(() => _hasInternet = _hasNetwork(result));
  }

  Future<void> _requestNotificationPermission() async {
    if (!Platform.isAndroid && !Platform.isIOS) return;
    final status = await Permission.notification.status;
    if (status.isGranted || status.isPermanentlyDenied) return;
    await Permission.notification.request();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      clipBehavior: Clip.none,
      children: [
        widget.child,
        if (!_hasInternet)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Material(
              elevation: 6,
              color: const Color(0xFFC2410C),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.s12,
                    AppSpacing.s8,
                    AppSpacing.s8,
                    AppSpacing.s8,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.wifi_off_rounded, color: Colors.white, size: 22),
                      const SizedBox(width: AppSpacing.s8),
                      Expanded(
                        child: Text(
                          "Internet ulanmagan. Onlayn kurslar, sinxronlash va yangilanishlar ishlamaydi — Wi‑Fi yoki mobil tarmoqni yoqing.",
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                height: 1.35,
                              ),
                        ),
                      ),
                      TextButton(
                        onPressed: _checkInternet,
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          minimumSize: const Size(0, 0),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text("Tekshirish"),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
