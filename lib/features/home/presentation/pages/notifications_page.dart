import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/providers.dart';
import '../../../../core/state/auth_controller.dart';
import '../../../../core/state/notifications_state.dart';

class NotificationsPage extends ConsumerWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final feedAsync = ref.watch(notificationsFeedProvider);
    final repo = ref.watch(notificationsRepositoryProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Notificationlar')),
      body: feedAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const Center(child: Text('Notificationlarni yuklashda xatolik.')),
        data: (items) {
          if (items.isEmpty) {
            return const Center(child: Text('Hozircha notification yo‘q.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            itemCount: items.length,
            separatorBuilder: (context, index) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final item = items[index];
              return InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () async {
                  final userId = auth.userId ?? '';
                  await repo.markViewed(userId: userId, notificationId: item.id);
                  ref.invalidate(notificationsFeedProvider);
                },
                child: Card(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: item.imageUrl.isEmpty
                              ? Container(
                                  width: 92,
                                  height: 72,
                                  color: const Color(0xFFE9F0FF),
                                  child: const Icon(
                                    Icons.image_outlined,
                                    color: Color(0xFF1E6BB8),
                                  ),
                                )
                              : Image.network(
                                  item.imageUrl,
                                  width: 92,
                                  height: 72,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      width: 92,
                                      height: 72,
                                      color: const Color(0xFFE9F0FF),
                                      child: const Icon(
                                        Icons.image_outlined,
                                        color: Color(0xFF1E6BB8),
                                      ),
                                    );
                                  },
                                ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      item.title,
                                      style: const TextStyle(fontWeight: FontWeight.w700),
                                    ),
                                  ),
                                  if (!item.viewed)
                                    const Icon(Icons.brightness_1, size: 10, color: Color(0xFF2563EB)),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(item.message),
                              const SizedBox(height: 6),
                              Text(
                                _formatDate(item.sentAt),
                                style: Theme.of(
                                  context,
                                ).textTheme.labelSmall?.copyWith(color: Colors.black54),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

String _formatDate(DateTime value) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(value.day)}.${two(value.month)} ${two(value.hour)}:${two(value.minute)}';
}
