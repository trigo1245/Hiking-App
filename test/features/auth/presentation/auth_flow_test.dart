import 'package:flutter_test/flutter_test.dart';
import 'package:hiking_app/features/auth/domain/app_user.dart';
import 'package:hiking_app/features/auth/domain/auth_failure.dart';

import '../../../helpers/pump_app.dart';
import '../fake_auth_repository.dart';

void main() {
  testWidgets('로그인하지 않았으면 카카오·구글 버튼만 있는 로그인 화면이 뜬다', (tester) async {
    await pumpApp(tester, authRepository: FakeAuthRepository());

    expect(find.text('카카오로 시작하기'), findsOneWidget);
    expect(find.text('구글로 시작하기'), findsOneWidget);
    expect(find.text('로그인 없이 시작하기'), findsNothing);
  });

  testWidgets('구글로 시작하면 홈으로 가고 내 정보에 구글 계정이 보인다', (tester) async {
    final repo = FakeAuthRepository();
    await pumpApp(tester, authRepository: repo);

    await tester.tap(find.text('구글로 시작하기'));
    await tester.pumpAndSettle();

    expect(repo.calls, ['signInWithGoogle']);
    expect(find.text('홈 화면을 준비하고 있어요'), findsOneWidget);

    await tester.tap(find.text('내 정보').last);
    await tester.pumpAndSettle();
    expect(find.text('등산객AB12'), findsOneWidget);
    expect(find.text('구글 계정으로 로그인했어요'), findsOneWidget);
  });

  testWidgets('카카오 로그인 결과가 나중에 도착하면 홈으로 간다', (tester) async {
    final repo = FakeAuthRepository();
    await pumpApp(tester, authRepository: repo);

    await tester.tap(find.text('카카오로 시작하기'));
    await tester.pumpAndSettle();
    expect(repo.calls, ['signInWithKakao']);
    expect(find.text('카카오로 시작하기'), findsOneWidget);

    repo.completeKakaoSignIn();
    await tester.pumpAndSettle();
    expect(find.text('홈 화면을 준비하고 있어요'), findsOneWidget);
  });

  testWidgets('카카오 로그인 오류가 나중에 도착하면 안내 문구를 띄운다', (tester) async {
    final repo = FakeAuthRepository();
    await pumpApp(tester, authRepository: repo);

    repo.emitFailure(const AuthFailure(AuthFailureType.network));
    await tester.pumpAndSettle();

    expect(find.text('인터넷 연결을 확인하고 다시 시도해 주세요.'), findsOneWidget);
  });

  testWidgets('내 정보에는 계정 연결 버튼이 없고, 로그아웃하면 로그인 화면으로 돌아간다', (tester) async {
    final repo = FakeAuthRepository(
      user: const AppUser(id: 'u1', provider: SocialProvider.kakao),
    );
    await pumpApp(tester, authRepository: repo);
    await tester.tap(find.text('내 정보').last);
    await tester.pumpAndSettle();

    expect(find.textContaining('연결하기'), findsNothing);

    await tester.tap(find.text('로그아웃'));
    await tester.pumpAndSettle();

    expect(repo.calls, ['signOut']);
    expect(find.text('카카오로 시작하기'), findsOneWidget);
  });
}
