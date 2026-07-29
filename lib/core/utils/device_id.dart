import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';

class DeviceId {
  static Future<String> getStableDeviceId() async {
    try {
      final plugin = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final info = await plugin.androidInfo;
        return info.id.isNotEmpty ? info.id : 'android_device';
      }
      if (Platform.isIOS) {
        final info = await plugin.iosInfo;
        return info.identifierForVendor ?? 'ios_device';
      }
    } catch (_) {}
    return 'device_default';
  }
}


