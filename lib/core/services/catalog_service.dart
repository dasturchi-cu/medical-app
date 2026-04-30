import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/course_models.dart';

class CatalogService {
  static List<Course> _courses = const [];
  static const Duration _requestTimeout = Duration(seconds: 12);

  /// Last bootstrap error message (non-null if the last fetch failed or returned no courses).
  static String? lastLoadError;

  /// True after a successful fetch with a parseable `items` list (may be empty).
  static bool lastLoadOk = false;

  static List<Course> get courses => _courses;

  static Future<void> bootstrap({int maxAttempts = 3}) async {
    lastLoadError = null;
    lastLoadOk = false;
    final baseUrl = getApiBaseUrl();
    if (baseUrl.isEmpty) {
      lastLoadError = 'API_BASE_URL bo\'sh.';
      return;
    }
    final attempts = maxAttempts < 1 ? 1 : maxAttempts;
    for (var i = 0; i < attempts; i++) {
      try {
        debugPrint('[API][mobile.courses][request] attempt=${i + 1} baseUrl=$baseUrl');
        final response = await http
            .get(Uri.parse('$baseUrl/api/v1/mobile/courses'))
            .timeout(_requestTimeout);
        debugPrint('[API][mobile.courses][response] status=${response.statusCode}');
        if (response.statusCode < 200 || response.statusCode >= 300) {
          lastLoadError = 'Katalog HTTP ${response.statusCode}';
          if (i == attempts - 1) return;
          await Future<void>.delayed(Duration(milliseconds: 800 * (i + 1)));
          continue;
        }
        final body = jsonDecode(response.body);
        if (body is! Map<String, dynamic>) {
          lastLoadError = 'Katalog javobi JSON emas.';
          return;
        }
        final raw = body['items'];
        if (raw is! List) {
          lastLoadError = 'Katalogda items ro\'yxati yo\'q.';
          return;
        }
        _courses = raw
            .whereType<Map<String, dynamic>>()
            .map(_toCourse)
            .toList(growable: false);
        debugPrint('[API][mobile.courses][parsed] courses=${_courses.length}');
        lastLoadOk = true;
        if (_courses.isEmpty) {
          lastLoadError = 'Serverdan faol kurslar ro\'yxati bo\'sh.';
        } else {
          lastLoadError = null;
        }
        return;
      } catch (e, st) {
        lastLoadError = e.toString();
        debugPrint('[API][mobile.courses][error] $e\n$st');
        if (i == attempts - 1) return;
        await Future<void>.delayed(Duration(milliseconds: 800 * (i + 1)));
      }
    }
  }

  static Course _toCourse(Map<String, dynamic> json) {
    final sectionsRaw = json['sections'];
    final sections = sectionsRaw is List
        ? sectionsRaw.whereType<Map<String, dynamic>>().map(_toSection).toList(growable: false)
        : const <Section>[];
    return Course(
      id: (json['id'] ?? '').toString(),
      categoryId: 'cat_nevralogiya',
      titleUz: (json['title_uz'] ?? '').toString(),
      authorUz: 'Neuroscience',
      imageUrl: (json['image_url'] ?? '').toString(),
      priceUz: '${(json['price_uzs'] ?? 0).toString()} so\'m',
      progress: 0,
      rating: double.tryParse((json['rating_avg'] ?? '0').toString()) ?? 0,
      isPaid: true,
      descriptionUz: (json['description_uz'] ?? '').toString(),
      sections: sections,
    );
  }

  static Section _toSection(Map<String, dynamic> json) {
    final lessonsRaw = json['lessons'];
    final lessons = lessonsRaw is List
        ? lessonsRaw.whereType<Map<String, dynamic>>().map(_toLesson).toList(growable: false)
        : const <Lesson>[];
    return Section(
      id: (json['id'] ?? '').toString(),
      titleUz: (json['title'] ?? '').toString(),
      durationUz: '${lessons.length * 10} daq',
      lessons: lessons,
    );
  }

  static Lesson _toLesson(Map<String, dynamic> json) {
    final durationSec = int.tryParse((json['duration_sec'] ?? '0').toString()) ?? 0;
    final minutes = (durationSec ~/ 60).toString().padLeft(2, '0');
    final seconds = (durationSec % 60).toString().padLeft(2, '0');
    return Lesson(
      id: (json['id'] ?? '').toString(),
      titleUz: (json['title'] ?? '').toString(),
      durationUz: '$minutes:$seconds',
      isLocked: !(json['is_free'] == true),
      isCompleted: false,
      transcriptUz: '',
      slides: const [],
      videoUrl: (json['video_url'] ?? '').toString(),
    );
  }
}
