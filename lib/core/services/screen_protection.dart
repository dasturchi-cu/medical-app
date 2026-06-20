import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_windowmanager/flutter_windowmanager.dart';

/// PDF/video kabi maxfiy kontentda skrinshot va ekran yozuvini cheklash.
class ScreenProtection {
  ScreenProtection._();

  static var _enabled = false;

  static Future<void> enable() async {
    if (_enabled || kIsWeb) return;
    if (!Platform.isAndroid) return;
    try {
      await FlutterWindowManager.addFlags(FlutterWindowManager.FLAG_SECURE);
      _enabled = true;
    } catch (e) {
      debugPrint('[screen_protection] enable failed: $e');
    }
  }

  static Future<void> disable() async {
    if (!_enabled || kIsWeb) return;
    if (!Platform.isAndroid) return;
    try {
      await FlutterWindowManager.clearFlags(FlutterWindowManager.FLAG_SECURE);
      _enabled = false;
    } catch (e) {
      debugPrint('[screen_protection] disable failed: $e');
    }
  }
}
