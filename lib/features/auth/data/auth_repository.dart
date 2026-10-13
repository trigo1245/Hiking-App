import '../domain/app_user.dart';
import '../domain/auth_failure.dart';

/// 로그인 기능의 창구. 화면은 이 인터페이스만 알고, Supabase·Google SDK는 모른다.
abstract interface class AuthRepository {
  AppUser? get currentUser;

  /// 로그인·로그아웃 때마다 최신 사용자를 내보낸다.
  Stream<AppUser?> watchUser();

  /// 브라우저 로그인(카카오)처럼 결과가 나중에 도착하는 흐름의 오류.
  Stream<AuthFailure> watchFailures();

  /// 로그인 창을 띄워 바로 로그인한다. 실패하면 [AuthFailure]를 던진다.
  Future<void> signInWithGoogle();

  /// 브라우저를 연다. 결과는 [watchUser] / [watchFailures]로 도착한다.
  Future<void> signInWithKakao();

  Future<void> signOut();
}
