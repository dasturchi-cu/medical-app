import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';
import '../http_request_timeouts.dart';
import '../models/course_models.dart';
import 'home_feeds_disk_cache.dart';

String _fallbackInstructor() => 'Umidjon Mukarramov';

class CatalogService {
  static const _prefsKey = 'catalog_courses_json_v1';
  static List<Course> _courses = const [];
  static Future<void>? _bootstrapInFlight;
  /// Faqat muvaffaqiyatli tarmoq javobidan keyin — disk keshi TTL ni bloklamasligi uchun.
  static DateTime? _lastNetworkLoadedAt;
  static DateTime? _lastBootstrapAttemptAt;
  static const Duration _cacheTtl = Duration(minutes: 5);
  static bool _hydratedFromDisk = false;
  static bool _homeBundleUnsupported = false;
  static Future<void>? _detailsRefreshInFlight;
  /// Katalog yuklangach UI qayta chizilsin (`HomePage` va boshqalar tinglaydi).
  static final ValueNotifier<int> catalogRevision = ValueNotifier<int>(0);

  static bool get isRefreshingDetails => _detailsRefreshInFlight != null;

  /// True faqat kurslarda section.lessons bo‘lib, video-meta (duration) ham bor holat.
  static bool get hasLessonDetails => _catalogHasLessonDetails(_courses);

  /// Last bootstrap error message (non-null if the last fetch failed or returned no courses).
  static String? lastLoadError;

  /// True after a successful fetch with a parseable `items` list (may be empty).
  static bool lastLoadOk = false;
  static bool get isLoading => _bootstrapInFlight != null;
  static bool get isLoadingStuck =>
      _bootstrapInFlight != null &&
      _lastBootstrapAttemptAt != null &&
      DateTime.now().difference(_lastBootstrapAttemptAt!) >
          const Duration(seconds: 12);

  static List<Course> get courses => _courses;

  /// Bosh sahifa statistikasi faqat kurs ro'yxati o'zgarganda qayta yuklansin.
  static String get courseListIdentityKey =>
      _courses.map((c) => c.id.trim()).where((id) => id.isNotEmpty).join('|');

  static bool _catalogHasLessonDetails(List<Course> courses) {
    for (final course in courses) {
      for (final section in course.sections) {
        if (section.lessons.isNotEmpty) return true;
      }
    }
    return false;
  }

  static Course _mergePreferringExistingLessons(Course incoming, Course existing) {
    final existingLessons = existing.sections.fold<int>(
      0,
      (sum, s) => sum + s.lessons.length,
    );
    final incomingLessons = incoming.sections.fold<int>(
      0,
      (sum, s) => sum + s.lessons.length,
    );
    if (existingLessons > incomingLessons) {
      return Course(
        id: existing.id,
        categoryId: existing.categoryId,
        titleUz: incoming.titleUz.isNotEmpty ? incoming.titleUz : existing.titleUz,
        titleRu: incoming.titleRu.isNotEmpty ? incoming.titleRu : existing.titleRu,
        titleEn: incoming.titleEn.isNotEmpty ? incoming.titleEn : existing.titleEn,
        authorUz: incoming.authorUz.isNotEmpty ? incoming.authorUz : existing.authorUz,
        imageUrl: incoming.imageUrl.isNotEmpty ? incoming.imageUrl : existing.imageUrl,
        priceUz: incoming.priceUz.isNotEmpty ? incoming.priceUz : existing.priceUz,
        progress: existing.progress,
        rating: incoming.rating > 0 ? incoming.rating : existing.rating,
        commentsCount:
            incoming.commentsCount > 0 ? incoming.commentsCount : existing.commentsCount,
        lessonCount: existing.lessonCount > 0
            ? existing.lessonCount
            : (incoming.lessonCount > 0 ? incoming.lessonCount : existingLessons),
        isPaid: incoming.isPaid,
        descriptionUz:
            incoming.descriptionUz.isNotEmpty ? incoming.descriptionUz : existing.descriptionUz,
        descriptionRu:
            incoming.descriptionRu.isNotEmpty ? incoming.descriptionRu : existing.descriptionRu,
        descriptionEn:
            incoming.descriptionEn.isNotEmpty ? incoming.descriptionEn : existing.descriptionEn,
        sections: existing.sections,
      );
    }
    return incoming;
  }

