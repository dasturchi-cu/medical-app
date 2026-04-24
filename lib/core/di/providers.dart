import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/course_repository.dart';
import '../data/repositories/mock_course_repository.dart';
import '../data/repositories/mock_quiz_repository.dart';
import '../data/repositories/quiz_repository.dart';
import '../services/activation_service.dart';

final courseRepositoryProvider = Provider<CourseRepository>((ref) {
  return MockCourseRepository();
});

final quizRepositoryProvider = Provider<QuizRepository>((ref) {
  return MockQuizRepository();
});

final activationServiceProvider = Provider<ActivationService>((ref) {
  return ActivationService();
});

