/// Admin panel: `title_uz` / `title_ru` / `title_en` — tanlangan til bo‘yicha.
String pickLocalizedText({
  required String uz,
  String? ru,
  String? en,
  required String langCode,
}) {
  final code = langCode.trim().toLowerCase();
  if (code == 'ru') {
    final r = (ru ?? '').trim();
    if (r.isNotEmpty) return r;
  }
  if (code == 'en') {
    final e = (en ?? '').trim();
    if (e.isNotEmpty) return e;
  }
  final u = uz.trim();
  return u.isNotEmpty ? u : (ru ?? en ?? '').trim();
}

String cleanCourseTitle(String? title) {
  final raw = (title ?? '').trim();
  if (raw.isEmpty) return '';
  return raw
      .replaceAll(RegExp(r'\/\s*talaba', caseSensitive: false), '')
      .replaceAll(RegExp(r'\b\d+\s*talaba\b', caseSensitive: false), '')
      .replaceAll(RegExp(r'\btalaba\b', caseSensitive: false), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}
