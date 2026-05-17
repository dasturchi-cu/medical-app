import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase/supabase.dart';

import '../models/notification_models.dart';
import 'notifications_repository.dart';

/// Bitta foydalanuvchi uchun yagona feed oqimi — Riverpod `invalidate` spamini oldini oladi.
class _NotificationFeedSession {
  _NotificationFeedSession({
    required this.repository,
    required this.userId,
    required this.pollInterval,
  });

  final HttpNotificationsRepository repository;
  final String userId;
  final Duration pollInterval;

  final StreamController<List<AppNotificationItem>> controller =
      StreamController<List<AppNotificationItem>>.broadcast();
  RealtimeChannel? channel;
  Timer? poller;
  Timer? publishDebounce;
  var disposed = false;
  var publishInFlight = false;
  var bootstrapped = false;
  List<AppNotificationItem>? lastFeed;

  Stream<List<AppNotificationItem>> get stream => controller.stream;

  Future<void> publishLatest({bool force = false}) async {
    if (disposed) return;
    if (publishInFlight && !force) return;
    publishInFlight = true;
    try {
      final feed = await repository.fetchFeed(userId: userId);
      if (disposed) return;
      lastFeed = feed;
      controller.add(feed);
    } catch (error, stackTrace) {
      if (!disposed) controller.addError(error, stackTrace);
    } finally {
      publishInFlight = false;
    }
  }

  void schedulePublishLatest({bool force = false}) {
    if (disposed) return;
    if (force) {
      publishDebounce?.cancel();
      unawaited(publishLatest(force: true));
      return;
    }
    publishDebounce?.cancel();
    publishDebounce = Timer(const Duration(milliseconds: 800), () {
      unawaited(publishLatest());
    });
  }

  void onRealtimeChange(PostgresChangePayload payload) {
    debugPrint('[realtime][notifications] ${payload.table} ${payload.eventType}');
    schedulePublishLatest();
  }

  Future<void> startRealtime() async {
    final client = repository.realtimeClient;
    if (client == null) return;

    channel = client
        .channel('app-notifications-$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'notification_deliveries',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: onRealtimeChange,
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'notifications',
          callback: onRealtimeChange,
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'notification_click_events',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: onRealtimeChange,
        );
    channel?.subscribe();
  }

  Future<void> bootstrap() async {
    if (bootstrapped || disposed) return;
    bootstrapped = true;
    await publishLatest(force: true);
    await startRealtime();
    poller = Timer.periodic(pollInterval, (_) => schedulePublishLatest());
  }

  void ensureStarted() {
    if (lastFeed != null && !controller.isClosed) {
      controller.add(lastFeed!);
    }
    unawaited(bootstrap());
  }

  Future<void> dispose() async {
    if (disposed) return;
    disposed = true;
    publishDebounce?.cancel();
    poller?.cancel();
    if (channel != null) {
      await repository.realtimeClient?.removeChannel(channel!);
    }
    await controller.close();
  }
}

class HttpNotificationsRepository implements NotificationsRepository {
  HttpNotificationsRepository({
    required this.baseUrl,
    this.client,
    this.realtimeClient,
  });

  final String baseUrl;
  final http.Client? client;
  final SupabaseClient? realtimeClient;

  static final Map<String, _NotificationFeedSession> _feedSessions = {};

  http.Client get _client => client ?? http.Client();

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

  @override
  Future<List<AppNotificationItem>> fetchFeed({required String userId}) async {
    if (baseUrl.isEmpty || userId.isEmpty) {
      throw Exception('API manzili yoki userId topilmadi (notifications).');
    }
    final uri = Uri.parse('$baseUrl/api/v1/notifications/feed?user_id=$userId&limit=100');
    debugPrint('[API][notifications.feed][request] $uri');
    final response = await _client.get(uri);
    debugPrint('[API][notifications.feed][response] status=${response.statusCode}');
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        _errorMessage('Bildirishnomalarni olishda xatolik (${response.statusCode}).', response.body),
      );
    }

    final body = jsonDecode(response.body);
    if (body is! Map<String, dynamic>) {
      throw Exception('Bildirishnoma javobi JSON emas.');
    }
    final rawItems = body['items'];
    if (rawItems is! List) {
      throw Exception("Bildirishnoma ro'yxati topilmadi.");
    }

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
    if (baseUrl.isEmpty || userId.isEmpty || notificationId.isEmpty) {
      throw Exception('API manzili yoki identifikatorlar topilmadi (notifications.view).');
    }
    final uri = Uri.parse('$baseUrl/api/v1/notifications/$notificationId/view');
    debugPrint('[API][notifications.view][request] $uri userId=$userId');
    final response = await _client.post(
      uri,
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({'user_id': userId}),
    );
    debugPrint('[API][notifications.view][response] status=${response.statusCode}');
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        _errorMessage('Bildirishnomani ko‘rildi belgilashda xatolik (${response.statusCode}).', response.body),
      );
    }
    requestFeedRefresh(userId: userId);
  }

  @override
  Future<void> markClicked({
    required String userId,
    required String notificationId,
  }) async {
    if (baseUrl.isEmpty || userId.isEmpty || notificationId.isEmpty) {
      throw Exception('API manzili yoki identifikatorlar topilmadi (notifications.click).');
    }
    final uri = Uri.parse('$baseUrl/api/v1/notifications/$notificationId/click');
    debugPrint('[API][notifications.click][request] $uri userId=$userId');
    final response = await _client.post(
      uri,
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({'user_id': userId}),
    );
    debugPrint('[API][notifications.click][response] status=${response.statusCode}');
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        _errorMessage('Bildirishnomani click belgilashda xatolik (${response.statusCode}).', response.body),
      );
    }
  }

  _NotificationFeedSession _sessionFor(String userId, Duration pollInterval) {
    return _feedSessions.putIfAbsent(
      userId,
      () => _NotificationFeedSession(
        repository: this,
        userId: userId,
        pollInterval: pollInterval,
      ),
    );
  }

  @override
  Stream<List<AppNotificationItem>> watchFeed({
    required String userId,
    Duration pollInterval = const Duration(seconds: 90),
  }) {
    if (userId.isEmpty) return Stream.value(const []);

    final session = _sessionFor(userId, pollInterval);
    session.ensureStarted();
    return session.stream;
  }

  @override
  void requestFeedRefresh({required String userId}) {
    if (userId.isEmpty) return;
    final session = _feedSessions[userId];
    if (session == null) return;
    session.schedulePublishLatest(force: true);
  }

  static void clearFeedSession(String userId) {
    final session = _feedSessions.remove(userId);
    if (session != null) {
      unawaited(session.dispose());
    }
  }
}
