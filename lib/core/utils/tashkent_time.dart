/// O‘zbekiston vaqti (UTC+5, DST yo‘q) — reyting kunlik chegarasi bilan mos.
class TashkentTime {
  TashkentTime._();

  static const _offset = Duration(hours: 5);

  static DateTime now() => DateTime.now().toUtc().add(_offset);

  /// `YYYY-MM-DD` — backend `Asia/Tashkent` bilan bir xil.
  static String dateKey([DateTime? at]) {
    final t = at ?? now();
    return '${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}';
  }

  /// Keyingi mahalliy 00:00 gacha qolgan vaqt.
  static Duration untilNextMidnight([DateTime? at]) {
    final t = at ?? now();
    final next = DateTime.utc(t.year, t.month, t.day + 1);
    return next.difference(t);
  }

  /// Device local date key `YYYY-MM-DD`.
  static String localDateKey([DateTime? at]) {
    final t = at ?? DateTime.now();
    return '${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}';
  }

  /// Device local next midnight delay.
  static Duration localUntilNextMidnight([DateTime? at]) {
    final t = at ?? DateTime.now();
    final next = DateTime(t.year, t.month, t.day + 1);
    return next.difference(t);
  }
}
