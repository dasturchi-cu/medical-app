import 'package:flutter/material.dart';

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final items = const <({String title, String message, String time, String imageUrl})>[
      (
        title: 'Yangi kurs qo‘shildi',
        message: 'Nevrologiyada yangi diagnostika kursi kanalga joylandi.',
        time: 'Bugun, 21:40',
        imageUrl: 'https://picsum.photos/seed/notif-neuro-1/320/180',
      ),
      (
        title: 'Chegirma e’loni',
        message: 'EEG kursi uchun 20% chegirma faqat shu hafta amal qiladi.',
        time: 'Bugun, 18:10',
        imageUrl: 'https://picsum.photos/seed/notif-neuro-2/320/180',
      ),
      (
        title: 'Yangilik',
        message: 'Kurslar bo‘limida yangi video darslar yuklandi.',
        time: 'Kecha, 13:22',
        imageUrl: 'https://picsum.photos/seed/notif-neuro-3/320/180',
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Notificationlar')),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        itemCount: items.length,
        separatorBuilder: (context, index) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final item = items[index];
          return Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(
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
                        Text(
                          item.title,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        Text(item.message),
                        const SizedBox(height: 6),
                        Text(
                          item.time,
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
