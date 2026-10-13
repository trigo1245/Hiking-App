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

  final calls = <String>[];

  void _emit(AppUser? user) {
    _user = user;
    _users.add(user);
  }

  /// 브라우저 로그인 결과가 나중에 도착하는 상황을 흉내 낸다.
  void completeKakaoSignIn() =>
      _emit(const AppUser(id: 'kakao-user', provider: SocialProvider.kakao));

  void emitFailure(AuthFailure failure) => _failures.add(failure);

  @override
  AppUser? get currentUser => _user;

  @override
  Stream<AppUser?> watchUser() => _users.stream;

  @override
  Stream<AuthFailure> watchFailures() => _failures.stream;

  @override
  Future<void> signInWithGoogle() async {
    calls.add('signInWithGoogle');
    _emit(const AppUser(id: 'google-user', provider: SocialProvider.google));
  }

  @override
  Future<void> signInWithKakao() async => calls.add('signInWithKakao');

  @override
  Future<void> signOut() async {
    calls.add('signOut');
    _emit(null);
  }
}
