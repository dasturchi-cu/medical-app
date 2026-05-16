import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/course_progress_local_store.dart';

class CourseProgress {
  final String courseId;
  final String? lastLessonId;
  final Set<String> completedLessonIds;
  final Set<String> watchedLessonIds;
  final bool enrolled;

  const CourseProgress({
    required this.courseId,
    required this.lastLessonId,
    required this.completedLessonIds,
    required this.watchedLessonIds,
    required this.enrolled,
  });

  CourseProgress copyWith({
    String? lastLessonId,
    Set<String>? completedLessonIds,
    Set<String>? watchedLessonIds,
    bool? enrolled,
  }) {
    return CourseProgress(
      courseId: courseId,
      lastLessonId: lastLessonId ?? this.lastLessonId,
      completedLessonIds: completedLessonIds ?? this.completedLessonIds,
      watchedLessonIds: watchedLessonIds ?? this.watchedLessonIds,
      enrolled: enrolled ?? this.enrolled,
    );
  }
}

class ProgressState {
  final Map<String, CourseProgress> byCourseId;

  const ProgressState({required this.byCourseId});

  ProgressState copyWith({Map<String, CourseProgress>? byCourseId}) {
    return ProgressState(byCourseId: byCourseId ?? this.byCourseId);
  }
}

final progressControllerProvider =
    NotifierProvider<ProgressController, ProgressState>(ProgressController.new);

class ProgressController extends Notifier<ProgressState> {
  @override
  ProgressState build() {
    return const ProgressState(byCourseId: {});
  }

  void hydrateFromLocal(Map<String, CourseProgress> cached) {
    if (cached.isEmpty) return;
    final next = {...state.byCourseId};
    for (final entry in cached.entries) {
      final existing = next[entry.key];
      if (existing == null) {
        next[entry.key] = entry.value;
        continue;
      }
      next[entry.key] = existing.copyWith(
        lastLessonId: existing.lastLessonId ?? entry.value.lastLessonId,
        watchedLessonIds: {...existing.watchedLessonIds, ...entry.value.watchedLessonIds},
        completedLessonIds: {...existing.completedLessonIds, ...entry.value.completedLessonIds},
        enrolled: existing.enrolled || entry.value.enrolled,
      );
    }
    state = state.copyWith(byCourseId: next);
  }

  void _persistSoon() {
    final snapshot = state;
    unawaited(CourseProgressLocalStore.save(snapshot));
  }

  CourseProgress _ensure(String courseId) {
    return state.byCourseId[courseId] ??
        CourseProgress(
          courseId: courseId,
          lastLessonId: null,
          completedLessonIds: <String>{},
          watchedLessonIds: <String>{},
          enrolled: false,
        );
  }

  void enroll(String courseId) {
    final current = _ensure(courseId);
    state = state.copyWith(
      byCourseId: {
        ...state.byCourseId,
        courseId: current.copyWith(enrolled: true),
      },
    );
    _persistSoon();
  }

  void openedLesson({required String courseId, required String lessonId}) {
    final current = _ensure(courseId);
    final watched = {...current.watchedLessonIds, lessonId};
    state = state.copyWith(
      byCourseId: {
        ...state.byCourseId,
        courseId: current.copyWith(
          lastLessonId: lessonId,
          watchedLessonIds: watched,
          enrolled: true,
        ),
      },
    );
    _persistSoon();
  }

  void completeLesson({required String courseId, required String lessonId}) {
    final current = _ensure(courseId);
    final nextSet = {...current.completedLessonIds, lessonId};
    final watched = {...current.watchedLessonIds, lessonId};
    state = state.copyWith(
      byCourseId: {
        ...state.byCourseId,
        courseId: current.copyWith(
          completedLessonIds: nextSet,
          watchedLessonIds: watched,
          enrolled: true,
        ),
      },
    );
    _persistSoon();
  }

  void mergeCompletedFromServer(Map<String, Set<String>> completedByCourseId) {
    if (completedByCourseId.isEmpty) return;
    final next = {...state.byCourseId};
    for (final entry in completedByCourseId.entries) {
      final current = _ensure(entry.key);
      final merged = {...current.completedLessonIds, ...entry.value};
      final watched = {...current.watchedLessonIds, ...entry.value};
      next[entry.key] = current.copyWith(
        completedLessonIds: merged,
        watchedLessonIds: watched,
        enrolled: true,
      );
    }
    state = state.copyWith(byCourseId: next);
    _persistSoon();
  }

  void mergeWatchedFromServer(Map<String, Set<String>> watchedByCourseId) {
    if (watchedByCourseId.isEmpty) return;
    final next = {...state.byCourseId};
    for (final entry in watchedByCourseId.entries) {
      final current = _ensure(entry.key);
      final merged = {...current.watchedLessonIds, ...entry.value};
      next[entry.key] = current.copyWith(
        watchedLessonIds: merged,
        enrolled: true,
      );
    }
    state = state.copyWith(byCourseId: next);
    _persistSoon();
  }

  /// Video ijro etilganda UI foizi darhol yangilansin (server javobini kutmasdan).
  void noteLessonPlayback(
    String courseId,
    String lessonId, {
    required bool completed,
  }) {
    final current = _ensure(courseId);
    final watched = {...current.watchedLessonIds, lessonId};
    final completedSet =
        completed ? {...current.completedLessonIds, lessonId} : current.completedLessonIds;
    state = state.copyWith(
      byCourseId: {
        ...state.byCourseId,
        courseId: current.copyWith(
          watchedLessonIds: watched,
          completedLessonIds: completedSet,
          enrolled: true,
        ),
      },
    );
    _persistSoon();
  }
}

