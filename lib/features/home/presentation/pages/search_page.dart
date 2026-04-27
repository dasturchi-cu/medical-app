import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/providers.dart';
import '../../../../core/mock/mock_data.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/utils/category_icons.dart';

final searchQueryProvider = StateProvider<String>((ref) => '');

class SearchPage extends ConsumerWidget {
  const SearchPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(courseRepositoryProvider);
    final query = ref.watch(searchQueryProvider).trim().toLowerCase();

    final courses = repo.getCourses().where((c) {
      if (query.isEmpty) return true;
      return c.titleUz.toLowerCase().contains(query) ||
          c.authorUz.toLowerCase().contains(query);
    }).toList();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Qidiruv',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 12),
            TextField(
              onChanged: (v) => ref.read(searchQueryProvider.notifier).state = v,
              decoration: const InputDecoration(
                hintText: 'Kurs yoki muallifni qidiring',
                prefixIcon: Icon(Icons.search),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.separated(
                itemCount: courses.length,
                separatorBuilder: (_, index) => const SizedBox(height: 10),
                itemBuilder: (context, i) {
                  final c = courses[i];
                  return Card(
                    margin: EdgeInsets.zero,
                    child: ListTile(
                      leading: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE9F0FF),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          iconForCategoryKey(
                            MockData.categories
                                .firstWhere((x) => x.id == c.categoryId,
                                    orElse: () => MockData.categories.first)
                                .iconKey,
                          ),
                          color: const Color(0xFF1E6BB8),
                        ),
                      ),
                      title: Text(
                        c.titleUz,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      subtitle: Text(
                        c.authorUz,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.black54,
                            ),
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.push('${AppRoutes.courseDetail}?id=${c.id}'),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

