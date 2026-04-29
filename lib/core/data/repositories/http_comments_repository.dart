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

  @override
  Future<List<AppCommentItem>> fetchComments({
    required String courseKey,
    required String userId,
  }) async {
    if (baseUrl.isEmpty || courseKey.isEmpty) return const [];
    final uri = Uri.parse(
      '$baseUrl/api/v1/comments?course_key=$courseKey&user_id=$userId',
    );
    final response = await _client.get(uri);
    if (response.statusCode < 200 || response.statusCode >= 300) return const [];
    final body = jsonDecode(response.body);
    if (body is! Map<String, dynamic>) return const [];
    final raw = body['items'];
    if (raw is! List) return const [];
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
    await _client.post(
      uri,
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({
        'course_key': courseKey,
        'user_id': userId,
        'author_name': authorName,
        'text': text,
      }),
    );
  }

  @override
  Future<void> toggleLike({
    required String commentId,
    required String userId,
  }) async {
    if (baseUrl.isEmpty || commentId.isEmpty || userId.isEmpty) return;
    final uri = Uri.parse('$baseUrl/api/v1/comments/$commentId/like');
    await _client.post(
      uri,
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({'user_id': userId}),
    );
  }

  @override
  Stream<List<AppCommentItem>> watchComments({
    required String courseKey,
    required String userId,
    Duration pollInterval = const Duration(seconds: 6),
  }) async* {
    yield await fetchComments(courseKey: courseKey, userId: userId);
    yield* Stream.periodic(
      pollInterval,
    ).asyncMap((_) => fetchComments(courseKey: courseKey, userId: userId));
  }
}
