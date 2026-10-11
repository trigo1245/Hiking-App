import 'dart:async';

import 'package:hiking_app/features/auth/data/auth_repository.dart';
import 'package:hiking_app/features/auth/domain/app_user.dart';
import 'package:hiking_app/features/auth/domain/auth_failure.dart';

/// 서버 없이 로그인 흐름을 흉내 내는 테스트용 repository.
class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({this._user});

  AppUser? _user;
  final _users = StreamController<AppUser?>.broadcast();
  final _failures = StreamController<AuthFailure>.broadcast();

  /// 설정하면 다음 linkGoogle 호출이 이 오류를 던진다.
  AuthFailure? nextLinkGoogleFailure;

  final calls = <String>[];

  void _emit(AppUser? user) {
    _user = user;
    _users.add(user);
  }

  /// 브라우저 로그인 오류가 나중에 도착하는 상황을 흉내 낸다.
  void emitFailure(AuthFailure failure) => _failures.add(failure);

  @override
  AppUser? get currentUser => _user;

  @override
  Stream<AppUser?> watchUser() => _users.stream;

  @override
  Stream<AuthFailure> watchFailures() => _failures.stream;

  @override
  Future<void> signInAnonymously() async {
    calls.add('signInAnonymously');
    _emit(const AppUser(id: 'anon', isAnonymous: true));
  }

  @override
  Future<void> signInWithGoogle() async {
    calls.add('signInWithGoogle');
    _emit(
      const AppUser(
        id: 'google-user',
        isAnonymous: false,
        linkedProviders: {SocialProvider.google},
      ),
    );
  }

  @override
  Future<void> signInWithKakao() async => calls.add('signInWithKakao');

  @override
  Future<void> linkGoogle() async {
    calls.add('linkGoogle');
    final failure = nextLinkGoogleFailure;
    if (failure != null) {
      nextLinkGoogleFailure = null;
      throw failure;
    }
    _emit(
      AppUser(
        id: _user!.id,
        isAnonymous: false,
        linkedProviders: {..._user!.linkedProviders, SocialProvider.google},
      ),
    );
  }

  @override
  Future<void> linkKakao() async => calls.add('linkKakao');

  @override
  Future<void> signOut() async {
    calls.add('signOut');
    _emit(null);
  }
}
