import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/localization/language_provider.dart';
import '../../../../core/di/providers.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/state/auth_controller.dart';
import '../../../../core/state/progress_controller.dart';
import '../../../../core/theme/design_system.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(courseRepositoryProvider);
    final progress = ref.watch(progressControllerProvider);
    final auth = ref.watch(authControllerProvider);
    final myCount = repo.getCourses().where((c) {
      final p = progress.byCourseId[c.id];
      return (p?.enrolled ?? false) || c.progress > 0;
    }).length;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.s16,
          AppSpacing.s12,
          AppSpacing.s16,
          AppSpacing.s16,
        ),
        children: [
          Text(
            context.tr('profile'),
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: AppSpacing.s12),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.s12),
              child: Row(
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceAlt,
                      borderRadius: BorderRadius.circular(AppRadius.card),
                    ),
                    child: const Icon(
                      Icons.person,
                      color: AppColors.primary,
                      size: 30,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          auth.name,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          auth.isLoggedIn
                              ? 'ID: ${auth.userId ?? '-'}'
                              : '$myCount ta kurs',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: AppColors.textSecondary,
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
          const SizedBox(height: AppSpacing.s12),
          if (auth.isLoggedIn && auth.userId != null)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.s12),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: auth.userId!));
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('ID nusxalandi')),
                    );
                  },
                  icon: const Icon(Icons.copy_all_outlined),
                  label: const Text('ID ni nusxalash'),
                ),
              ),
            ),
          if (!auth.isLoggedIn)
            Card(
              margin: const EdgeInsets.only(bottom: AppSpacing.s12),
              child: ListTile(
                leading: const Icon(Icons.login),
                title: const Text('Akkauntga kiring'),
                subtitle: const Text('Kurs sotib olish uchun login qiling'),
                onTap: () => context.push(AppRoutes.login),
              ),
            ),
          Card(
            margin: EdgeInsets.zero,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.menu_book_outlined),
                  title: Text(context.tr('nav_my_courses')),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.go(AppRoutes.myCourses),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.language_outlined),
                  title: Text(context.tr('language')),
                  trailing: DropdownButtonHideUnderline(
                    child: DropdownButton<AppLang>(
                      value:
                          (ref
                                      .watch(localizationProvider)
                                      .valueOrNull
                                      ?.langCode ??
                                  'uz') ==
                              'ru'
                          ? AppLang.ru
                          : (ref
                                        .watch(localizationProvider)
                                        .valueOrNull
                                        ?.langCode ??
                                    'uz') ==
                                'en'
                          ? AppLang.en
                          : AppLang.uz,
                      items: [
                        DropdownMenuItem(
                          value: AppLang.uz,
                          child: Text(context.tr('lang_uz')),
                        ),
                        DropdownMenuItem(
                          value: AppLang.ru,
                          child: Text(context.tr('lang_ru')),
                        ),
                        DropdownMenuItem(
                          value: AppLang.en,
                          child: Text(context.tr('lang_en')),
                        ),
                      ],
                      onChanged: (v) {
                        if (v == null) return;
                        ref
                            .read(localizationProvider.notifier)
                            .setLang(
                              v == AppLang.ru
                                  ? 'ru'
                                  : v == AppLang.en
                                  ? 'en'
                                  : 'uz',
                            );
                      },
                    ),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.settings_outlined),
                  title: Text(context.tr('settings')),
                  subtitle: Text(context.tr('dummy')),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(context.tr('soon'))),
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
