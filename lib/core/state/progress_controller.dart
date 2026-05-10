import 'package:flutter_riverpod/flutter_riverpod.dart';

class CourseProgress {
  final String courseId;
  final String? lastLessonId;
  final Set<String> completedLessonIds;
  final bool enrolled;

  const CourseProgress({
    required this.courseId,
    required this.lastLessonId,
    required this.completedLessonIds,
    required this.enrolled,
  });

  CourseProgress copyWith({
    String? lastLessonId,
    Set<String>? completedLessonIds,
    bool? enrolled,
  }) {
    return CourseProgress(
      courseId: courseId,
      lastLessonId: lastLessonId ?? this.lastLessonId,
      completedLessonIds: completedLessonIds ?? this.completedLessonIds,
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

  CourseProgress _ensure(String courseId) {
    return state.byCourseId[courseId] ??
        CourseProgress(
          courseId: courseId,
          lastLessonId: null,
          completedLessonIds: <String>{},
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
  }

  void openedLesson({required String courseId, required String lessonId}) {
    final current = _ensure(courseId);
    state = state.copyWith(
      byCourseId: {
        ...state.byCourseId,
        courseId: current.copyWith(lastLessonId: lessonId, enrolled: true),
      },
    );
  }

  void completeLesson({required String courseId, required String lessonId}) {
    final current = _ensure(courseId);
    final nextSet = {...current.completedLessonIds, lessonId};
    state = state.copyWith(
      byCourseId: {
        ...state.byCourseId,
        courseId: current.copyWith(completedLessonIds: nextSet, enrolled: true),
      },
    );
  }

  void mergeCompletedFromServer(Map<String, Set<String>> completedByCourseId) {
    if (completedByCourseId.isEmpty) return;
    final next = {...state.byCourseId};
    for (final entry in completedByCourseId.entries) {
      final current = _ensure(entry.key);
      final merged = {...current.completedLessonIds, ...entry.value};
      next[entry.key] = current.copyWith(
        completedLessonIds: merged,
        enrolled: true,
      );
    }
    state = state.copyWith(byCourseId: next);
  }
}

