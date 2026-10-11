import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/activities/presentation/activities_screen.dart';
import '../features/auth/presentation/my_info_screen.dart';
import '../features/home/presentation/home_screen.dart';
import 'app_shell.dart';

/// 화면 경로 이름. 문자열을 여기저기 직접 쓰지 않도록 모아 둔다.
abstract final class AppRoutes {
  static const home = '/home';
  static const activities = '/activities';
  static const myInfo = '/me';
}

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: AppRoutes.home,
    routes: [
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
});
