import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase/supabase.dart';

import '../../http_request_timeouts.dart';
import '../../services/memory_ttl_cache.dart';
import '../models/lesson_slide_models.dart';
import 'lesson_slides_repository.dart';

class HttpLessonSlidesRepository implements LessonSlidesRepository {
  HttpLessonSlidesRepository({
    required this.baseUrl,
    this.client,
    this.realtimeClient,
  });

  final String baseUrl;
  final http.Client? client;
  final SupabaseClient? realtimeClient;

  http.Client get _client => client ?? http.Client();

  static final MemoryTtlCache<List<LessonSlideItem>> _cache =
      MemoryTtlCache<List<LessonSlideItem>>(ttl: const Duration(minutes: 5));

  Future<List<LessonSlideItem>> _fetchLessonSlidesNetwork({required String lessonId}) async {
    if (baseUrl.isEmpty || lessonId.isEmpty) return const [];
    final uri = Uri.parse('$baseUrl/api/v1/lesson-slides?lesson_id=$lessonId&active_only=true');
    try {
      final response =
          await _client.get(uri).timeout(apiListFetchTimeoutForBaseUrl(baseUrl));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final cached = _cache.peek(lessonId);
        if (cached != null && cached.isNotEmpty) return cached;
        return const [];
      }
      final body = jsonDecode(response.body);
      if (body is! Map<String, dynamic>) return const [];
      final raw = body['items'];
      if (raw is! List) return const [];
      return raw
          .whereType<Map<String, dynamic>>()
          .map(LessonSlideItem.fromJson)
          .toList(growable: false);
    } catch (e, st) {
      debugPrint('[API][lesson_slides.fetch][error] $e\n$st');
      final cached = _cache.peek(lessonId);
      if (cached != null && cached.isNotEmpty) return cached;
      return const [];
    }
  }

  @override
  Future<List<LessonSlideItem>> fetchLessonSlides({required String lessonId}) async {
    if (lessonId.isEmpty) return const [];
    return _cache.getOrFetch(lessonId, () => _fetchLessonSlidesNetwork(lessonId: lessonId));
  }

  @override
  Stream<List<LessonSlideItem>> watchLessonSlides({
    required String lessonId,
    Duration pollInterval = const Duration(seconds: 90),
  }) {
    if (lessonId.isEmpty) return Stream.value(const []);
    final controller = StreamController<List<LessonSlideItem>>();
    RealtimeChannel? channel;
    Timer? poller;
    var disposed = false;

    Future<void> push() async {
      if (disposed) return;
      _cache.invalidate(lessonId);
      controller.add(await fetchLessonSlides(lessonId: lessonId));
    }

    Future<void> boot() async {
      await push();
      final client = realtimeClient;
      if (client != null) {
        channel = client
            .channel('app-lesson-slides-$lessonId')
            .onPostgresChanges(
              event: PostgresChangeEvent.all,
              schema: 'public',
              table: 'lesson_slides',
              filter: PostgresChangeFilter(
                type: PostgresChangeFilterType.eq,
                column: 'lesson_id',
                value: lessonId,
              ),
              callback: (_) => unawaited(push()),
            )
            .subscribe();
      }
      final pollMs = client != null ? pollInterval.inMilliseconds * 3 : pollInterval.inMilliseconds;
      poller = Timer.periodic(
        Duration(milliseconds: pollMs.clamp(90000, 300000)),
        (_) => unawaited(push()),
      );
    }

    unawaited(boot());
    controller.onCancel = () async {
      disposed = true;
      poller?.cancel();
      if (channel != null) await realtimeClient?.removeChannel(channel!);
      await controller.close();
    };
    return controller.stream;
  }
}
