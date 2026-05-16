import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../../../core/config/api_config.dart';
import '../../../../core/state/auth_controller.dart';

enum PomodoroSessionType { focus, breakTime }

class PomodoroState {
  const PomodoroState({
    required this.sessionType,
    required this.focusMinutes,
    required this.breakMinutes,
    required this.soundOn,
    required this.totalSeconds,
    required this.remainingSeconds,
    required this.isRunning,
    required this.pomodoroCount,
    required this.completedSessions,
  });

  factory PomodoroState.initial() {
    return const PomodoroState(
      sessionType: PomodoroSessionType.focus,
      focusMinutes: 25,
      breakMinutes: 5,
      soundOn: true,
      totalSeconds: 25 * 60,
      remainingSeconds: 25 * 60,
      isRunning: false,
      pomodoroCount: 1,
      completedSessions: 0,
    );
  }

  final PomodoroSessionType sessionType;
  final int focusMinutes;
  final int breakMinutes;
  final bool soundOn;
  final int totalSeconds;
  final int remainingSeconds;
  final bool isRunning;
  final int pomodoroCount;
  final int completedSessions;

  PomodoroState copyWith({
    PomodoroSessionType? sessionType,
    int? focusMinutes,
    int? breakMinutes,
    bool? soundOn,
    int? totalSeconds,
    int? remainingSeconds,
    bool? isRunning,
    int? pomodoroCount,
    int? completedSessions,
  }) {
    return PomodoroState(
      sessionType: sessionType ?? this.sessionType,
      focusMinutes: focusMinutes ?? this.focusMinutes,
      breakMinutes: breakMinutes ?? this.breakMinutes,
      soundOn: soundOn ?? this.soundOn,
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

final pomodoroProvider =
    AutoDisposeNotifierProvider<PomodoroController, PomodoroState>(
  PomodoroController.new,
);

class PomodoroController extends AutoDisposeNotifier<PomodoroState> {
  Timer? _timer;
  int _persistedFocusSeconds = 0;
  bool _isDisposed = false;

  @override
  PomodoroState build() {
    ref.onDispose(() {
      _isDisposed = true;
      _cancelTimer();
    });
    return PomodoroState.initial();
  }

  void setSessionType(PomodoroSessionType type) {
    if (state.sessionType == type) return;
    _cancelTimer();
    _persistedFocusSeconds = 0;
    final duration = _durationFor(type);
    state = state.copyWith(
      sessionType: type,
      totalSeconds: duration,
      remainingSeconds: duration,
      isRunning: false,
    );
  }

  void updateFocusMinutes(int minutes) {
    final clamped = minutes.clamp(1, 90);
    final isFocus = state.sessionType == PomodoroSessionType.focus;
    state = state.copyWith(
      focusMinutes: clamped,
      totalSeconds: isFocus ? clamped * 60 : state.totalSeconds,
      remainingSeconds: isFocus ? clamped * 60 : state.remainingSeconds,
      isRunning: isFocus ? false : state.isRunning,
    );
    if (isFocus) {
      _cancelTimer();
      _persistedFocusSeconds = 0;
    }
  }

  void updateBreakMinutes(int minutes) {
    final clamped = minutes.clamp(1, 45);
    final isBreak = state.sessionType == PomodoroSessionType.breakTime;
    state = state.copyWith(
      breakMinutes: clamped,
      totalSeconds: isBreak ? clamped * 60 : state.totalSeconds,
      remainingSeconds: isBreak ? clamped * 60 : state.remainingSeconds,
      isRunning: isBreak ? false : state.isRunning,
    );
    if (isBreak) _cancelTimer();
  }

  void toggleSound(bool value) {
    state = state.copyWith(soundOn: value);
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
    _persistedFocusSeconds = 0;
    final duration = _durationFor(state.sessionType);
    state = state.copyWith(
      isRunning: false,
      totalSeconds: duration,
      remainingSeconds: duration,
    );
  }

  void _tick() {
    if (_isDisposed) return;
    final seconds = state.remainingSeconds;
    if (seconds <= 1) {
      _cancelTimer();
      if (_isDisposed) return;
      final finishedFocus = state.sessionType == PomodoroSessionType.focus;
      state = state.copyWith(
        remainingSeconds: 0,
        isRunning: false,
        completedSessions: state.completedSessions + 1,
        pomodoroCount: finishedFocus
            ? state.pomodoroCount + 1
            : state.pomodoroCount,
      );
      if (finishedFocus) {
        final delta = (state.totalSeconds - _persistedFocusSeconds).clamp(
          0,
          state.totalSeconds,
        );
        if (delta > 0) {
          _persistedFocusSeconds += delta;
          unawaited(
            _sendPomodoroSession(
              focusSeconds: delta,
              completedCycles: 1,
            ),
          );
        }
      }
      return;
    }

    if (_isDisposed) return;
    state = state.copyWith(remainingSeconds: seconds - 1);
  }

  int _durationFor(PomodoroSessionType type) {
    return type == PomodoroSessionType.focus
        ? state.focusMinutes * 60
        : state.breakMinutes * 60;
  }

  void _cancelTimer() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> stopForPageExit() async {
    // Pomodoro sahifadan chiqilganda timer/background yozuvni to'xtatamiz.
    pause();
    if (state.sessionType != PomodoroSessionType.focus) return;
    final elapsed = (state.totalSeconds - state.remainingSeconds).clamp(
      0,
      state.totalSeconds,
    );
    final delta = elapsed - _persistedFocusSeconds;
    if (delta < 60) return; // juda qisqa sessiyalarni shovqin qilmaymiz
    _persistedFocusSeconds += delta;
    await _sendPomodoroSession(
      focusSeconds: delta,
      completedCycles: 0,
    );
  }

  Future<void> _sendPomodoroSession({
    required int focusSeconds,
    int breakSeconds = 0,
    int completedCycles = 1,
  }) async {
    final auth = ref.read(authControllerProvider);
    final userId = auth.userId ?? '';
    final baseUrl = getApiBaseUrl();
    if (userId.isEmpty || baseUrl.isEmpty) return;
    if (focusSeconds <= 0) return;
    try {
      final primary = Uri.parse('$baseUrl/api/v1/ranking/pomodoro/session');
      final fallback = Uri.parse('$baseUrl/api/v1/leaderboard/pomodoro/session');
      final bodyStr = jsonEncode({
        'user_id': userId,
        'focus_seconds': focusSeconds,
        'break_seconds': breakSeconds,
        'completed_cycles': completedCycles,
        'focus_minutes': ((focusSeconds + 59) ~/ 60).clamp(1, 9999),
        'break_minutes': ((breakSeconds + 59) ~/ 60).clamp(0, 9999),
      });
      const headers = {'Content-Type': 'application/json'};
      var res = await http.post(primary, headers: headers, body: bodyStr);
      if (res.statusCode == 404) {
        debugPrint('[Pomodoro][sync][fallback] POST $fallback');
        res = await http.post(fallback, headers: headers, body: bodyStr);
      }
      if (res.statusCode < 200 || res.statusCode >= 300) {
        debugPrint('[Pomodoro][sync] status=${res.statusCode} body=${res.body}');
      }
    } catch (e) {
      debugPrint('[Pomodoro][sync] $e');
    }
  }
}
