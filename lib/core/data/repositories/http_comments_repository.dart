import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase/supabase.dart';

import '../../services/memory_ttl_cache.dart';
import '../../services/mobile_api_auth.dart';
import '../models/comment_models.dart';
import 'comments_repository.dart';

class HttpCommentsRepository implements CommentsRepository {
  HttpCommentsRepository({required this.baseUrl, this.client, this.realtimeClient});

  final String baseUrl;
  final http.Client? client;
  final SupabaseClient? realtimeClient;

  http.Client get _client => client ?? http.Client();
  static const _timeout = Duration(seconds: 8);
  static final MemoryTtlCache<List<AppCommentItem>> _cache = MemoryTtlCache<List<AppCommentItem>>(
    ttl: const Duration(minutes: 2),
  );

  static String _cacheKey(String courseKey, String userId) => '$courseKey|${userId.trim()}';

  String _errorMessage(String fallback, String body) {
    try {
      final parsed = jsonDecode(body);
      if (parsed is Map<String, dynamic>) {
        final detail = parsed['detail']?.toString().trim() ?? '';
        if (detail.isNotEmpty) return detail;
      }
    } catch (_) {}
    return fallback;
  }

  Future<List<AppCommentItem>> _fetchCommentsNetwork({
    required String courseKey,
    required String userId,
  }) async {
    if (baseUrl.isEmpty || courseKey.isEmpty) return const [];
    final hasUser = userId.trim().isNotEmpty;
    final uri = Uri.parse(
      hasUser
          ? '$baseUrl/api/v1/comments?course_key=$courseKey&user_id=$userId'
          : '$baseUrl/api/v1/comments?course_key=$courseKey',
    );
    debugPrint('[API][comments.fetch][request] courseKey=$courseKey userId=${hasUser ? userId : "-"}');
    final response = await _client.get(uri).timeout(_timeout);
    debugPrint('[API][comments.fetch][response] status=${response.statusCode}');
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(_errorMessage('Izohlarni olishda xatolik (${response.statusCode}).', response.body));
    }
    final body = jsonDecode(response.body);
    if (body is! Map<String, dynamic>) {
      throw Exception("Izohlar javobi noto'g'ri.");
    }
    final raw = body['items'];
    if (raw is! List) {
      throw Exception("Izohlar ro'yxati topilmadi.");
    }
    return raw
        .whereType<Map<String, dynamic>>()
        .map(AppCommentItem.fromJson)
        .toList(growable: false);
  }

  @override
  Future<List<AppCommentItem>> fetchComments({
    required String courseKey,
    required String userId,
    bool forceRefresh = false,
  }) async {
    final key = _cacheKey(courseKey, userId);
    return _cache.getOrFetch(
      key,
      () => _fetchCommentsNetwork(courseKey: courseKey, userId: userId),
      forceRefresh: forceRefresh,
    );
  }

  void _patchCachedLike({
    required String courseKey,
    required String userId,
    required String commentId,
    required bool likedByMe,
    required int likesCount,
  }) {
    final key = _cacheKey(courseKey, userId);
    final current = _cache.peek(key);
    if (current == null) return;
    _cache.put(
      key,
      current
          .map(
            (item) => item.id == commentId
                ? item.copyWith(likedByMe: likedByMe, likesCount: likesCount)
                : item,
          )
          .toList(growable: false),
    );
  }

  void _invalidateCourseComments(String courseKey) {
    _cache.invalidatePrefix('$courseKey|');
  }

  @override
  Future<void> addComment({
    required String courseKey,
    required String userId,
    required String authorName,
    required String text,
  }) async {
    if (baseUrl.isEmpty || courseKey.isEmpty || userId.isEmpty) return;
    debugPrint('[API][comments.add][request] courseKey=$courseKey userId=$userId');
    final uri = Uri.parse('$baseUrl/api/v1/comments');
    final response = await _client
        .post(
      uri,
      headers: MobileApiAuth.headers(extra: const {'Content-Type': 'application/json'}),
      body: jsonEncode(MobileApiAuth.withSession({
        'course_key': courseKey,
        'user_id': userId,
        'author_name': authorName,
        'text': text,
      })),
    )
        .timeout(_timeout);
    debugPrint('[API][comments.add][response] status=${response.statusCode}');
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(_errorMessage('Izoh yuborilmadi (${response.statusCode}).', response.body));
    }
    _invalidateCourseComments(courseKey);
  }

  @override
  Future<void> addReply({
    required String commentId,
    required String userId,
    required String authorName,
    required String text,
  }) async {
    if (baseUrl.isEmpty || commentId.isEmpty || userId.isEmpty) return;
    debugPrint('[API][comments.reply][request] commentId=$commentId userId=$userId');
    final uri = Uri.parse('$baseUrl/api/v1/comments/$commentId/reply');
    final response = await _client
        .post(
      uri,
      headers: MobileApiAuth.headers(extra: const {'Content-Type': 'application/json'}),
      body: jsonEncode(MobileApiAuth.withSession({
        'user_id': userId,
        'author_name': authorName,
        'text': text,
      })),
    )
        .timeout(_timeout);
    debugPrint('[API][comments.reply][response] status=${response.statusCode}');
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(_errorMessage('Javob yuborilmadi (${response.statusCode}).', response.body));
    }
  }

  @override
  Future<void> toggleLike({
    required String commentId,
    required String userId,
    String courseKey = '',
    bool likedByMe = false,
    int likesCount = 0,
  }) async {
    if (baseUrl.isEmpty || commentId.isEmpty || userId.isEmpty) return;
    _patchCachedLike(
      courseKey: courseKey,
      userId: userId,
      commentId: commentId,
      likedByMe: likedByMe,
      likesCount: likesCount,
    );
    debugPrint('[API][comments.like][request] commentId=$commentId userId=$userId');
    final uri = Uri.parse('$baseUrl/api/v1/comments/$commentId/like');
    final response = await _client
        .post(
      uri,
      headers: MobileApiAuth.headers(extra: const {'Content-Type': 'application/json'}),
      body: jsonEncode(MobileApiAuth.withSession({'user_id': userId})),
    )
        .timeout(_timeout);
    debugPrint('[API][comments.like][response] status=${response.statusCode}');
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(_errorMessage('Like amalida xatolik (${response.statusCode}).', response.body));
    }

  }

  @override
  Stream<List<AppCommentItem>> watchComments({
    required String courseKey,
    required String userId,
    Duration pollInterval = const Duration(seconds: 15),
  }) {
    final controller = StreamController<List<AppCommentItem>>();
    RealtimeChannel? channel;
    Timer? poller;
    var disposed = false;
    List<AppCommentItem> last = const [];

    Future<void> push({bool forceRefresh = false}) async {
      if (disposed) return;
      try {
        last = await fetchComments(
          courseKey: courseKey,
          userId: userId,
          forceRefresh: forceRefresh,
        );
      } catch (_) {
        final cached = _cache.peek(_cacheKey(courseKey, userId));
        if (cached != null) last = cached;
      }
      if (!disposed) controller.add(last);
    }

    Future<void> boot() async {
      final cached = _cache.peek(_cacheKey(courseKey, userId));
      if (cached != null && cached.isNotEmpty) {
        last = cached;
        controller.add(last);
      }
      await push();
      final client = realtimeClient;
      if (client != null) {
        channel = client
            .channel('app-comments-$courseKey')
            .onPostgresChanges(
              event: PostgresChangeEvent.all,
              schema: 'public',
              table: 'app_comments',
              filter: PostgresChangeFilter(
                type: PostgresChangeFilterType.eq,
                column: 'course_key',
                value: courseKey,
              ),
              callback: (_) => unawaited(push(forceRefresh: true)),
            )
            .onPostgresChanges(
              event: PostgresChangeEvent.all,
              schema: 'public',
              table: 'app_comment_likes',
              callback: (_) {},
            )
            .subscribe();
      }
      final pollMs = client != null ? pollInterval.inMilliseconds * 3 : pollInterval.inMilliseconds;
      poller = Timer.periodic(Duration(milliseconds: pollMs.clamp(120000, 300000)), (_) => unawaited(push()));
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
