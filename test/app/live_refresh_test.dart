import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hiking_app/features/auth/domain/app_user.dart';

import '../features/auth/fake_auth_repository.dart';
import '../features/chat/fake_chat_remote.dart';
import '../helpers/pump_app.dart';

void main() {
  Future<void> settle(WidgetTester tester) async {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('내 정보를 보고 있을 때 메시지 요청이 오면 새로고침 없이 바로 보인다', (tester) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final chats = FakeChatRemote();
    await pumpApp(
      tester,
      authRepository: FakeAuthRepository(
        user: const AppUser(id: 'u1', provider: SocialProvider.google),
      ),
      chats: chats,
    );
    await settle(tester);
    await tester.tap(find.text('내 정보'));
    await settle(tester);
    expect(find.text('메시지 요청 1'), findsNothing);

    chats.receiveRequest('고당봉지킴이', '0002', '안녕하세요!');
    // Realtime 신호는 0.3초 모아서 한 번에 다시 받는다.
    await tester.pump(const Duration(milliseconds: 400));
    await settle(tester);
    expect(find.text('메시지 요청 1'), findsOneWidget);
  });

  testWidgets('버전 글자를 5번 누르면 시연용 메뉴가 열린다 (개발 빌드에서는 처음부터 보인다)', (tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pumpApp(
      tester,
      authRepository: FakeAuthRepository(
        user: const AppUser(id: 'u1', provider: SocialProvider.google),
      ),
    );
    await settle(tester);
    await tester.tap(find.text('내 정보'));
    await settle(tester);
    expect(find.textContaining('버전 '), findsOneWidget);
    // 테스트는 개발 빌드(kDebugMode)라 이미 보인다.
    expect(find.text('시연용 기록 다시 만들기 (8개)'), findsOneWidget);
  });
}
