import 'dart:io';

String getApiBaseUrl() {
  const fromEnv = String.fromEnvironment('API_BASE_URL', defaultValue: '');
  if (fromEnv.isNotEmpty) return _normalizeBaseUrl(fromEnv);
  const defaultProd =
      String.fromEnvironment(
        'API_BASE_URL_DEFAULT',
        defaultValue: 'http://84.46.243.149',
      );
  // Android: avvalo `API_BASE_URL_LAN` (masalan lokal LAN), bo‘lmasa VPS production fallback.
  if (Platform.isAndroid) {
    const lanDefault = String.fromEnvironment('API_BASE_URL_LAN', defaultValue: '');
    final lan = lanDefault.trim();
    if (lan.isNotEmpty) return _normalizeBaseUrl(lan);
    // Lokal backend uchun run paytida `--dart-define=API_BASE_URL=http://10.0.2.2:8000` bering.
    return _normalizeBaseUrl(defaultProd);
  }
  return _normalizeBaseUrl(defaultProd);
}

String _normalizeBaseUrl(String input) {
  var value = input.trim();
  if (value.isEmpty) return value;

  // Common typo: missing "om" in onrender.com
  value = value.replaceAll('.onrender.c/', '.onrender.com/');
  value = value.replaceAll('.onrender.c', '.onrender.com');
  // Common typo: double "om" — onrender.comom (e.g. dart-define or env paste error)
  value = value.replaceAll('.onrender.comom', '.onrender.com');
  value = value.replaceAll('.onrender.comom/', '.onrender.com/');

  if (!value.startsWith('http://') && !value.startsWith('https://')) {
    value = 'https://$value';
  }

  return value.replaceAll(RegExp(r'/+$'), '');
}
