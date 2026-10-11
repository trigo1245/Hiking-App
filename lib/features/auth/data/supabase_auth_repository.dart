import 'dart:async';

import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/app_user.dart';
import '../domain/auth_failure.dart';
import 'auth_repository.dart';

class SupabaseAuthRepository implements AuthRepository {
  // 비공개 필드를 바로 받는 매개변수. 바깥에서는 auth:, googleWebClientId:, redirectUrl:로 넘긴다.
  SupabaseAuthRepository({
    required this._auth,
    required this._googleWebClientId,
    required this._redirectUrl,
  });

  final GoTrueClient _auth;
  final String _googleWebClientId;
  final String _redirectUrl;

  Future<void>? _googleInit;

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
  Future<void> signInAnonymously() => _guard(() => _auth.signInAnonymously());

  @override
  Future<void> signInWithGoogle() => _guard(() async {
    final idToken = await _googleIdToken();
    await _auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: idToken,
    );
  });

  @override
  Future<void> linkGoogle() => _guard(() async {
    final idToken = await _googleIdToken();
    await _auth.linkIdentityWithIdToken(
      provider: OAuthProvider.google,
      idToken: idToken,
    );
  });

  @override
  Future<void> signInWithKakao() => _guard(
    () => _auth.signInWithOAuth(OAuthProvider.kakao, redirectTo: _redirectUrl),
  );

  @override
  Future<void> linkKakao() => _guard(
    () => _auth.linkIdentity(OAuthProvider.kakao, redirectTo: _redirectUrl),
  );

  @override
  Future<void> signOut() => _guard(() async {
    await _auth.signOut();
    // 다음 구글 로그인 때 계정 선택 창이 다시 뜨도록 기기의 구글 로그인도 끊는다.
    if (_googleInit != null) await GoogleSignIn.instance.signOut();
  });

  /// 구글 로그인 창을 띄워 ID 토큰을 받는다.
  /// Android(Credential Manager)의 ID 토큰에는 at_hash가 없어 access token은 넘기지 않는다.
  Future<String> _googleIdToken() async {
    if (_googleWebClientId.isEmpty) {
      throw const AuthFailure(
        AuthFailureType.notConfigured,
        'GOOGLE_WEB_CLIENT_ID가 env.json에 없어요.',
      );
    }
    _googleInit ??= GoogleSignIn.instance.initialize(
      serverClientId: _googleWebClientId,
    );
    await _googleInit;

    final account = await GoogleSignIn.instance.authenticate();
    final idToken = account.authentication.idToken;
    if (idToken == null) {
      throw const AuthFailure(AuthFailureType.unknown, '구글 ID 토큰이 없어요.');
    }
    return idToken;
  }

  /// 외부 라이브러리 오류를 [AuthFailure]로 바꿔 던진다.
  Future<void> _guard(Future<void> Function() action) async {
    try {
      await action();
    } catch (error) {
      throw mapAuthError(error);
    }
  }

  static AppUser? _toAppUser(User? user) {
    if (user == null) return null;
    final providers = <SocialProvider>{
      for (final identity in user.identities ?? const <UserIdentity>[])
        ?_providerFromName(identity.provider),
    };
    return AppUser(
      id: user.id,
      isAnonymous: user.isAnonymous,
      linkedProviders: providers,
    );
  }

  static SocialProvider? _providerFromName(String name) => switch (name) {
    'kakao' => SocialProvider.kakao,
    'google' => SocialProvider.google,
    _ => null,
  };
}

/// Supabase·Google 오류를 [AuthFailure]로 분류한다. 테스트를 위해 공개한다.
AuthFailure mapAuthError(Object error) {
  if (error is AuthFailure) return error;

  if (error is GoogleSignInException) {
    return switch (error.code) {
      GoogleSignInExceptionCode.canceled ||
      GoogleSignInExceptionCode.interrupted => AuthFailure(
        AuthFailureType.cancelled,
        error.description,
      ),
      GoogleSignInExceptionCode.clientConfigurationError ||
      GoogleSignInExceptionCode.providerConfigurationError => AuthFailure(
        AuthFailureType.notConfigured,
        error.description,
      ),
      _ => AuthFailure(AuthFailureType.unknown, error.description),
    };
  }

  if (error is AuthRetryableFetchException) {
    return AuthFailure(AuthFailureType.network, error.message);
  }

  if (error is AuthException) {
    // 브라우저 로그인 오류는 error_code가 statusCode에 담겨 온다.
    final codes = {error.code, error.statusCode};
    if (codes.contains('identity_already_exists')) {
      return AuthFailure(AuthFailureType.identityAlreadyExists, error.message);
    }
    if (codes.any(_configErrorCodes.contains)) {
      return AuthFailure(AuthFailureType.notConfigured, error.message);
    }
    return AuthFailure(AuthFailureType.unknown, error.message);
  }

  return AuthFailure(AuthFailureType.unknown, error.toString());
}

const _configErrorCodes = {
  'manual_linking_disabled',
  'provider_disabled',
  'anonymous_provider_disabled',
  'validation_failed',
};