  static List<Course> _mergeCourseLists(List<Course> incoming, List<Course> existing) {
    if (existing.isEmpty) return incoming;
    final existingById = {for (final c in existing) c.id: c};
    return incoming
        .map((c) => _mergePreferringExistingLessons(c, existingById[c.id] ?? c))
        .toList(growable: false);
  }

  /// To'liq katalogni fon rejimida yangilash — UI ni darslarsiz "tez" javob bilan nolga tushirmaydi.
  static Future<void> refreshDetailedCatalog({
    int maxAttempts = 2,
    bool force = false,
  }) async {
    if (!_hydratedFromDisk && _courses.isEmpty) {
      await _hydrateFromDisk();
    }
    final now = DateTime.now();
    if (!force &&
        _catalogHasLessonDetails(_courses) &&
        _lastNetworkLoadedAt != null &&
        now.difference(_lastNetworkLoadedAt!) <= _cacheTtl) {
      return;
    }
    final baseUrl = getApiBaseUrl();
    if (baseUrl.isEmpty) return;
    await _refreshDetailedCatalogInBackground(
      baseUrl: baseUrl,
      maxAttempts: maxAttempts,
    );
  }

  /// Populate catalog from `GET /api/v1/home` → `courses` object (`items` list).
  /// Used when benchmarking single-request home bundle vs `/mobile/courses`.
  static void applyCoursesFromHomePayload(Map<String, dynamic>? coursesWrapper) {
    if (coursesWrapper == null) return;
    final raw = coursesWrapper['items'];
    if (raw is! List) return;
    try {
      final rawMaps = raw.whereType<Map<String, dynamic>>().toList(growable: false);
      final incoming = rawMaps.map(_toCourse).toList(growable: false);
      _courses = _mergeCourseLists(incoming, _courses);
      lastLoadOk = true;
      _lastNetworkLoadedAt = DateTime.now();
      lastLoadError = _courses.isEmpty ? 'Serverdan faol kurslar ro\'yxati bo\'sh.' : null;
      if (_courses.isNotEmpty) {
        unawaited(_persistToDisk(rawMaps));
      }
    } catch (e, st) {
      debugPrint('[CatalogService.applyCoursesFromHomePayload][error] $e\n$st');
      lastLoadOk = false;
      lastLoadError = e.toString();
    } finally {
      _bumpCatalogRevision();
    }
  }

  static void _bumpCatalogRevision() {
    catalogRevision.value++;
  }

  static Future<void> bootstrap({
    int maxAttempts = 3,
    bool forceRefresh = false,
  }) async {
    if (!_hydratedFromDisk && _courses.isEmpty) {
      await _hydrateFromDisk();
    }
    final now = DateTime.now();
    if (!forceRefresh &&
        _lastBootstrapAttemptAt != null &&
        now.difference(_lastBootstrapAttemptAt!) < const Duration(seconds: 20)) {
      return;
    }
    if (!forceRefresh &&
        _courses.isNotEmpty &&
        _lastBootstrapAttemptAt != null &&
        now.difference(_lastBootstrapAttemptAt!) < const Duration(minutes: 2)) {
      return;
    }
    if (!forceRefresh &&
        _lastNetworkLoadedAt != null &&
        now.difference(_lastNetworkLoadedAt!) <= _cacheTtl &&
        _courses.isNotEmpty) {
      return;
    }
    final inFlight = _bootstrapInFlight;
    if (inFlight != null) return inFlight;
    final future = _doBootstrap(maxAttempts: maxAttempts);
    _bootstrapInFlight = future;
    try {
      await future;
    } finally {
      if (identical(_bootstrapInFlight, future)) _bootstrapInFlight = null;
    }
  }

  /// Ilova ochilganda keshdan katalogni darhol ko‘rsatish (tarmoqsiz).
  static Future<void> preloadFromDisk() => _hydrateFromDisk();

