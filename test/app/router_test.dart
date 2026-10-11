import 'package:flutter_test/flutter_test.dart';
import 'package:hiking_app/app/router.dart';

void main() {
  group('authRedirect', () {
    test('로그인하지 않았으면 로그인 화면으로 보낸다', () {
      expect(
        authRedirect(isSignedIn: false, location: AppRoutes.home),
        AppRoutes.login,
      );
    });

    test('로그인하지 않았고 이미 로그인 화면이면 그대로 둔다', () {
      expect(
        authRedirect(isSignedIn: false, location: AppRoutes.login),
        isNull,
      );
    });

    test('로그인했는데 로그인 화면이면 홈으로 보낸다', () {
      expect(
        authRedirect(isSignedIn: true, location: AppRoutes.login),
        AppRoutes.home,
      );
    });

    test('로그인했으면 다른 화면은 그대로 둔다', () {
      expect(
        authRedirect(isSignedIn: true, location: AppRoutes.myInfo),
        isNull,
      );
    });
  });
}
