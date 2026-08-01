import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

/// A stable, per-device anonymous identity for users who interact with
/// comments/likes/ratings without logging in.
///
/// Must stay per-device (not per-course, not a shared constant): every guest
/// used to be collapsed onto the same id, so one anonymous visitor's like or
/// rating showed up as another anonymous visitor's — including on different
/// physical devices — which is what made likes "randomly" toggle off and
/// ratings collide.
class GuestIdentity {
  GuestIdentity._();

  static const _prefsKey = 'guest_identity_id_v1';
  static String? _cached;

  static Future<void> ensureLoaded() async {
    if (_cached != null) return;
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_prefsKey);
    if (existing != null && existing.isNotEmpty) {
      _cached = existing;
      return;
    }
    final generated = 'guest_${_randomUuidV4()}';
    await prefs.setString(_prefsKey, generated);
    _cached = generated;
  }

  /// Synchronous accessor for use in widget `build()`. [ensureLoaded] is
  /// awaited during app startup before the first frame, so this is normally
  /// already populated; the fallback only covers a not-yet-loaded edge case
  /// (e.g. hot restart) and is intentionally not persisted from here.
  static String get id => _cached ?? (_cached = 'guest_${_randomUuidV4()}');

  static String _randomUuidV4() {
    final rand = Random.secure();
    final bytes = List<int>.generate(16, (_) => rand.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    String hex(int start, int end) =>
        bytes.sublist(start, end).map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex(0, 4)}-${hex(4, 6)}-${hex(6, 8)}-${hex(8, 10)}-${hex(10, 16)}';
  }
}
