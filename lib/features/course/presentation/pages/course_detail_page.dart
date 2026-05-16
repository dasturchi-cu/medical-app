import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;

import '../../../../core/config/api_config.dart';
import '../../../../core/di/providers.dart';
import '../../../../core/services/course_progress_remote_sync.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/state/app_state_providers.dart';
import '../../../../core/state/auth_controller.dart';
import '../../../../core/state/purchase_controller.dart';
import '../../../../core/state/progress_controller.dart';
import '../../../../core/localization/language_provider.dart';
import '../../../../core/utils/course_title.dart';
import '../../../../widgets/base_card.dart';
import '../../../../widgets/lesson_item.dart';
import '../widgets/purchase_modal.dart';

class CourseDetailPage extends ConsumerStatefulWidget {
  const CourseDetailPage({super.key, required this.courseId});

  final String courseId;

  @override
  ConsumerState<CourseDetailPage> createState() => _CourseDetailPageState();
}

class _CourseDetailPageState extends ConsumerState<CourseDetailPage> {
  bool _catalogOpenSent = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _recordCatalogOpen();
      unawaited(CourseProgressRemoteSync.refresh(ref));
    });
  }

  Future<void> _recordCatalogOpen() async {
    if (_catalogOpenSent) return;
    final auth = ref.read(authControllerProvider);
    final userId = auth.userId;
    if (userId == null || userId.isEmpty) return;
    final baseUrl = getApiBaseUrl();
    if (baseUrl.isEmpty || widget.courseId.trim().isEmpty) return;
    _catalogOpenSent = true;
    try {
      debugPrint(
        '[API][courses.catalog_open][request] courseId=${widget.courseId} userId=$userId',
      );
      final response = await http
          .post(
            Uri.parse('$baseUrl/api/v1/courses/${widget.courseId}/catalog-open'),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({'user_id': userId}),
          )
          .timeout(const Duration(seconds: 10));
      debugPrint('[API][courses.catalog_open][response] status=${response.statusCode}');
    } catch (e) {
      debugPrint('[API][courses.catalog_open][error] $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(courseRepositoryProvider);
    final authState = ref.watch(authControllerProvider);
    final lang =
        ref.watch(localizationProvider).valueOrNull?.langCode ?? 'uz';
    final course = repo.getCourseById(widget.courseId);
    final purchased = ref.watch(purchaseControllerProvider).isPurchased(widget.courseId);
    final progressState = ref.watch(progressControllerProvider);
    final lessons = course == null ? const [] : repo.getFlattenLessons(widget.courseId);
    final isDoctorCourse = course?.id == 'course_private_neuro';
    final p = progressState.byCourseId[widget.courseId];
    final watchedCount = p?.watchedLessonIds.length ?? 0;
    final progressValue = lessons.isEmpty
        ? 0.0
        : (watchedCount / lessons.length).toDouble().clamp(0.0, 1.0);

    if (course == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Kurs')),
        body: const Center(child: Text('Kurs topilmadi')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(cleanCourseTitle(course.localizedTitle(lang))),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        children: [
          _CourseHero(imageUrl: course.imageUrl),
          const SizedBox(height: 14),
          Text(
            cleanCourseTitle(course.localizedTitle(lang)),
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900, fontSize: 30, height: 1.25),
          ),
          const SizedBox(height: 8),
          Text(
            course.localizedDescription(lang),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  height: 1.35,
                ),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progressValue.clamp(0, 1),
              minHeight: 8,
              backgroundColor: const Color(0xFFE7EEF9),
              valueColor: const AlwaysStoppedAnimation(Color(0xFF1E6BB8)),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Ko‘rish: ${(progressValue * 100).round()}% · $watchedCount / ${lessons.length} dars',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _ChipInfo(
                  icon: Icons.menu_book_outlined,
                  label: '${lessons.length} ta dars',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ChipInfo(
                  icon: Icons.lock_open_outlined,
                  label: isDoctorCourse
                      ? 'Har bir baza alohida sotiladi'
                      : (purchased ? 'Kurs ochilgan' : '1-dars bepul'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ChipInfo(
                  icon: Icons.person_outline,
                  label: authState.isLoggedIn
                      ? authState.name
                      : context.tr('guest'),
                ),
              ),
            ],
          ),
          if (!purchased && !isDoctorCourse)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: SizedBox(
                height: 46,
                child: FilledButton.tonal(
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () async {
                    await showPurchaseModal(
                      context: context,
                      courseName: course.titleUz,
                      description: course.descriptionUz,
                      price: course.priceUz,
                      courseId: course.id,
                    );
                  },
                  child: const Text(
                    'Sotib olish',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 14),
          if (isDoctorCourse) ...[
            Text(
              'Bazalar',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 10),
            ...course.sections.map((s) {
              final purchaseState = ref.watch(purchaseControllerProvider);
              final basePurchased = purchaseState.isBasePurchased(course.id, s.id);
              final sectionUnlocked = purchaseState.isPurchased(course.id) || basePurchased;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: BaseCard(
                  title: sectionUnlocked ? '${s.titleUz} (sotib olingan)' : s.titleUz,
                  videoCountText: '${s.lessons.length} ta video',
                  onTap: () async {
                    if (!sectionUnlocked) {
                      await showPurchaseModal(
                        context: context,
                        courseName: '${course.titleUz} - ${s.titleUz}',
                        description: 'Ushbu baza uchun alohida to‘lov qilinadi',
                        price: course.priceUz,
                        courseId: basePurchaseKey(course.id, s.id),
                      );
                      return;
                    }
                    ref.read(selectedCourseIdProvider.notifier).state = course.id;
                    ref.read(progressControllerProvider.notifier).enroll(course.id);
                    context.push(
                      '${AppRoutes.lessonList}?courseId=${course.id}&sectionId=${s.id}',
                    );
                  },
                ),
              );
            }),
          ] else ...[
            Text(
              'Video darslar',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 10),
            ...List.generate(lessons.length, (i) {
              final l = lessons[i];
              final locked = !purchased && l.isLocked;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: LessonItem(
                  index: i + 1,
                  title: l.titleUz,
                  duration: l.durationUz,
                  locked: locked,
                  onTap: () async {
                    if (locked) {
                      await showPurchaseModal(
                        context: context,
                        courseName: course.titleUz,
                        description: course.descriptionUz,
                        price: course.priceUz,
                        courseId: course.id,
                      );
                      return;
                    }
                    ref.read(selectedCourseIdProvider.notifier).state = course.id;
                    ref.read(progressControllerProvider.notifier).openedLesson(
                          courseId: course.id,
                          lessonId: l.id,
                        );
                    context.push('${AppRoutes.lesson}?id=${l.id}');
                  },
                ),
              );
            }),
          ],
          const SizedBox(height: 8),
          SizedBox(
            height: 48,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF1E6BB8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: () {
                if (!purchased && !isDoctorCourse) {
                  showPurchaseModal(
                    context: context,
                    courseName: course.titleUz,
                    description: course.descriptionUz,
                    price: course.priceUz,
                    courseId: course.id,
                  );
                  return;
                }
                ref.read(selectedCourseIdProvider.notifier).state = course.id;
                ref.read(progressControllerProvider.notifier).enroll(course.id);
                final firstSection = course.sections.isNotEmpty ? course.sections.first : null;
                if (firstSection != null) {
                  context.push(
                    '${AppRoutes.lessonList}?courseId=${course.id}&sectionId=${firstSection.id}',
                  );
                  return;
                }
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Bu kurs uchun avval dars qo\'shing.'),
                  ),
                );
              },
              child: const Text(
                'Boshlash',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CourseHero extends StatelessWidget {
  const _CourseHero({required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    final raw = imageUrl.trim();
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: 200,
        width: double.infinity,
        child: raw.isEmpty
            ? const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF1E6BB8), Color(0xFF0E4E8B)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              )
            : raw.startsWith('data:image')
                ? Image.memory(
                    base64Decode(raw.substring(raw.indexOf(',') + 1)),
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF1E6BB8), Color(0xFF0E4E8B)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                    ),
                  )
                : Image.network(
                raw,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    color: const Color(0xFFEAF1FF),
                    alignment: Alignment.center,
                    child: const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) => const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF1E6BB8), Color(0xFF0E4E8B)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}

class _ChipInfo extends StatelessWidget {
  const _ChipInfo({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: const Color(0xFF1E6BB8)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
