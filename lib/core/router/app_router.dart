import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/course/presentation/pages/course_detail_page.dart';
import '../../features/home/presentation/pages/home_page.dart';
import '../../features/home/presentation/pages/my_courses_page.dart';
import '../../features/home/presentation/pages/profile_page.dart';
import '../../features/home/presentation/pages/search_page.dart';
import '../../features/lesson/presentation/pages/lesson_list_page.dart';
import '../../features/lesson/presentation/pages/lesson_view_page.dart';
import '../../features/quiz/presentation/pages/quiz_page.dart';
import '../../features/quiz/presentation/pages/result_page.dart';
import '../../widgets/app_bottom_nav.dart';
import '../router/app_routes.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: AppRoutes.home,
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return ScaffoldWithBottomNav(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.home,
                builder: (context, state) => const HomePage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.myCourses,
                builder: (context, state) => const MyCoursesPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.search,
                builder: (context, state) => const SearchPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.profile,
                builder: (context, state) => const ProfilePage(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.courseDetail,
        builder: (context, state) {
          final courseId = state.uri.queryParameters['id'] ?? '';
          return CourseDetailPage(courseId: courseId);
        },
      ),
      GoRoute(
        path: AppRoutes.lessonList,
        builder: (context, state) {
          final courseId = state.uri.queryParameters['courseId'] ?? '';
          final sectionId = state.uri.queryParameters['sectionId'] ?? '';
          return LessonListPage(courseId: courseId, sectionId: sectionId);
        },
      ),
      GoRoute(
        path: AppRoutes.lesson,
        builder: (context, state) {
          final lessonId = state.uri.queryParameters['id'] ?? '';
          return LessonViewPage(lessonId: lessonId);
        },
      ),
      GoRoute(
        path: AppRoutes.quiz,
        builder: (context, state) {
          final quizId = state.uri.queryParameters['id'] ?? '';
          return QuizPage(quizId: quizId);
        },
      ),
      GoRoute(
        path: AppRoutes.result,
        builder: (context, state) {
          final score = int.tryParse(state.uri.queryParameters['score'] ?? '') ?? 0;
          final total = int.tryParse(state.uri.queryParameters['total'] ?? '') ?? 0;
          return ResultPage(score: score, total: total);
        },
      ),
    ],
  );
});

// Bottom navigation shell scaffold
class ScaffoldWithBottomNav extends StatelessWidget {
  const ScaffoldWithBottomNav({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  void _onTap(int index) => navigationShell.goBranch(
        index,
        initialLocation: index == navigationShell.currentIndex,
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: AppBottomNav(
        currentIndex: navigationShell.currentIndex,
        onTap: _onTap,
      ),
    );
  }
}

