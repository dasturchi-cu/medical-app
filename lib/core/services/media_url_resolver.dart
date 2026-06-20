import '../config/api_config.dart';

/// Supabase Storage / nisbiy yo'llarni R2 yoki backend proxy URL ga aylantiradi.
class MediaUrlResolver {
  MediaUrlResolver._();

  static const _youtubeId = r'^[a-zA-Z0-9_-]{11}$';
  static const _r2PublicDefault = String.fromEnvironment(
    'R2_PUBLIC_BASE_URL',
    defaultValue: 'https://pub-f2e4edcbc94e4154bf7991b8b9ada00d.r2.dev',
  );

  static String get r2PublicBaseUrl {
    final value = _r2PublicDefault.trim().replaceAll(RegExp(r'/+$'), '');
    return value;
  }

  static String _clean(String raw) => raw.replaceAll(RegExp(r'[\s\n\r]+'), '').trim();

  static bool isYoutubeReference(String raw) {
    final value = _clean(raw);
    if (value.isEmpty) return false;
    if (RegExp(_youtubeId).hasMatch(value)) return true;
    final lower = value.toLowerCase();
    return lower.contains('youtube.com') ||
        lower.contains('youtu.be') ||
        lower.contains('youtube-nocookie.com');
  }

  static bool isStorageBacked(String raw) {
    final value = _clean(raw);
    if (value.isEmpty || isYoutubeReference(value)) return false;
    if (extractStorageKey(value) != null) return true;
    if (!value.startsWith('http://') && !value.startsWith('https://')) return true;
    final lower = value.toLowerCase();
    return lower.contains('supabase.co/storage/') || lower.contains('.r2.dev/');
  }

  /// `content-assets/...` yoki `lessons/foo.mp4` kabi R2 object key.
  static String? extractStorageKey(String raw) {
    final value = _clean(raw);
    if (value.isEmpty) return null;
    if (value.startsWith('data:')) return null;

    final supabase = RegExp(
      r'/storage/v1/object/(?:public|sign|authenticated)/([^/?#]+)/([^?#]+)',
      caseSensitive: false,
    ).firstMatch(value);
    if (supabase != null) {
      final bucket = supabase.group(1) ?? '';
      var objectPath = supabase.group(2) ?? '';
      objectPath = Uri.decodeComponent(objectPath);
      if (bucket == 'content-assets' && objectPath.startsWith('content-assets/')) {
        objectPath = objectPath.substring('content-assets/'.length);
      }
      return objectPath.isEmpty ? null : objectPath;
    }

    final r2 = RegExp(r'\.r2\.dev/([^?#]+)', caseSensitive: false).firstMatch(value);
    if (r2 != null) {
      final objectPath = Uri.decodeComponent(r2.group(1) ?? '');
      return objectPath.isEmpty ? null : objectPath;
    }

    if (!value.startsWith('http://') && !value.startsWith('https://')) {
      var path = value.startsWith('/') ? value.substring(1) : value;
      if (path.startsWith('content-assets/')) {
        path = path.substring('content-assets/'.length);
      }
      return path.isEmpty ? null : path;
    }
    return null;
  }

  static String _publicR2Url(String objectKey) {
    final key = objectKey.startsWith('/') ? objectKey.substring(1) : objectKey;
    return '${r2PublicBaseUrl}/$key';
  }

  static String _backendStreamUrl(String objectKey, {String? apiBaseUrl}) {
    final base = (apiBaseUrl ?? getApiBaseUrl()).replaceAll(RegExp(r'/+$'), '');
    final key = objectKey.startsWith('/') ? objectKey.substring(1) : objectKey;
    return '$base/api/v1/media/stream?path=${Uri.encodeComponent(key)}';
  }

  /// Backend `/media/stream` — R2 ishlamasa zaxira.
  static String backendStreamUrl(String objectKey, {String? apiBaseUrl}) =>
      _backendStreamUrl(objectKey, apiBaseUrl: apiBaseUrl);

  /// Katalogda saqlash uchun: YouTube o'zgarmaydi, storage URL R2 public ga.
  static String resolveStoredMediaUrl(String raw) {
    final value = _clean(raw);
    if (value.isEmpty || isYoutubeReference(value)) return value;
    final key = extractStorageKey(value);
    if (key != null) return _publicR2Url(key);
    return value;
  }

  /// Video player uchun: storage fayllar avval R2 public URL, keyin proxy.
  static String resolveVideoPlayUrl(String raw, {String? apiBaseUrl, bool useBackendProxy = false}) {
    final value = _clean(raw);
    if (value.isEmpty) return '';
    if (isYoutubeReference(value)) return value;
    final key = extractStorageKey(value);
    if (key != null) {
      if (useBackendProxy) {
        return _backendStreamUrl(key, apiBaseUrl: apiBaseUrl);
      }
      return _publicR2Url(key);
    }
    return value;
  }

  /// Rasmlar/PDF uchun.
  static String resolveFetchUrl(String raw, {String? apiBaseUrl}) {
    final value = _clean(raw);
    if (value.isEmpty) return '';
    if (value.startsWith('data:')) return value;
    final broken = value.indexOf('data:image');
    if (broken > 0 && value.contains('.r2.dev/')) {
      return value.substring(broken);
    }
    if (isYoutubeReference(value)) return value;
    final key = extractStorageKey(value);
    if (key != null) {
      return _publicR2Url(key);
    }
    if (!value.startsWith('http://') && !value.startsWith('https://')) {
      final baseInput = (apiBaseUrl ?? '').trim().isNotEmpty ? apiBaseUrl! : getApiBaseUrl();
      final base = baseInput.replaceAll(RegExp(r'/+$'), '');
      if (base.isEmpty) return value;
      final path = value.startsWith('/') ? value : '/$value';
      return '$base$path';
    }
    return value;
  }
}
