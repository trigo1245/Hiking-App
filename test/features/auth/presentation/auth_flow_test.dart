import 'package:flutter_test/flutter_test.dart';
import 'package:hiking_app/features/auth/domain/app_user.dart';
import 'package:hiking_app/features/auth/domain/auth_failure.dart';

import '../../../helpers/pump_app.dart';
import '../fake_auth_repository.dart';

void main() {
  testWidgets('로그인하지 않았으면 로그인 화면이 뜨고, 익명으로 시작하면 홈으로 간다', (tester) async {
    final repo = FakeAuthRepository();
    await pumpApp(tester, authRepository: repo);

    expect(find.text('카카오로 시작하기'), findsOneWidget);
    expect(find.text('구글로 시작하기'), findsOneWidget);

    await tester.tap(find.text('로그인 없이 시작하기'));
    await tester.pumpAndSettle();

    expect(repo.calls, ['signInAnonymously']);
    expect(find.text('홈 화면을 준비하고 있어요'), findsOneWidget);
  });

  testWidgets('구글로 시작하면 홈으로 간다', (tester) async {
    final repo = FakeAuthRepository();
    await pumpApp(tester, authRepository: repo);

    await tester.tap(find.text('구글로 시작하기'));
    await tester.pumpAndSettle();

    expect(repo.calls, ['signInWithGoogle']);
    expect(find.text('홈 화면을 준비하고 있어요'), findsOneWidget);
  });

  Future<FakeAuthRepository> openMyInfoAsAnonymous(WidgetTester tester) async {
    final repo = FakeAuthRepository(
      user: const AppUser(id: 'anon', isAnonymous: true),
    );
    await pumpApp(tester, authRepository: repo);
    await tester.tap(find.text('내 정보').last);
    await tester.pumpAndSettle();
    return repo;
  }

  testWidgets('익명 사용자가 구글 계정을 연결하면 로그아웃 버튼이 생긴다', (tester) async {
    final repo = await openMyInfoAsAnonymous(tester);

    expect(find.text('등산객AB12'), findsOneWidget);
    expect(find.text('로그아웃'), findsNothing);

    await tester.tap(find.text('구글 계정 연결하기'));
    await tester.pumpAndSettle();

    expect(repo.calls, ['linkGoogle']);
    expect(find.text('구글 계정으로 로그인했어요'), findsOneWidget);
    expect(find.text('로그아웃'), findsOneWidget);
  });

  testWidgets('이미 가입된 구글 계정이면 그 계정으로 로그인할지 묻는다', (tester) async {
    final repo = await openMyInfoAsAnonymous(tester);
    repo.nextLinkGoogleFailure = const AuthFailure(
      AuthFailureType.identityAlreadyExists,
    );

    await tester.tap(find.text('구글 계정 연결하기'));
    await tester.pumpAndSettle();
    expect(find.text('이미 가입된 계정이 있어요'), findsOneWidget);

    await tester.tap(find.text('그 계정으로 로그인하기'));
    await tester.pumpAndSettle();
    expect(repo.calls, ['linkGoogle', 'signInWithGoogle']);
  });

  testWidgets('카카오 연결 결과가 나중에 오류로 도착해도 같은 안내를 띄운다', (tester) async {
    final repo = await openMyInfoAsAnonymous(tester);

    await tester.tap(find.text('카카오 계정 연결하기'));
    await tester.pumpAndSettle();
    repo.emitFailure(const AuthFailure(AuthFailureType.identityAlreadyExists));
    await tester.pumpAndSettle();

    expect(find.textContaining('이 카카오 계정으로'), findsOneWidget);
  });

  testWidgets('로그아웃하면 로그인 화면으로 돌아간다', (tester) async {
    final repo = FakeAuthRepository(
      user: const AppUser(
        id: 'u1',
        isAnonymous: false,
        linkedProviders: {SocialProvider.kakao},
      ),
    );
    await pumpApp(tester, authRepository: repo);
    await tester.tap(find.text('내 정보').last);
    await tester.pumpAndSettle();

    expect(find.text('구글 계정도 연결하기'), findsOneWidget);
    await tester.tap(find.text('로그아웃'));
    await tester.pumpAndSettle();

    expect(find.text('카카오로 시작하기'), findsOneWidget);
  });
}
