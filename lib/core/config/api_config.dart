import 'dart:io';

String getApiBaseUrl() {
  const fromEnv = String.fromEnvironment('API_BASE_URL', defaultValue: '');
  if (fromEnv.isNotEmpty) return fromEnv;
  // Android emulator usually reaches host by 10.0.2.2,
  // while real phone needs LAN IP (same Wi-Fi).
  if (Platform.isAndroid) {
    const lanDefault = String.fromEnvironment(
      'API_BASE_URL_LAN',
      defaultValue: 'http://192.168.100.168:8000',
    );
    return lanDefault;
  }
  return 'http://localhost:8000';
}
