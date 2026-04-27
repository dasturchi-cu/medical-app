import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/providers.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/state/app_state_providers.dart';
import '../../../../core/state/auth_controller.dart';
import '../../../../core/state/purchase_controller.dart';
import '../../../../core/state/progress_controller.dart';
import '../../../../widgets/lesson_item.dart';

class LessonListPage extends ConsumerWidget {
  const LessonListPage({
    super.key,
    required this.courseId,
    required this.sectionId,
  });

  final String courseId;
  final String sectionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(courseRepositoryProvider);
    final section = repo.getSectionById(courseId, sectionId);
    final purchased = ref.watch(purchaseControllerProvider).isPurchased(courseId);

    if (section == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Darslar'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.pop(),
          ),
        ),
        body: const Center(child: Text('Bo‘lim topilmadi')),
      );
    }

    final flat = repo.getFlattenLessons(courseId);
    int globalIndexOf(String lessonId) =>
        flat.indexWhere((x) => x.id == lessonId);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Darslar'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        itemCount: section.lessons.length,
        separatorBuilder: (_, index) => const SizedBox(height: 10),
        itemBuilder: (context, i) {
          final l = section.lessons[i];

          final g = globalIndexOf(l.id);
          final locked = !purchased && g > 0; // only first lesson overall is free

          return LessonItem(
            index: g + 1,
            title: l.titleUz,
            duration: l.durationUz,
            locked: locked,
            onTap: () async {
                if (locked) {
                  final go = await showDialog<bool>(
                    context: context,
                    builder: (ctx) {
                      return AlertDialog(
                        title: const Text('Obuna bo‘ling'),
                        content: const Text(
                          'Bu dars yopiq. Ochish uchun tizimga kiring va obuna xarid qiling.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(ctx).pop(false),
                            child: const Text('Bekor'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.of(ctx).pop(true),
                            child: const Text('Ochish'),
                          ),
                        ],
                      );
                    },
                  );
                  if (go != true) return;

                  final auth = ref.read(authControllerProvider);
                  if (!auth.isLoggedIn) {
                    final ok = await showModalBottomSheet<bool>(
                      context: context,
                      isScrollControlled: true,
                      builder: (ctx) => const _LoginSheet(),
                    );
                    if (ok != true) return;
                  }

                  final bought = await showDialog<bool>(
                    context: context,
                    builder: (ctx) {
                      return AlertDialog(
                        title: const Text('Obuna'),
                        content: const Text(
                          'Kursni ochish uchun “Sotib olish” tugmasini bosing.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(ctx).pop(false),
                            child: const Text('Keyinroq'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.of(ctx).pop(true),
                            child: const Text('Sotib olish'),
                          ),
                        ],
                      );
                    },
                  );
                  if (bought == true) {
                    ref.read(purchaseControllerProvider.notifier).purchaseCourse(courseId);
                  } else {
                    return;
                  }
                }

                ref.read(selectedCourseIdProvider.notifier).state = courseId;
                ref
                    .read(progressControllerProvider.notifier)
                    .openedLesson(courseId: courseId, lessonId: l.id);
                context.push('${AppRoutes.lesson}?id=${l.id}');
              },
          );
        },
      ),
    );
  }
}

class _LoginSheet extends ConsumerStatefulWidget {
  const _LoginSheet();

  @override
  ConsumerState<_LoginSheet> createState() => _LoginSheetState();
}

class _LoginSheetState extends ConsumerState<_LoginSheet> {
  final _name = TextEditingController(text: 'Azizbek');

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: 16 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Kirish',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _name,
              decoration: const InputDecoration(
                hintText: 'Ismingiz',
                prefixIcon: Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 48,
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF1E6BB8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () {
                  ref.read(authControllerProvider.notifier).login(name: _name.text);
                  Navigator.of(context).pop(true);
                },
                child: const Text(
                  'Kirish',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

