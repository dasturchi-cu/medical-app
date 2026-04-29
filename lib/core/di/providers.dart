import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/course_repository.dart';
import '../data/repositories/comments_repository.dart';
import '../data/repositories/http_comments_repository.dart';
import '../data/repositories/http_lesson_slides_repository.dart';
import '../data/repositories/http_notifications_repository.dart';
import '../data/repositories/http_slides_repository.dart';
import '../data/repositories/http_test_attempt_repository.dart';
import '../data/repositories/mock_course_repository.dart';
import '../data/repositories/mock_quiz_repository.dart';
import '../data/repositories/notifications_repository.dart';
import '../data/repositories/quiz_repository.dart';
import '../data/repositories/lesson_slides_repository.dart';
import '../data/repositories/slides_repository.dart';
import '../data/repositories/test_attempt_repository.dart';
import '../services/activation_service.dart';
import '../services/auth_service.dart';

final courseRepositoryProvider = Provider<CourseRepository>((ref) {
  return MockCourseRepository();
});

final quizRepositoryProvider = Provider<QuizRepository>((ref) {
  return MockQuizRepository();
});

final activationServiceProvider = Provider<ActivationService>((ref) {
  return ActivationService();
});

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

final notificationsRepositoryProvider = Provider<NotificationsRepository>((ref) {
  const apiBaseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: '');
  return HttpNotificationsRepository(baseUrl: apiBaseUrl);
});

final testAttemptRepositoryProvider = Provider<TestAttemptRepository>((ref) {
  const apiBaseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: '');
  return HttpTestAttemptRepository(baseUrl: apiBaseUrl);
});

final slidesRepositoryProvider = Provider<SlidesRepository>((ref) {
  const apiBaseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: '');
  return HttpSlidesRepository(baseUrl: apiBaseUrl);
});

final commentsRepositoryProvider = Provider<CommentsRepository>((ref) {
  const apiBaseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: '');
  return HttpCommentsRepository(baseUrl: apiBaseUrl);
});

final lessonSlidesRepositoryProvider = Provider<LessonSlidesRepository>((ref) {
  const apiBaseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: '');
  return HttpLessonSlidesRepository(baseUrl: apiBaseUrl);
});

