import '../../services/media_url_resolver.dart';

class AppNotificationItem {
  const AppNotificationItem({
    required this.id,
    required this.title,
    required this.message,
    required this.imageUrl,
    required this.type,
    required this.route,
    required this.data,
    required this.sentAt,
    required this.viewed,
  });

  final String id;
  final String title;
  final String message;
  final String imageUrl;
  final String type;
  final String route;
  final Map<String, String> data;
  final DateTime sentAt;
  final bool viewed;

  factory AppNotificationItem.fromJson(Map<String, dynamic> json) {
    final rawSentAt = (json['sent_at'] ?? '').toString();
    return AppNotificationItem(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      message: (json['message'] ?? '').toString(),
      imageUrl: MediaUrlResolver.resolveStoredMediaUrl((json['image_url'] ?? '').toString()),
      type: (json['type'] ?? 'generic').toString(),
      route: (json['route'] ?? '/notifications').toString(),
      data: _parseDataMap(json['data']),
      sentAt: DateTime.tryParse(rawSentAt)?.toLocal() ?? DateTime.now(),
      viewed: json['viewed'] == true,
    );
  }

  static Map<String, String> _parseDataMap(dynamic value) {
    if (value is! Map) return const {};
    final out = <String, String>{};
    value.forEach((key, val) {
      final k = key.toString().trim();
      if (k.isEmpty) return;
      out[k] = val?.toString() ?? '';
    });
    return out;
  }
}
