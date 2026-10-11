import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/activities/presentation/activities_screen.dart';
import '../features/auth/presentation/auth_providers.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/my_info_screen.dart';
import '../features/home/presentation/home_screen.dart';
import 'app_shell.dart';

/// 화면 경로 이름. 문자열을 여기저기 직접 쓰지 않도록 모아 둔다.
abstract final class AppRoutes {
  static const login = '/login';
  static const home = '/home';
  static const activities = '/activities';
  static const myInfo = '/me';
}

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
