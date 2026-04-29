import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/comment_models.dart';
import 'comments_repository.dart';

class HttpCommentsRepository implements CommentsRepository {
  HttpCommentsRepository({required this.baseUrl, this.client});

  final String baseUrl;
  final http.Client? client;

  http.Client get _client => client ?? http.Client();
  static const _timeout = Duration(seconds: 8);

  @override
  Future<List<AppCommentItem>> fetchComments({
    required String courseKey,
    required String userId,
  }) async {
    if (baseUrl.isEmpty || courseKey.isEmpty) return const [];
    final uri = Uri.parse(
      '$baseUrl/api/v1/comments?course_key=$courseKey&user_id=$userId',
    );
    final response = await _client.get(uri).timeout(_timeout);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Izohlarni olishda xatolik (${response.statusCode}).');
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
  Future<void> addComment({
    required String courseKey,
    required String userId,
    required String authorName,
    required String text,
  }) async {
    if (baseUrl.isEmpty || courseKey.isEmpty || userId.isEmpty) return;
    final uri = Uri.parse('$baseUrl/api/v1/comments');
    final response = await _client
        .post(
      uri,
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({
        'course_key': courseKey,
        'user_id': userId,
        'author_name': authorName,
        'text': text,
      }),
    )
        .timeout(_timeout);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Izoh yuborilmadi (${response.statusCode}).');
    }
  }

  @override
  Future<void> toggleLike({
    required String commentId,
    required String userId,
  }) async {
    if (baseUrl.isEmpty || commentId.isEmpty || userId.isEmpty) return;
    final uri = Uri.parse('$baseUrl/api/v1/comments/$commentId/like');
    final response = await _client
        .post(
      uri,
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({'user_id': userId}),
    )
        .timeout(_timeout);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Like amalida xatolik (${response.statusCode}).');
    }
  }

  @override
  Stream<List<AppCommentItem>> watchComments({
    required String courseKey,
    required String userId,
    Duration pollInterval = const Duration(seconds: 6),
  }) async* {
    List<AppCommentItem> last = const [];
    try {
      last = await fetchComments(courseKey: courseKey, userId: userId);
    } catch (_) {}
    yield last;

    await for (final _ in Stream.periodic(pollInterval)) {
      try {
        last = await fetchComments(courseKey: courseKey, userId: userId);
        yield last;
      } catch (_) {
        // Keep previously rendered comments instead of flashing empty list.
        yield last;
      }
    }
  }
}
