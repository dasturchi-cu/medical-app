import 'package:shared_preferences/shared_preferences.dart';

/// Saqlangan video tezligi (keyingi darslar uchun).
class VideoPlaybackPrefs {
  VideoPlaybackPrefs._();

  static const _speedKey = 'video_playback_speed_v1';

  static Future<double> loadSpeed() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final v = prefs.getDouble(_speedKey);
      if (v == null) return 1.0;
      if (_allowedSpeeds.contains(v)) return v;
      return 1.0;
    } catch (_) {
      return 1.0;
    }
  }

  static Future<void> saveSpeed(double speed) async {
    if (!_allowedSpeeds.contains(speed)) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_speedKey, speed);
    } catch (_) {}
  }

  static const List<double> allowedSpeeds = [
    0.25,
    0.5,
    0.75,
    1.0,
    1.25,
    1.5,
    1.75,
    2.0,
  ];

  static final Set<double> _allowedSpeeds = allowedSpeeds.toSet();
}
