import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/providers.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/state/progress_controller.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(courseRepositoryProvider);
    final progress = ref.watch(progressControllerProvider);
    final myCount = repo.getCourses().where((c) {
      final p = progress.byCourseId[c.id];
      return (p?.enrolled ?? false) || c.progress > 0;
    }).length;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        children: [
          Text(
            'Profil',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 12),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE9F0FF),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Icon(Icons.person, color: Color(0xFF1E6BB8), size: 30),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Azizbek User',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w900,
                              ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$myCount ta kurs',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Colors.black54,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            margin: EdgeInsets.zero,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.menu_book_outlined),
                  title: const Text('Kurslarim'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.go(AppRoutes.myCourses),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.settings_outlined),
                  title: const Text('Sozlamalar'),
                  subtitle: const Text('Dummy'),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Sozlamalar: tez orada')),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

