import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/providers.dart';
import '../../../../core/localization/language_provider.dart';
import '../providers/pomodoro_provider.dart';
import '../widgets/control_buttons.dart';
import '../widgets/circular_timer.dart';
import '../widgets/course_selector.dart';

class PomodoroScreen extends ConsumerWidget {
  const PomodoroScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(pomodoroProvider);
    final notifier = ref.read(pomodoroProvider.notifier);
    final repo = ref.watch(courseRepositoryProvider);

    final courses = repo
        .getCourses()
        .map((e) => CourseOption(id: e.id, title: e.titleUz))
        .toList(growable: false);
    if (courses.isNotEmpty && state.selectedCourseId.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        notifier.selectCourse(courses.first.id);
      });
    }

    final isFocus = state.sessionType == PomodoroSessionType.focus;
    final pomodoroTypeLabel = isFocus
        ? context.tr('pomodoro_session_focus')
        : context.tr('pomodoro_session_break');
    final selectedCourse =
        courses
            .where((e) => e.id == state.selectedCourseId)
            .firstOrNull
            ?.title ??
        '-';

    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          const _BackgroundGlow(),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).maybePop(),
                        icon: const Icon(
                          Icons.close_rounded,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.tr('pomodoro_title'),
                              style: Theme.of(context).textTheme.headlineSmall
                                  ?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                            Text(
                              selectedCourse,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: Colors.white.withValues(alpha: 0.72),
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  CourseSelector(
                    title: context.tr('pomodoro_course_selector'),
                    selectedCourseId: state.selectedCourseId,
                    courses: courses,
                    onChanged: notifier.selectCourse,
                  ),
                  const SizedBox(height: 14),
                  _SessionTypeSwitch(
                    focusLabel: context.tr('pomodoro_session_focus'),
                    breakLabel: context.tr('pomodoro_session_break'),
                    selected: state.sessionType,
                    onChanged: notifier.setSessionType,
                  ),
                  const SizedBox(height: 26),
                  Center(
                    child: CircularTimer(
                      remainingSeconds: state.remainingSeconds,
                      totalSeconds: state.totalSeconds,
                      isRunning: state.isRunning,
                      sessionLabel: pomodoroTypeLabel,
                    ),
                  ),
                  const SizedBox(height: 18),
                  _SessionStats(
                    pomodoroCount: state.pomodoroCount,
                    completedSessions: state.completedSessions,
                    pomodoroLabel: context.tr('pomodoro_count_label'),
                    completedLabel: context.tr('pomodoro_completed_label'),
                    typeLabel: pomodoroTypeLabel,
                  ),
                  const Spacer(),
                  ControlButtons(
                    isRunning: state.isRunning,
                    onStart: notifier.start,
                    onPause: notifier.pause,
                    onReset: notifier.reset,
                    startLabel: context.tr('pomodoro_start'),
                    pauseLabel: context.tr('pomodoro_pause'),
                    resetLabel: context.tr('pomodoro_reset'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SessionStats extends StatelessWidget {
  const _SessionStats({
    required this.pomodoroCount,
    required this.completedSessions,
    required this.pomodoroLabel,
    required this.completedLabel,
    required this.typeLabel,
  });

  final int pomodoroCount;
  final int completedSessions;
  final String pomodoroLabel;
  final String completedLabel;
  final String typeLabel;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _GlassStatCard(
            title: pomodoroLabel,
            value: '$pomodoroCount',
            suffix: typeLabel,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _GlassStatCard(
            title: completedLabel,
            value: '$completedSessions',
            suffix: context.tr('pomodoro_sessions_suffix'),
          ),
        ),
      ],
    );
  }
}

class _GlassStatCard extends StatelessWidget {
  const _GlassStatCard({
    required this.title,
    required this.value,
    required this.suffix,
  });

  final String title;
  final String value;
  final String suffix;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.72),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                value,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                suffix,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.72),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SessionTypeSwitch extends StatelessWidget {
  const _SessionTypeSwitch({
    required this.focusLabel,
    required this.breakLabel,
    required this.selected,
    required this.onChanged,
  });

  final String focusLabel;
  final String breakLabel;
  final PomodoroSessionType selected;
  final ValueChanged<PomodoroSessionType> onChanged;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white.withValues(alpha: 0.20)),
          ),
          child: Row(
            children: [
              Expanded(
                child: _SwitchChip(
                  label: focusLabel,
                  selected: selected == PomodoroSessionType.focus,
                  onTap: () => onChanged(PomodoroSessionType.focus),
                ),
              ),
              Expanded(
                child: _SwitchChip(
                  label: breakLabel,
                  selected: selected == PomodoroSessionType.breakTime,
                  onTap: () => onChanged(PomodoroSessionType.breakTime),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SwitchChip extends StatelessWidget {
  const _SwitchChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: selected
            ? Colors.white.withValues(alpha: 0.22)
            : Colors.transparent,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Center(
              child: Text(
                label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BackgroundGlow extends StatelessWidget {
  const _BackgroundGlow();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0D1B36), Color(0xFF273470), Color(0xFF5B2D84)],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -80,
            right: -20,
            child: _GlowCircle(
              size: 220,
              color: const Color(0xFF67D7FF).withValues(alpha: 0.28),
            ),
          ),
          Positioned(
            left: -60,
            bottom: 120,
            child: _GlowCircle(
              size: 180,
              color: const Color(0xFFA38BFF).withValues(alpha: 0.24),
            ),
          ),
        ],
      ),
    );
  }
}

class _GlowCircle extends StatelessWidget {
  const _GlowCircle({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: [BoxShadow(color: color, blurRadius: 100, spreadRadius: 30)],
      ),
    );
  }
}

extension _FirstOrNullX<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
