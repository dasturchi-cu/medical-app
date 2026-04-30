import 'dart:io';

String getApiBaseUrl() {
  const fromEnv = String.fromEnvironment('API_BASE_URL', defaultValue: '');
  if (fromEnv.isNotEmpty) return _normalizeBaseUrl(fromEnv);
  // Android emulator usually reaches host by 10.0.2.2,
  // while real phone needs LAN IP (same Wi-Fi).
  if (Platform.isAndroid) {
    const lanDefault = String.fromEnvironment(
      'API_BASE_URL_LAN',
      defaultValue: 'http://192.168.100.168:8000',
    );
    return _normalizeBaseUrl(lanDefault);
  }
  return _normalizeBaseUrl('http://localhost:8000');
}

String _normalizeBaseUrl(String input) {
  var value = input.trim();
  if (value.isEmpty) return value;

  // Common typo: missing "om" in onrender.com
  value = value.replaceAll('.onrender.c/', '.onrender.com/');
  value = value.replaceAll('.onrender.c', '.onrender.com');

  if (!value.startsWith('http://') && !value.startsWith('https://')) {
    value = 'https://$value';
  }

  return value.replaceAll(RegExp(r'/+$'), '');
}
