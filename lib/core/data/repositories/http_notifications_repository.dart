import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/notification_models.dart';
import 'notifications_repository.dart';

class HttpNotificationsRepository implements NotificationsRepository {
  HttpNotificationsRepository({
    required this.baseUrl,
    this.client,
  });

  final String baseUrl;
  final http.Client? client;

  http.Client get _client => client ?? http.Client();

  @override
  Future<List<AppNotificationItem>> fetchFeed({required String userId}) async {
    if (baseUrl.isEmpty || userId.isEmpty) return const [];
    final uri = Uri.parse('$baseUrl/api/v1/notifications/feed?user_id=$userId&limit=100');
    final response = await _client.get(uri);
    if (response.statusCode < 200 || response.statusCode >= 300) return const [];

    final body = jsonDecode(response.body);
    if (body is! Map<String, dynamic>) return const [];
    final rawItems = body['items'];
    if (rawItems is! List) return const [];

    return rawItems
        .whereType<Map<String, dynamic>>()
        .map(AppNotificationItem.fromJson)
        .toList(growable: false);
  }

  @override
  Future<void> markViewed({
    required String userId,
    required String notificationId,
  }) async {
    if (baseUrl.isEmpty || userId.isEmpty || notificationId.isEmpty) return;
    final uri = Uri.parse('$baseUrl/api/v1/notifications/$notificationId/view');
    await _client.post(
      uri,
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({'user_id': userId}),
    );
  }

  @override
  Stream<List<AppNotificationItem>> watchFeed({
    required String userId,
    Duration pollInterval = const Duration(seconds: 8),
  }) async* {
    if (userId.isEmpty) {
      yield const [];
      return;
    }
    yield await fetchFeed(userId: userId);
    yield* Stream.periodic(pollInterval).asyncMap((_) => fetchFeed(userId: userId));
  }
}
