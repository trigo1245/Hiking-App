import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/app_user.dart';
import '../domain/auth_failure.dart';
import 'auth_repository.dart';

/// 카카오·구글 모두 Supabase OAuth(브라우저)로 로그인한다.
/// 브라우저에서 로그인을 마치면 딥링크([_redirectUrl])로 앱에 돌아오고, 세션은 onAuthStateChange로 온다.
/// 구글도 브라우저 방식이라 앱 서명(SHA-1) 등록이 필요 없다. 어느 컴퓨터에서 빌드해도 로그인된다.
class SupabaseAuthRepository implements AuthRepository {
  // 비공개 필드를 바로 받는 매개변수. 바깥에서는 auth:, redirectUrl:로 넘긴다.
  SupabaseAuthRepository({required this._auth, required this._redirectUrl});

  final GoTrueClient _auth;
  final String _redirectUrl;

  @override
  AppUser? get currentUser => _toAppUser(_auth.currentUser);

  @override
  Stream<AppUser?> watchUser() => _auth.onAuthStateChange
      .map((state) => _toAppUser(state.session?.user))
      // 오류는 watchFailures에서 따로 다룬다.
      .handleError((_) {});

  @override
  Stream<AuthFailure> watchFailures() {
    final controller = StreamController<AuthFailure>();
    final sub = _auth.onAuthStateChange.listen(
      (_) {},
      onError: (Object error) => controller.add(mapAuthError(error)),
    );
    controller.onCancel = sub.cancel;
    return controller.stream;
  }

  @override
  Future<void> signInWithGoogle() => _guard(
    () => _auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: _redirectUrl,
      // 로그아웃 후 다른 계정으로 들어갈 수 있도록 매번 계정 선택 화면을 띄운다.
      queryParams: const {'prompt': 'select_account'},
    ),
  );

  @override
  Future<void> signInWithKakao() => _guard(
    () => _auth.signInWithOAuth(OAuthProvider.kakao, redirectTo: _redirectUrl),
  );

  @override
  Future<void> signOut() => _guard(_auth.signOut);

  /// 외부 라이브러리 오류를 [AuthFailure]로 바꿔 던진다.
  Future<void> _guard(Future<void> Function() action) async {
    try {
      await action();
    } catch (error) {
      throw mapAuthError(error);
    }
  }

  static AppUser? _toAppUser(User? user) {
    // 익명 로그인은 지원하지 않는다. 예전 테스트에서 남은 익명 세션은 로그아웃 상태로 본다.
    if (user == null || user.isAnonymous) return null;
    return AppUser(
      id: user.id,
      // 가입할 때 사용한 로그인 방법
      provider: switch (user.appMetadata['provider']) {
        'kakao' => SocialProvider.kakao,
        'google' => SocialProvider.google,
        _ => null,
      },
    );
  }
}

/// Supabase 오류를 [AuthFailure]로 분류한다. 테스트를 위해 공개한다.
AuthFailure mapAuthError(Object error) {
  if (error is AuthFailure) return error;

  if (error is AuthRetryableFetchException) {
    return AuthFailure(AuthFailureType.network, error.message);
  }

  if (error is AuthException) {
    // 브라우저 로그인 오류는 error_code가 statusCode에 담겨 온다.
    final codes = {error.code, error.statusCode};
    if (codes.any(_configErrorCodes.contains)) {
      return AuthFailure(AuthFailureType.notConfigured, error.message);
    }
    return AuthFailure(AuthFailureType.unknown, error.message);
  }

  return AuthFailure(AuthFailureType.unknown, error.toString());
}

const _configErrorCodes = {'provider_disabled', 'validation_failed'};
