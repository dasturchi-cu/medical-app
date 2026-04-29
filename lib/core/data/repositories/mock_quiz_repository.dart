import '../../mock/mock_data.dart';
import '../../models/quiz_models.dart';
import 'quiz_repository.dart';

class MockQuizRepository implements QuizRepository {
  @override
  Quiz? getQuizById(String id) {
    if (id == MockData.quiz.id) return MockData.quiz;
    return Quiz(
      id: id,
      titleUz: MockData.quiz.titleUz,
      questions: MockData.quiz.questions,
    );
  }
}

