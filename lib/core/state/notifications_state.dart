import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/notification_models.dart';
import '../di/providers.dart';
import 'auth_controller.dart';

final notificationsFeedProvider = StreamProvider<List<AppNotificationItem>>((ref) {
  final auth = ref.watch(authControllerProvider);
  final userId = auth.userId ?? '';
  return ref.read(notificationsRepositoryProvider).watchFeed(userId: userId);
});

/// Unread items (`viewed == false`) for bell badge / indicators.
final unreadNotificationsCountProvider = Provider<int>((ref) {
  final feed = ref.watch(notificationsFeedProvider);
  return feed.when(
    data: (items) => items.where((e) => !e.viewed).length,
    loading: () => 0,
    error: (_, _) => 0,
  );
});
