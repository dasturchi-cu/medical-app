import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/course_models.dart';

class CatalogService {
  static List<Course> _courses = const [];
  static const Duration _requestTimeout = Duration(seconds: 8);

  static List<Course> get courses => _courses;

  static Future<void> bootstrap() async {
    final baseUrl = getApiBaseUrl();
    if (baseUrl.isEmpty) return;
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/api/v1/mobile/courses'))
          .timeout(_requestTimeout);
      if (response.statusCode < 200 || response.statusCode >= 300) return;
      final body = jsonDecode(response.body);
      if (body is! Map<String, dynamic>) return;
      final raw = body['items'];
      if (raw is! List) return;
      _courses = raw
          .whereType<Map<String, dynamic>>()
          .map(_toCourse)
          .toList(growable: false);
    } catch (_) {}
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
