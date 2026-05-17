import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

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

/// AutoDispose emas — sahifadan chiqganda `prepareForPageExit` timer to‘xtatadi.
final pomodoroProvider = NotifierProvider<PomodoroController, PomodoroState>(
  PomodoroController.new,
);

class PomodoroController extends Notifier<PomodoroState> {
  static const _prefsKey = 'pomodoro_state_v1';
  Timer? _timer;
  int _persistedFocusSeconds = 0;
  bool _isDisposed = false;
  String? _sessionId;
  int _lastSyncedAtMs = 0;
  int _lastPersistMs = 0;
  bool _hydrated = false;
  bool _pomodoroSyncEndpointMissing = false;
  static const int _minRankingFocusSeconds = 30;

  @override
  PomodoroState build() {
    ref.onDispose(() {
      _isDisposed = true;
      _cancelTimer();
    });
    if (!_hydrated) {
      _hydrated = true;
      unawaited(_hydrateFromDisk());
    }
    return PomodoroState.initial();
  }

  void setSessionType(PomodoroSessionType type) {
    if (state.sessionType == type) return;
    _cancelTimer();
    _persistedFocusSeconds = 0;
    _sessionId = null;
    final duration = _durationFor(type);
    state = state.copyWith(
      sessionType: type,
      totalSeconds: duration,
      remainingSeconds: duration,
      isRunning: false,
    );
    unawaited(_persistToDisk());
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
      _sessionId = null;
    }
    unawaited(_persistToDisk());
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
    unawaited(_persistToDisk());
  }

  void toggleSound(bool value) {
    state = state.copyWith(soundOn: value);
    unawaited(_persistToDisk());
  }

  void start() {
    if (state.isRunning) return;
    if (state.remainingSeconds <= 0) {
      reset();
    }
    if (_sessionId == null && state.sessionType == PomodoroSessionType.focus) {
      unawaited(_sendSessionLifecycle('start', focusSeconds: state.totalSeconds));
    } else if (_sessionId != null && state.sessionType == PomodoroSessionType.focus) {
      unawaited(_sendSessionLifecycle('resume'));
    }
    state = state.copyWith(isRunning: true);
    _lastSyncedAtMs = DateTime.now().millisecondsSinceEpoch;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    unawaited(_persistToDisk());
  }

  void pause() => _haltRunning(updateProvider: true);

  void _haltRunning({required bool updateProvider}) {
    if (!state.isRunning) return;
    _cancelTimer();
    final sendPause =
        _sessionId != null && state.sessionType == PomodoroSessionType.focus;
    if (updateProvider && !_isDisposed) {
      state = state.copyWith(isRunning: false);
    }
    if (sendPause) {
      unawaited(_sendSessionLifecycle('pause'));
    }
    if (updateProvider && !_isDisposed) {
      unawaited(_persistToDisk());
    }
  }

  void reset() {
    _cancelTimer();
    _persistedFocusSeconds = 0;
    _sessionId = null;
    final duration = _durationFor(state.sessionType);
    state = state.copyWith(
      isRunning: false,
      totalSeconds: duration,
      remainingSeconds: duration,
    );
    unawaited(_persistToDisk());
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
        final elapsed = state.totalSeconds.clamp(1, 24 * 3600);
        _persistedFocusSeconds = 0;
        unawaited(
          _sendPomodoroSession(
            focusSeconds: elapsed,
            completedCycles: 1,
          ),
        );
        if (_sessionId != null) {
          unawaited(
            _sendSessionLifecycle(
              'finish',
              durationSec: elapsed,
              status: 'completed',
            ),
          );
          _sessionId = null;
        }
      }
      unawaited(_persistToDisk(force: true));
      return;
    }

    if (_isDisposed) return;
    state = state.copyWith(remainingSeconds: seconds - 1);
    _lastSyncedAtMs = DateTime.now().millisecondsSinceEpoch;
    unawaited(_persistToDisk());
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

  Future<void> onAppLifecycleChanged(AppLifecycleState stateValue) async {
    if (stateValue == AppLifecycleState.resumed) {
      if (state.isRunning) {
        _syncWallClockDrift();
        if (_timer == null) {
          _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
        }
      }
      await _persistToDisk(force: true);
      return;
    }
    if (stateValue == AppLifecycleState.inactive ||
        stateValue == AppLifecycleState.paused ||
        stateValue == AppLifecycleState.detached) {
      if (state.isRunning) {
        _syncWallClockDrift();
        _cancelTimer();
      }
      await _persistToDisk(force: true);
    }
  }

  void _syncWallClockDrift() {
    if (!state.isRunning || _lastSyncedAtMs <= 0) return;
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final delta = ((nowMs - _lastSyncedAtMs) / 1000).floor();
    if (delta <= 0) return;
    final next = (state.remainingSeconds - delta).clamp(0, state.totalSeconds);
    if (next == state.remainingSeconds) return;
    state = state.copyWith(remainingSeconds: next);
    _lastSyncedAtMs = nowMs;
  }

  Future<void> _persistToDisk({bool force = false}) async {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    if (!force && state.isRunning && nowMs - _lastPersistMs < 4000) {
      return;
    }
    _lastPersistMs = nowMs;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _prefsKey,
        jsonEncode({
          'sessionType': state.sessionType.name,
          'focusMinutes': state.focusMinutes,
          'breakMinutes': state.breakMinutes,
          'soundOn': state.soundOn,
          'totalSeconds': state.totalSeconds,
          'remainingSeconds': state.remainingSeconds,
          'isRunning': state.isRunning,
          'pomodoroCount': state.pomodoroCount,
          'completedSessions': state.completedSessions,
          'persistedFocusSeconds': _persistedFocusSeconds,
          'sessionId': _sessionId,
          'lastSyncedAtMs': DateTime.now().millisecondsSinceEpoch,
        }),
      );
    } catch (_) {}
  }

  Future<void> _hydrateFromDisk() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw == null || raw.trim().isEmpty) return;
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return;
      final typeRaw = (decoded['sessionType'] ?? 'focus').toString();
      final restoredType = typeRaw == PomodoroSessionType.breakTime.name
          ? PomodoroSessionType.breakTime
          : PomodoroSessionType.focus;
      _persistedFocusSeconds =
          int.tryParse((decoded['persistedFocusSeconds'] ?? '0').toString()) ?? 0;
      _sessionId = (decoded['sessionId'] ?? '').toString().trim().isEmpty
          ? null
          : (decoded['sessionId'] ?? '').toString();
      _lastSyncedAtMs =
          int.tryParse((decoded['lastSyncedAtMs'] ?? '0').toString()) ?? 0;
      final restored = PomodoroState(
        sessionType: restoredType,
        focusMinutes: int.tryParse((decoded['focusMinutes'] ?? '25').toString()) ?? 25,
        breakMinutes: int.tryParse((decoded['breakMinutes'] ?? '5').toString()) ?? 5,
        soundOn: decoded['soundOn'] != false,
        totalSeconds: int.tryParse((decoded['totalSeconds'] ?? '1500').toString()) ?? 1500,
        remainingSeconds:
            int.tryParse((decoded['remainingSeconds'] ?? '1500').toString()) ?? 1500,
        isRunning: decoded['isRunning'] == true,
        pomodoroCount: int.tryParse((decoded['pomodoroCount'] ?? '1').toString()) ?? 1,
        completedSessions:
            int.tryParse((decoded['completedSessions'] ?? '0').toString()) ?? 0,
      );
      if (_isDisposed) return;
      state = restored;
      _syncWallClockDrift();
      if (state.isRunning && _timer == null) {
        _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
      }
    } catch (e) {
      debugPrint('[Pomodoro][hydrate] $e');
    }
  }

  Future<void> _sendSessionLifecycle(
    String action, {
    int? focusSeconds,
    int? durationSec,
    String status = 'completed',
  }) async {
    final auth = ref.read(authControllerProvider);
    final userId = auth.userId ?? '';
    final baseUrl = getApiBaseUrl();
    if (userId.isEmpty || baseUrl.isEmpty) return;
    final headers = const {'Content-Type': 'application/json'};
    try {
      if (action == 'start') {
        final res = await http.post(
          Uri.parse('$baseUrl/api/v1/pomodoro/session/start'),
          headers: headers,
          body: jsonEncode({
            'user_id': userId,
            'focus_seconds': focusSeconds ?? state.totalSeconds,
          }),
        );
        if (res.statusCode >= 200 && res.statusCode < 300) {
          final body = jsonDecode(res.body);
          if (body is Map<String, dynamic>) {
            final sid = (body['session_id'] ?? '').toString().trim();
            if (sid.isNotEmpty) _sessionId = sid;
          }
        }
        return;
      }
      final sid = (_sessionId ?? '').trim();
      if (sid.isEmpty) return;
      if (action == 'pause' || action == 'resume') {
        await http.post(
          Uri.parse('$baseUrl/api/v1/pomodoro/session/$action'),
          headers: headers,
          body: jsonEncode({'user_id': userId, 'session_id': sid}),
        );
        return;
      }
      if (action == 'finish') {
        await http.post(
          Uri.parse('$baseUrl/api/v1/pomodoro/session/finish'),
          headers: headers,
          body: jsonEncode({
            'user_id': userId,
            'session_id': sid,
            'duration_sec': durationSec ?? (state.totalSeconds - state.remainingSeconds),
            'status': status,
          }),
        );
      }
    } catch (e) {
      debugPrint('[Pomodoro][lifecycle:$action] $e');
    }
  }

  /// Sahifadan chiqishda darhol timer to‘xtatiladi (async reyting alohida).
  void prepareForPageExit() {
    _cancelTimer();
    if (_isDisposed) return;
    if (state.isRunning) {
      state = state.copyWith(isRunning: false);
    }
    _lastSyncedAtMs = DateTime.now().millisecondsSinceEpoch;
    unawaited(_persistToDisk(force: true));
  }

  Future<void> flushRankingOnPageExit() async {
    if (state.sessionType != PomodoroSessionType.focus) return;
    final elapsed = (state.totalSeconds - state.remainingSeconds).clamp(
      0,
      state.totalSeconds,
    );
    final delta = elapsed - _persistedFocusSeconds;
    if (delta < _minRankingFocusSeconds) return;
    _persistedFocusSeconds += delta;
    await _sendPomodoroSession(
      focusSeconds: delta,
      completedCycles: 0,
    );
    if (_sessionId != null) {
      await _sendSessionLifecycle(
        'finish',
        durationSec: elapsed,
        status: 'stopped',
      );
      _sessionId = null;
    }
    await _persistToDisk(force: true);
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
    if (_pomodoroSyncEndpointMissing) return;
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
      var res = await http
          .post(primary, headers: headers, body: bodyStr)
          .timeout(const Duration(seconds: 25));
      if (res.statusCode == 404) {
        debugPrint('[Pomodoro][sync][fallback] POST $fallback');
        res = await http
            .post(fallback, headers: headers, body: bodyStr)
            .timeout(const Duration(seconds: 25));
        if (res.statusCode == 404) {
          _pomodoroSyncEndpointMissing = true;
          debugPrint(
            '[Pomodoro][sync] endpoint missing (both /ranking and /leaderboard 404).',
          );
          return;
        }
      }
      if (res.statusCode >= 200 && res.statusCode < 300) {
        debugPrint(
          '[Pomodoro][sync] ok focus_seconds=$focusSeconds cycles=$completedCycles',
        );
      } else {
        debugPrint('[Pomodoro][sync] status=${res.statusCode} body=${res.body}');
      }
    } catch (e) {
      debugPrint('[Pomodoro][sync] $e');
    }
  }
}