  static Future<void> _hydrateFromDisk() async {
    _hydratedFromDisk = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw == null || raw.isEmpty) return;
      final body = jsonDecode(raw);
      if (body is! Map<String, dynamic>) return;
      final items = body['items'];
      if (items is! List || items.isEmpty) return;
      _courses = items
          .whereType<Map<String, dynamic>>()
          .map(_toCourse)
          .toList(growable: false);
      lastLoadOk = true;
      lastLoadError = null;
      // Diskdan muvaffaqiyatli ko'tarilganda ham qisqa muddatga "fresh" deb hisoblaymiz,
      // aks holda ilova ochilishida darhol network timeout urib ketadi.
      _lastNetworkLoadedAt = DateTime.now();
      _lastBootstrapAttemptAt = DateTime.now();
      _bumpCatalogRevision();
      debugPrint('[CatalogService] hydrated ${_courses.length} courses from disk');
    } catch (e, st) {
      debugPrint('[CatalogService._hydrateFromDisk][error] $e\n$st');
    }
  }

  static Future<void> _persistToDisk(List<Map<String, dynamic>> rawItems) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _prefsKey,
        jsonEncode({'items': rawItems}),
      );
    } catch (e, st) {
      debugPrint('[CatalogService._persistToDisk][error] $e\n$st');
    }
  }

  static Future<void> _doBootstrap({int maxAttempts = 3}) async {
    final hadCachedCourses = _courses.isNotEmpty;
    _lastBootstrapAttemptAt = DateTime.now();
    lastLoadError = null;
    if (!hadCachedCourses) {
      lastLoadOk = false;
    }
    try {
    final baseUrl = getApiBaseUrl();
    if (baseUrl.isEmpty) {
      lastLoadError = 'API_BASE_URL bo\'sh.';
      return;
    }

    // Darslari bor kesh mavjud bo'lsa, darslarsiz tez ro'yxat UI ni 0 ga tushirmasligi uchun o'tkazib yuboramiz.
    if (!_catalogHasLessonDetails(_courses)) {
      await _tryBootstrapFromCoursesList(baseUrl);
    }

    final attempts = maxAttempts < 1 ? 1 : maxAttempts;
    for (var i = 0; i < attempts; i++) {
      try {
        debugPrint('[API][mobile.courses][request] attempt=${i + 1} baseUrl=$baseUrl');
        final uri = Uri.parse('$baseUrl/api/v1/mobile/courses');
        final response = await http
            .get(uri, headers: const {'Cache-Control': 'no-cache'})
            .timeout(catalogBootstrapHttpTimeoutForBaseUrl(baseUrl));
        debugPrint('[API][mobile.courses][response] status=${response.statusCode}');
        if (response.statusCode < 200 || response.statusCode >= 300) {
          lastLoadError = 'Katalog HTTP ${response.statusCode}';
          final seeded = await _tryBootstrapFromHomeBundle(baseUrl);
          if (seeded) return;
          if (i == attempts - 1) return;
          await Future<void>.delayed(
            isLikelyLocalDevBaseUrl(baseUrl)
                ? Duration(milliseconds: 350 * (i + 1))
                : Duration(seconds: 2 + i),
          );
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
        final rawMaps = raw.whereType<Map<String, dynamic>>().toList(growable: false);
        final incoming = rawMaps.map(_toCourse).toList(growable: false);
        _courses = _mergeCourseLists(incoming, _courses);
        debugPrint('[API][mobile.courses][parsed] courses=${_courses.length}');
        lastLoadOk = true;
        _lastNetworkLoadedAt = DateTime.now();
        if (_courses.isEmpty) {
          lastLoadError = 'Serverdan faol kurslar ro\'yxati bo\'sh.';
        } else {
          lastLoadError = null;
          unawaited(_persistToDisk(rawMaps));
        }
        return;
      } catch (e) {
        lastLoadError = e is TimeoutException
            ? 'Server javob bermadi (vaqt tugadi). Hosting uxlagan bo\'lishi yoki tarmoq sekin — ilovani qayta ishga tushiring yoki Wi‑Fi tekshiring.'
            : e.toString();
        debugPrint('[API][mobile.courses][error] $e');
        final seeded = await _tryBootstrapFromHomeBundle(baseUrl);
        if (seeded) return;
        if (i == attempts - 1) {
          final slideSeeded = _seedFromSlidesFallback();
          if (slideSeeded) return;
          if (_courses.isNotEmpty) {
            lastLoadOk = true;
            lastLoadError = null;
          }
          return;
        }
        await Future<void>.delayed(
          isLikelyLocalDevBaseUrl(baseUrl)
              ? Duration(milliseconds: 350 * (i + 1))
              : Duration(seconds: 2 + i),
        );
      }
    }
    _seedFromSlidesFallback();
    } finally {
      _bumpCatalogRevision();
    }
  }

  static Future<bool> _tryBootstrapFromHomeBundle(String baseUrl) async {
    if (_homeBundleUnsupported) return false;
    try {
      final uri = Uri.parse('$baseUrl/api/v1/home');
      debugPrint('[API][home.bundle][request] $uri');
      final response = await http
          .get(uri, headers: const {'Cache-Control': 'no-cache'})
          .timeout(
            isLikelyLocalDevBaseUrl(baseUrl)
                ? const Duration(seconds: 6)
                : const Duration(seconds: 10),
          );
      debugPrint('[API][home.bundle][response] status=${response.statusCode}');
      if (response.statusCode == 404) {
        _homeBundleUnsupported = true;
        return false;
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return false;
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) return false;
      final coursesWrapper = decoded['courses'];
      if (coursesWrapper is! Map<String, dynamic>) return false;
      final raw = coursesWrapper['items'];
      if (raw is! List) return false;
      final rawMaps = raw.whereType<Map<String, dynamic>>().toList(growable: false);
      final incoming = rawMaps.map(_toCourse).toList(growable: false);
      _courses = _mergeCourseLists(incoming, _courses);
      lastLoadOk = true;
      _lastNetworkLoadedAt = DateTime.now();
      if (_courses.isEmpty) {
        lastLoadError = 'Serverdan faol kurslar ro\'yxati bo\'sh.';
      } else {
        lastLoadError = null;
        unawaited(_persistToDisk(rawMaps));
      }
      debugPrint('[API][home.bundle][courses.parsed] courses=${_courses.length}');
      return true;
    } catch (e) {
      debugPrint('[API][home.bundle][error] $e');
      return false;
    }
  }

  static Future<bool> _tryBootstrapFromCoursesList(String baseUrl) async {
    try {
      final uri = Uri.parse('$baseUrl/api/v1/courses?active_only=true');
      debugPrint('[API][courses.list][request] $uri');
      final response = await http
          .get(uri, headers: const {'Cache-Control': 'no-cache'})
          .timeout(apiListFetchTimeoutForBaseUrl(baseUrl));
      debugPrint('[API][courses.list][response] status=${response.statusCode}');
      if (response.statusCode < 200 || response.statusCode >= 300) return false;
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) return false;
      final raw = decoded['items'];
      if (raw is! List) return false;
      final rawMaps = raw.whereType<Map<String, dynamic>>().toList(growable: false);
      if (rawMaps.isEmpty) return false;

      final incoming = rawMaps.map(_toCourseFromCoursesListItem).toList(growable: false);
      if (_catalogHasLessonDetails(_courses)) {
        debugPrint('[API][courses.list][skip] detailed catalog already loaded');
        return false;
      }
      _courses = incoming;
      lastLoadOk = true;
      _lastNetworkLoadedAt = DateTime.now();
      lastLoadError = null;
      // Darslarsiz katalogni diskka yozmaymiz — aks holda ilovada video darslar yo'qoladi.
      _bumpCatalogRevision();
      debugPrint('[API][courses.list][parsed] courses=${_courses.length} (lessons pending full catalog)');
      return true;
    } catch (e) {
      debugPrint('[API][courses.list][error] $e');
      return false;
    }
  }

  static Future<void> _refreshDetailedCatalogInBackground({
    required String baseUrl,
    required int maxAttempts,
  }) {
    final existing = _detailsRefreshInFlight;
    if (existing != null) return existing;
    final run = () async {
      final attempts = maxAttempts < 1 ? 1 : maxAttempts;
      for (var i = 0; i < attempts; i++) {
        try {
          debugPrint('[API][mobile.courses][refresh.request] attempt=${i + 1} baseUrl=$baseUrl');
          final uri = Uri.parse('$baseUrl/api/v1/mobile/courses');
          final response = await http
              .get(uri, headers: const {'Cache-Control': 'no-cache'})
              .timeout(catalogBootstrapHttpTimeoutForBaseUrl(baseUrl));
          debugPrint('[API][mobile.courses][refresh.response] status=${response.statusCode}');
          if (response.statusCode < 200 || response.statusCode >= 300) {
            final seeded = await _tryBootstrapFromHomeBundle(baseUrl);
            if (seeded) {
              _bumpCatalogRevision();
              return;
            }
            if (i == attempts - 1) return;
            await Future<void>.delayed(
              isLikelyLocalDevBaseUrl(baseUrl)
                  ? Duration(milliseconds: 350 * (i + 1))
                  : Duration(seconds: 2 + i),
            );
            continue;
          }
          final body = jsonDecode(response.body);
          if (body is! Map<String, dynamic>) return;
          final raw = body['items'];
          if (raw is! List) return;
          final rawMaps = raw.whereType<Map<String, dynamic>>().toList(growable: false);
          final incoming = rawMaps.map(_toCourse).toList(growable: false);
          _courses = _mergeCourseLists(incoming, _courses);
          lastLoadOk = true;
          _lastNetworkLoadedAt = DateTime.now();
          lastLoadError = _courses.isEmpty ? 'Serverdan faol kurslar ro\'yxati bo\'sh.' : null;
          if (rawMaps.isNotEmpty) {
            unawaited(_persistToDisk(rawMaps));
          }
          _bumpCatalogRevision();
          debugPrint('[API][mobile.courses][refresh.parsed] courses=${_courses.length}');
          return;
        } catch (e) {
          debugPrint('[API][mobile.courses][refresh.error] $e');
          final seeded = await _tryBootstrapFromHomeBundle(baseUrl);
          if (seeded) {
            _bumpCatalogRevision();
            return;
          }
          if (i == attempts - 1) return;
          await Future<void>.delayed(
            isLikelyLocalDevBaseUrl(baseUrl)
                ? Duration(milliseconds: 350 * (i + 1))
                : Duration(seconds: 2 + i),
          );
        }
      }
    }();
    _detailsRefreshInFlight = run;
    run.whenComplete(() {
      if (identical(_detailsRefreshInFlight, run)) _detailsRefreshInFlight = null;
    });
    return run;
  }

  static bool _seedFromSlidesFallback() {
    if (_courses.isNotEmpty) return false;
    final slides = HomeFeedsDiskCache.slides;
    if (slides.isEmpty) return false;
    final seenIds = <String>{};
    final generated = <Course>[];
    for (final s in slides) {
      final cid = (s.courseId ?? '').trim();
      final title = s.title.trim();
      if (cid.isEmpty || title.isEmpty || !seenIds.add(cid)) continue;
      generated.add(
        Course(
          id: cid,
          categoryId: 'cat_nevralogiya',
          titleUz: title,
          titleRu: title,
          titleEn: title,
          authorUz: _fallbackInstructor(),
          imageUrl: s.imageUrl,
          priceUz: '0 so\'m',
          progress: 0,
          rating: 0,
          commentsCount: 0,
          lessonCount: 0,
          isPaid: true,
          descriptionUz: '',
          descriptionRu: '',
          descriptionEn: '',
          sections: const [],
        ),
      );
    }
    if (generated.isEmpty) return false;
    _courses = generated;
    lastLoadOk = true;
    lastLoadError = null;
    debugPrint('[CatalogService] seeded ${generated.length} courses from slides fallback');
    return true;
  }

  static Course _toCourse(Map<String, dynamic> json) {
    final sectionsRaw = json['sections'];
    final sections = sectionsRaw is List
        ? sectionsRaw.whereType<Map<String, dynamic>>().map(_toSection).toList(growable: false)
        : const <Section>[];
    final instructorName = (json['instructor_name'] ?? json['author'] ?? '').toString().trim();
    final coverImage = (json['cover_image_url'] ?? json['image_url'] ?? '').toString().trim();
    final parsedLessonCount = int.tryParse((json['lesson_count'] ?? '').toString());
    final lessonCount = parsedLessonCount ??
        sections.fold<int>(0, (sum, s) => sum + s.lessons.length);
    return Course(
      id: (json['id'] ?? '').toString(),
      categoryId: 'cat_nevralogiya',
      titleUz: (json['title_uz'] ?? '').toString(),
      titleRu: (json['title_ru'] ?? '').toString(),
      titleEn: (json['title_en'] ?? '').toString(),
      authorUz: instructorName.isEmpty ? _fallbackInstructor() : instructorName,
      imageUrl: coverImage,
      priceUz: '${(json['price_uzs'] ?? 0).toString()} so\'m',
      progress: 0,
      rating: double.tryParse((json['rating_avg'] ?? '0').toString()) ?? 0,
      commentsCount: int.tryParse((json['comments_count'] ?? '0').toString()) ?? 0,
      lessonCount: lessonCount,
      isPaid: true,
      descriptionUz: (json['description_uz'] ?? '').toString(),
      descriptionRu: (json['description_ru'] ?? '').toString(),
      descriptionEn: (json['description_en'] ?? '').toString(),
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

  static String _formatLessonDuration(int durationSec) {
    if (durationSec <= 0) return '';
    final hours = durationSec ~/ 3600;
    final minutes = (durationSec % 3600) ~/ 60;
    final seconds = durationSec % 60;
    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  static Lesson _toLesson(Map<String, dynamic> json) {
    final durationSec = int.tryParse((json['duration_sec'] ?? '0').toString()) ?? 0;
    final durationLabel = _formatLessonDuration(durationSec);
    return Lesson(
      id: (json['id'] ?? '').toString(),
      titleUz: (json['title'] ?? '').toString(),
      durationUz: durationLabel,
      isLocked: !(json['is_free'] == true),
      isCompleted: false,
      transcriptUz: '',
      slides: const [],
      videoUrl: (json['video_url'] ?? '').toString(),
    );
  }

  static Course _toCourseFromCoursesListItem(Map<String, dynamic> json) {
    final instructorName = (json['instructor_name'] ?? json['author'] ?? '').toString().trim();
    final coverImage = (json['cover_image_url'] ?? json['image_url'] ?? '').toString().trim();
    final priceUzs = int.tryParse((json['price_uzs'] ?? '0').toString()) ?? 0;
    final rating = double.tryParse((json['rating_avg'] ?? json['rating'] ?? '0').toString()) ?? 0;
    final commentsCount = int.tryParse((json['comments_count'] ?? '0').toString()) ?? 0;
    final lessonCount = int.tryParse((json['lesson_count'] ?? json['lessons_count'] ?? '0').toString()) ?? 0;
    return Course(
      id: (json['id'] ?? '').toString(),
      categoryId: 'cat_nevralogiya',
      titleUz: (json['title_uz'] ?? '').toString(),
      titleRu: (json['title_ru'] ?? '').toString(),
      titleEn: (json['title_en'] ?? '').toString(),
      authorUz: instructorName.isEmpty ? _fallbackInstructor() : instructorName,
      imageUrl: coverImage,
      priceUz: '$priceUzs so\'m',
      progress: 0,
      rating: rating,
      commentsCount: commentsCount,
      lessonCount: lessonCount,
      isPaid: priceUzs > 0,
      descriptionUz: (json['description_uz'] ?? '').toString(),
      descriptionRu: (json['description_ru'] ?? '').toString(),
      descriptionEn: (json['description_en'] ?? '').toString(),
      sections: const [],
    );
  }
}
