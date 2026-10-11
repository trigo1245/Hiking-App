import 'package:flutter_test/flutter_test.dart';
import 'package:hiking_app/features/auth/domain/app_user.dart';

import '../features/auth/fake_auth_repository.dart';
import '../helpers/pump_app.dart';

void main() {
  testWidgets('하단 탭으로 홈 / 기록 / 내 정보 화면을 오갈 수 있다', (tester) async {
    await pumpApp(
      tester,
      authRepository: FakeAuthRepository(
        user: const AppUser(id: 'anon', isAnonymous: true),
      ),
    );

    // 처음에는 홈 화면
    expect(find.text('홈 화면을 준비하고 있어요'), findsOneWidget);

    await tester.tap(find.text('기록'));
    await tester.pumpAndSettle();
    expect(find.text('아직 등산 기록이 없어요'), findsOneWidget);

    await tester.tap(find.text('내 정보').last);
    await tester.pumpAndSettle();
    expect(find.text('계정을 연결해 주세요'), findsOneWidget);

    await tester.tap(find.text('홈').last);
    await tester.pumpAndSettle();
    expect(find.text('홈 화면을 준비하고 있어요'), findsOneWidget);
  });
}
