import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import 'media_url_resolver.dart';

/// Dars slaydlari (PDF/rasm) — qayta ochganda tarmoqsiz tez ko‘rinishi uchun kesh.
class LessonSlidesBytesCache {
  LessonSlidesBytesCache._();

  static const _dirName = 'remote_media_v1';

  static final Map<String, Uint8List> _memory = {};
  static Directory? _cacheDir;
  static bool _dirReady = false;

  static Future<void> ensureReady() async {
    if (_dirReady) return;
    try {
      final base = await getApplicationCacheDirectory();
      _cacheDir = Directory('${base.path}/$_dirName');
      if (!await _cacheDir!.exists()) {
        await _cacheDir!.create(recursive: true);
      }
      _dirReady = true;
    } catch (e, st) {
      debugPrint('[LessonSlidesBytesCache][init][error] $e\n$st');
    }
  }

  static String normalizeUrl(String raw, {required String apiBaseUrl}) {
    return MediaUrlResolver.resolveFetchUrl(raw, apiBaseUrl: apiBaseUrl);
  }

  static String _cacheKey(String normalizedUrl) {
    return sha256.convert(utf8.encode(normalizedUrl)).toString();
  }

  static Future<Uint8List?> _readDisk(String key) async {
    await ensureReady();
    final dir = _cacheDir;
    if (dir == null) return null;
    final file = File('${dir.path}/$key');
    if (!await file.exists()) return null;
    try {
      return await file.readAsBytes();
    } catch (_) {
      return null;
    }
  }

  static Future<void> _writeDisk(String key, Uint8List bytes) async {
    await ensureReady();
    final dir = _cacheDir;
    if (dir == null) return;
    try {
      await File('${dir.path}/$key').writeAsBytes(bytes, flush: true);
    } catch (e, st) {
      debugPrint('[LessonSlidesBytesCache][write][error] $e\n$st');
    }
  }

  /// [fetcher] — tarmoqdan yuklash (PDF uchun maxsus xato matnlari).
  static Future<Uint8List> loadBytes(
    String raw, {
    required Future<Uint8List> Function(String normalizedUrl) fetcher,
    String apiBaseUrl = '',
  }) async {
    final value = raw.trim();
    if (value.isEmpty) {
      throw Exception('Fayl manbasi bo‘sh.');
    }

    if (value.startsWith('data:')) {
      return _decodeDataUrl(value);
    }

    final normalized = normalizeUrl(value, apiBaseUrl: apiBaseUrl);
    final key = _cacheKey(normalized);

    final mem = _memory[key];
    if (mem != null && mem.isNotEmpty) {
      return mem;
    }

    final disk = await _readDisk(key);
    if (disk != null && disk.isNotEmpty) {
      _memory[key] = disk;
      debugPrint('[LessonSlidesBytesCache] disk hit ${key.substring(0, 8)}');
      return disk;
    }

    debugPrint('[LessonSlidesBytesCache] network ${key.substring(0, 8)}');
    final bytes = await fetcher(normalized);
    if (bytes.isNotEmpty) {
      _memory[key] = bytes;
      unawaited(_writeDisk(key, bytes));
    }
    return bytes;
  }

  static Uint8List _decodeDataUrl(String value) {
    final comma = value.indexOf(',');
    if (comma <= 0) {
      throw Exception("Fayl formati noto'g'ri.");
    }
    try {
      return base64Decode(
        value.substring(comma + 1).replaceAll(RegExp(r'\s'), ''),
      );
    } catch (_) {
      throw Exception("Faylni o'qib bo'lmadi.");
    }
  }

  static Future<Uint8List> fetchHttpBytes(String normalizedUrl) async {
    final uri = Uri.tryParse(normalizedUrl);
    if (uri == null) throw Exception("URL noto'g'ri.");
    final response = await http.get(uri);
    if (response.statusCode != 200) {
      throw Exception("Yuklanmadi (status: ${response.statusCode}).");
    }
    return response.bodyBytes;
  }

  static Future<Uint8List> fetchPdfBytes(String normalizedUrl) async {
    final uri = Uri.tryParse(normalizedUrl);
    if (uri == null) throw Exception("PDF URL noto'g'ri.");
    final response = await http.get(uri);
    if (response.statusCode != 200) {
      final body = response.body.toLowerCase();
      if (body.contains('bucket not found')) {
        throw Exception(
          "Supabase Storage: content-assets bucket/policy yo‘q. SQL Editor’da "
          "migrations/012_storage_content_assets_bucket.sql ni ishga tushiring; bucket public qiling.",
        );
      }
      throw Exception("PDF yuklanmadi (status: ${response.statusCode}).");
    }
    return response.bodyBytes;
  }
}
