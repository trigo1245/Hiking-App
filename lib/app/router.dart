import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/achievements/presentation/achievements_screen.dart';
import '../features/activities/presentation/activities_screen.dart';
import '../features/activities/presentation/activity_detail_screen.dart';
import '../features/auth/presentation/auth_providers.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/my_info_screen.dart';
import '../features/courses/presentation/course_detail_screen.dart';
import '../features/courses/domain/competition.dart';
import '../features/courses/presentation/course_reviews_section.dart';
import '../features/courses/presentation/full_ranking_screen.dart';
import '../features/home/presentation/home_screen.dart';
import '../features/recording/data/location_service.dart';
import '../features/recording/presentation/location_permission_screen.dart';
import '../features/recording/presentation/recording_complete_screen.dart';
import '../features/recording/presentation/recording_screen.dart';
import '../features/subscription/presentation/premium_screen.dart';
import 'app_shell.dart';
import 'routes.dart';

export 'routes.dart';

/// 로그인 상태에 따라 이동할 경로. null이면 그대로 둔다.
/// - 로그인 안 함 → 로그인 화면
/// - 로그인 화면에 있는데 로그인됨 → 홈
@visibleForTesting
String? authRedirect({required bool isSignedIn, required String location}) {
  final atLogin = location == AppRoutes.login;
  if (!isSignedIn) return atLogin ? null : AppRoutes.login;
  if (atLogin) return AppRoutes.home;
  return null;
}

final routerProvider = Provider<GoRouter>((ref) {
  final authRepository = ref.watch(authRepositoryProvider);

  // 로그인한 사용자가 바뀔 때(로그인·로그아웃) 라우터가 redirect를 다시 검사하게 한다.
  final authChanged = ValueNotifier<int>(0);
  ref.listen(
    currentUserProvider.select((user) => user.value?.id),
    (_, _) => authChanged.value++,
  );

  final router = GoRouter(
    initialLocation: AppRoutes.home,
    refreshListenable: authChanged,
    redirect: (context, state) => authRedirect(
      isSignedIn: authRepository.currentUser != null,
      location: state.matchedLocation,
    ),
    routes: [
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      // 기록 화면들은 하단 탭 없이 전체 화면으로 띄운다.
      // 서로 겹쳐 쌓이지 않도록 하위 경로가 아닌 독립 경로로 둔다.
      GoRoute(
        path: AppRoutes.recording,
        builder: (context, state) => const RecordingScreen(),
      ),
      GoRoute(
        path: '/record-done/:id',
        builder: (context, state) =>
            RecordingCompleteScreen(activityId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/location-permission/:access',
        builder: (context, state) => LocationPermissionScreen(
          access: LocationAccess.values.byName(state.pathParameters['access']!),
        ),
      ),
      GoRoute(
        path: '/course/:id',
        builder: (context, state) =>
            CourseDetailScreen(courseId: state.pathParameters['id']!),
        routes: [
          // 리뷰 쓰기는 코스 상세 위에 쌓아서, 저장하면 상세로 돌아간다.
          GoRoute(
            path: 'review',
            builder: (context, state) =>
                WriteReviewScreen(courseId: state.pathParameters['id']!),
          ),
          GoRoute(
            path: 'ranking',
            builder: (context, state) => FullRankingScreen(
              courseId: state.pathParameters['id']!,
              initialKind: RankingKind.values.byName(
                state.uri.queryParameters['kind'] ?? RankingKind.most.name,
              ),
              initialAllTime: state.uri.queryParameters['alltime'] == 'true',
            ),
          ),
          GoRoute(
            path: 'reviews',
            builder: (context, state) =>
                AllReviewsScreen(courseId: state.pathParameters['id']!),
          ),
        ],
      ),
      GoRoute(
        path: '/activity/:id',
        builder: (context, state) =>
            ActivityDetailScreen(activityId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: AppRoutes.achievements,
        builder: (context, state) => const AchievementsScreen(),
      ),
      GoRoute(
        path: AppRoutes.premium,
        builder: (context, state) => const PremiumScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.home,
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.activities,
                builder: (context, state) => const ActivitiesScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.myInfo,
                builder: (context, state) => const MyInfoScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );

  ref.onDispose(() {
    router.dispose();
    authChanged.dispose();
  });
  return router;
});
