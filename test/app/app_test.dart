import 'package:flutter_test/flutter_test.dart';
import 'package:hiking_app/features/auth/domain/app_user.dart';

import '../features/auth/fake_auth_repository.dart';
import '../helpers/pump_app.dart';

void main() {
  testWidgets('하단 탭으로 홈 / 기록 / 내 정보 화면을 오갈 수 있다', (tester) async {
    await pumpApp(
      tester,
      authRepository: FakeAuthRepository(
        user: const AppUser(id: 'u1', provider: SocialProvider.kakao),
      ),
    );

    // 처음에는 홈 화면
    expect(find.text('산, 코스 이름으로 검색'), findsOneWidget);

    await tester.tap(find.text('기록'));
    await tester.pumpAndSettle();
    expect(find.text('아직 등산 기록이 없어요'), findsOneWidget);

    await tester.tap(find.text('내 정보').last);
    await tester.pumpAndSettle();
    expect(find.text('카카오 계정으로 로그인했어요'), findsOneWidget);

    await tester.tap(find.text('홈').last);
    await tester.pumpAndSettle();
    expect(find.text('산, 코스 이름으로 검색'), findsOneWidget);
  });
}
