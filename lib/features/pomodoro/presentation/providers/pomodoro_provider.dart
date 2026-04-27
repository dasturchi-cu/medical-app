import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

enum PomodoroSessionType { focus, breakTime }

class PomodoroState {
  const PomodoroState({
    required this.selectedCourseId,
    required this.sessionType,
    required this.totalSeconds,
    required this.remainingSeconds,
    required this.isRunning,
    required this.pomodoroCount,
    required this.completedSessions,
  });

  factory PomodoroState.initial() {
    return const PomodoroState(
      selectedCourseId: '',
      sessionType: PomodoroSessionType.focus,
      totalSeconds: 25 * 60,
      remainingSeconds: 25 * 60,
      isRunning: false,
      pomodoroCount: 1,
      completedSessions: 0,
    );
  }

  final String selectedCourseId;
  final PomodoroSessionType sessionType;
  final int totalSeconds;
  final int remainingSeconds;
  final bool isRunning;
  final int pomodoroCount;
  final int completedSessions;

  PomodoroState copyWith({
    String? selectedCourseId,
    PomodoroSessionType? sessionType,
    int? totalSeconds,
    int? remainingSeconds,
    bool? isRunning,
    int? pomodoroCount,
    int? completedSessions,
  }) {
    return PomodoroState(
      selectedCourseId: selectedCourseId ?? this.selectedCourseId,
      sessionType: sessionType ?? this.sessionType,
      totalSeconds: totalSeconds ?? this.totalSeconds,
      remainingSeconds: remainingSeconds ?? this.remainingSeconds,
      isRunning: isRunning ?? this.isRunning,
      pomodoroCount: pomodoroCount ?? this.pomodoroCount,
      completedSessions: completedSessions ?? this.completedSessions,
    );
  }

  double get progress {
    if (totalSeconds == 0) return 0;
    final elapsed = (totalSeconds - remainingSeconds).clamp(0, totalSeconds);
    return elapsed / totalSeconds;
  }
}

final pomodoroProvider = NotifierProvider<PomodoroController, PomodoroState>(
  PomodoroController.new,
);

class PomodoroController extends Notifier<PomodoroState> {
  Timer? _timer;

  @override
  PomodoroState build() {
    ref.onDispose(_cancelTimer);
    return PomodoroState.initial();
  }

  void selectCourse(String courseId) {
    state = state.copyWith(selectedCourseId: courseId);
  }

  void setSessionType(PomodoroSessionType type) {
    if (state.sessionType == type) return;
    _cancelTimer();
    final duration = _durationFor(type);
    state = state.copyWith(
      sessionType: type,
      totalSeconds: duration,
      remainingSeconds: duration,
      isRunning: false,
    );
  }

  void start() {
    if (state.isRunning) return;
    if (state.remainingSeconds <= 0) {
      reset();
    }
    state = state.copyWith(isRunning: true);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void pause() {
    if (!state.isRunning) return;
    _cancelTimer();
    state = state.copyWith(isRunning: false);
  }

  void reset() {
    _cancelTimer();
    final duration = _durationFor(state.sessionType);
    state = state.copyWith(
      isRunning: false,
      totalSeconds: duration,
      remainingSeconds: duration,
    );
  }

  void _tick() {
    final seconds = state.remainingSeconds;
    if (seconds <= 1) {
      _cancelTimer();
      final finishedFocus = state.sessionType == PomodoroSessionType.focus;
      state = state.copyWith(
        remainingSeconds: 0,
        isRunning: false,
        completedSessions: state.completedSessions + 1,
        pomodoroCount: finishedFocus
            ? state.pomodoroCount + 1
            : state.pomodoroCount,
      );
      return;
    }

    state = state.copyWith(remainingSeconds: seconds - 1);
  }

  int _durationFor(PomodoroSessionType type) {
    return type == PomodoroSessionType.focus ? 25 * 60 : 5 * 60;
  }

  void _cancelTimer() {
    _timer?.cancel();
    _timer = null;
  }
}
