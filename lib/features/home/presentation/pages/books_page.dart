import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/data/models/content_asset_models.dart';
import '../../../../core/localization/language_provider.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/state/books_state.dart';
import '../../../../widgets/cached_remote_image.dart';

class BooksPage extends ConsumerWidget {
  const BooksPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final booksAsync = ref.watch(booksFeedProvider);
    final progressAsync = ref.watch(bookProgressProvider);
    final paidIdsAsync = ref.watch(paidBookIdsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(context.tr('books_page_title'))),
      body: booksAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(child: Text(context.tr('books_server_error'))),
        data: (items) {
          final progressByBook = {
            for (final p in (progressAsync.valueOrNull ?? const <BookProgressModel>[])) p.bookId: p,
          };
          final paidBookIds = paidIdsAsync.valueOrNull ?? const <String>{};
          if (items.isEmpty) {
            return Center(child: Text(context.tr('books_empty')));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final item = items[index];
              final unlocked = !item.isPaid || paidBookIds.contains(item.id);
              final progress = progressByBook[item.id];
              final progressLine = progress == null
                  ? item.author
                  : 'Progress: ${progress.progressPercent.toStringAsFixed(1)}%';
              final aboutLine = item.description.trim().isEmpty
                  ? progressLine
                  : item.description.trim();
              return Card(
                margin: EdgeInsets.zero,
                child: ListTile(
                  contentPadding: const EdgeInsets.all(12),
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: 56,
                      height: 56,
                      child: _BookCoverImage(url: item.coverImageUrl),
                    ),
                  ),
                  title: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(
                    unlocked
                        ? progressLine
                        : item.isPaid
                        ? '${context.tr('book_locked_price', params: {'price': '${item.priceUzs}'})}\n$aboutLine'
                        : progressLine,
                    maxLines: unlocked ? 2 : 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: unlocked
                      ? const Icon(Icons.chevron_right)
                      : item.isPaid
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.lock_outline, size: 18),
                            const SizedBox(width: 6),
                            Chip(
                              label: Text('${item.priceUzs}'),
                              visualDensity: VisualDensity.compact,
                            ),
                          ],
                        )
                      : const Icon(Icons.chevron_right),
                  onTap: () => context.push('${AppRoutes.bookReader}?id=${item.id}'),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _BookCoverImage extends StatelessWidget {
  const _BookCoverImage({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    final value = url.trim();
    if (value.isEmpty) return const ColoredBox(color: Color(0xFFE9F0FF));
    if (value.startsWith('data:image')) {
      final comma = value.indexOf(',');
      if (comma > 0) {
        try {
          final payload = value.substring(comma + 1).replaceAll(RegExp(r'\s'), '');
          return Image.memory(base64Decode(payload), fit: BoxFit.cover, errorBuilder: (_, _, _) => const ColoredBox(color: Color(0xFFE9F0FF)));
        } catch (_) {
          return const ColoredBox(color: Color(0xFFE9F0FF));
        }
      }
    }
    return CachedRemoteImage(
      url: value,
      fit: BoxFit.cover,
      errorBuilder: (_, _) => const ColoredBox(color: Color(0xFFE9F0FF)),
    );
  }
}
