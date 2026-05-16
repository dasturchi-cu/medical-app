import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/localization/language_provider.dart';
import '../../../../core/di/providers.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/state/auth_controller.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/state/purchase_controller.dart';
import '../../../../core/state/progress_controller.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/design_system.dart';
import '../../../../core/theme/theme_mode_provider.dart';

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(ref.read(authControllerProvider.notifier).syncProfileFromServer());
    });
  }

  AppLang _langFromCode(String? code) {
    switch (code) {
      case 'ru':
        return AppLang.ru;
      case 'en':
        return AppLang.en;
      default:
        return AppLang.uz;
    }
  }

  Future<void> _showNameEditDialog(BuildContext context, WidgetRef ref) async {
    final auth = ref.read(authControllerProvider);
    final defaultName = context.tr('profile_default_name');
    var editedName = auth.name == defaultName ? '' : auth.name;
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(ctx.tr('profile_edit_name_title')),
          content: TextFormField(
            initialValue: editedName,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(hintText: ctx.tr('profile_name_hint')),
            onChanged: (value) => editedName = value,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(ctx.tr('btn_cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(editedName.trim()),
              child: Text(ctx.tr('btn_save')),
            ),
          ],
        );
      },
    );
    if (!context.mounted || newName == null) return;
    try {
      await ref.read(authControllerProvider.notifier).updateName(newName);
    } on AuthServiceError catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ref = this.ref;
    final repo = ref.watch(courseRepositoryProvider);
    final progress = ref.watch(progressControllerProvider);
    final purchase = ref.watch(purchaseControllerProvider);
    final auth = ref.watch(authControllerProvider);
    final themePref =
        ref.watch(themeModeProvider).valueOrNull ?? AppThemePreference.system;
    final p = context.appColors;
    final loc = ref.watch(localizationProvider).valueOrNull;
    final langCode = loc?.langCode ?? 'uz';
    final currentLang = _langFromCode(langCode);
    final displayName = auth.isLoggedIn ? auth.name : context.tr('guest');
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
                      color: p.surfaceSecondary,
                      borderRadius: BorderRadius.circular(AppRadius.card),
                    ),
                    child: Icon(
                      Icons.person,
                      color: p.primary,
                      size: 30,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          auth.isLoggedIn
                              ? context.tr(
                                  'profile_id_label',
                                  params: {'id': auth.userId ?? '-'},
                                )
                              : context.tr(
                                  'profile_courses_count',
                                  params: {'n': '$myCount'},
                                ),
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: p.textSecondary,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        if (auth.isLoggedIn)
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton.icon(
                              onPressed: () => _showNameEditDialog(context, ref),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 2),
                                minimumSize: const Size(0, 0),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              icon: const Icon(Icons.edit_outlined, size: 16),
                              label: Text(context.tr('profile_edit')),
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
                      SnackBar(content: Text(context.tr('profile_id_copied'))),
                    );
                  },
                  icon: const Icon(Icons.copy_all_outlined),
                  label: Text(context.tr('profile_copy_id')),
                ),
              ),
            ),
          if (!auth.isLoggedIn && purchase.purchasedCourseIds.isEmpty)
            Card(
              margin: const EdgeInsets.only(bottom: AppSpacing.s12),
              child: ListTile(
                leading: const Icon(Icons.login),
                title: Text(context.tr('profile_login_title')),
                subtitle: Text(context.tr('profile_login_subtitle')),
                onTap: () => context.push(AppRoutes.login),
              ),
            ),
          Card(
            margin: EdgeInsets.zero,
            child: Column(
              children: [
                ListTile(
                  leading: Icon(Icons.menu_book_outlined, color: p.icon),
                  title: Text(context.tr('nav_my_courses')),
                  trailing: Icon(Icons.chevron_right, color: p.icon),
                  onTap: () => context.go(AppRoutes.myCourses),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Icon(
                    themePref == AppThemePreference.dark
                        ? Icons.dark_mode_outlined
                        : themePref == AppThemePreference.system
                            ? Icons.brightness_auto_outlined
                            : Icons.light_mode_outlined,
                    color: p.icon,
                  ),
                  title: Text(context.tr('theme_appearance')),
                  subtitle: Text(_themeSubtitle(context, themePref)),
                  trailing: Icon(Icons.chevron_right, color: p.icon),
                  onTap: () => _showThemePicker(context, ref, themePref),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Icon(Icons.language_outlined, color: p.icon),
                  title: Text(context.tr('language')),
                  trailing: DropdownButtonHideUnderline(
                    child: DropdownButton<AppLang>(
                      value: currentLang,
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
                        final code = v == AppLang.ru
                            ? 'ru'
                            : v == AppLang.en
                                ? 'en'
                                : 'uz';
                        if (code == langCode) return;
                        unawaited(
                          ref.read(localizationProvider.notifier).setLang(code).then((_) {
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(context.tr('language_changed'))),
                            );
                          }),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _themeSubtitle(BuildContext context, AppThemePreference pref) {
    switch (pref) {
      case AppThemePreference.dark:
        return context.tr('theme_dark');
      case AppThemePreference.system:
        return context.tr('theme_system');
      case AppThemePreference.light:
        return context.tr('theme_light');
    }
  }

  Future<void> _showThemePicker(
    BuildContext context,
    WidgetRef ref,
    AppThemePreference current,
  ) async {
    final selected = await showModalBottomSheet<AppThemePreference>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        final p = ctx.appColors;
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  context.tr('theme_appearance'),
                  style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: p.textPrimary,
                      ),
                ),
              ),
              _ThemeOptionTile(
                title: context.tr('theme_light'),
                icon: Icons.light_mode_outlined,
                value: AppThemePreference.light,
                group: current,
                onPick: (v) => Navigator.pop(ctx, v),
              ),
              _ThemeOptionTile(
                title: context.tr('theme_dark'),
                icon: Icons.dark_mode_outlined,
                value: AppThemePreference.dark,
                group: current,
                onPick: (v) => Navigator.pop(ctx, v),
              ),
              _ThemeOptionTile(
                title: context.tr('theme_system'),
                icon: Icons.brightness_auto_outlined,
                value: AppThemePreference.system,
                group: current,
                onPick: (v) => Navigator.pop(ctx, v),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
    if (selected == null || selected == current) return;
    await ref.read(themeModeProvider.notifier).setPreference(selected);
  }
}

class _ThemeOptionTile extends StatelessWidget {
  const _ThemeOptionTile({
    required this.title,
    required this.icon,
    required this.value,
    required this.group,
    required this.onPick,
  });

  final String title;
  final IconData icon;
  final AppThemePreference value;
  final AppThemePreference group;
  final ValueChanged<AppThemePreference> onPick;

  @override
  Widget build(BuildContext context) {
    final p = context.appColors;
    final selected = value == group;
    return ListTile(
      leading: Icon(icon, color: selected ? p.primary : p.icon),
      title: Text(
        title,
        style: TextStyle(
          color: p.textPrimary,
          fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
        ),
      ),
      trailing: selected
          ? Icon(Icons.check_circle, color: p.primary)
          : Icon(Icons.circle_outlined, color: p.textMuted),
      onTap: () => onPick(value),
    );
  }
}
