import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hiking_app/app/routes.dart';
import 'package:hiking_app/features/auth/domain/app_user.dart';
import 'package:hiking_app/features/chat/domain/chat.dart';
import 'package:hiking_app/features/chat/presentation/chat_screen.dart';

import '../../helpers/pump_app.dart';
import '../auth/fake_auth_repository.dart';
import '../clubs/fake_club_remote.dart';
import 'fake_chat_remote.dart';

ChatMessage msg(int id, String who, DateTime at, {bool mine = false}) =>
    ChatMessage(
      id: id,
      senderNickname: who,
      senderTag: '0001',
      isMine: mine,
      body: '메시지 $id',
      createdAt: at,
    );

void main() {
  group('말풍선 배치', () {
    final t = DateTime(2026, 11, 1, 9);

    test('날짜가 바뀌면 구분선, 같은 사람이 5분 안에 이어 보내면 이름은 처음만·시각은 마지막만', () {
      final items = buildChatItems([
        msg(1, '산딸기', t),
        msg(2, '산딸기', t.add(const Duration(minutes: 2))),
        msg(3, '나', t.add(const Duration(minutes: 3)), mine: true),
        msg(4, '산딸기', t.add(const Duration(minutes: 20))),
        msg(5, '산딸기', t.add(const Duration(days: 1))),
      ]);
      String describe(ChatItem i) => switch (i) {
        ChatDateDivider() => '날짜',
        ChatUnreadDivider() => '읽음',
        ChatBubble(:final message, :final showSender, :final showTime) =>
          '${message.id}${showSender ? '이름' : ''}${showTime ? '시각' : ''}',
      };
      expect(items.map(describe), [
        '날짜',
        '1이름',
        '2시각',
        '3시각',
        '4이름시각',
        '날짜',
        '5이름시각',
      ]);
    });

    test('마지막으로 읽은 뒤 다른 사람이 보낸 첫 메시지 앞에 "여기까지 읽었어요"', () {
      final items = buildChatItems([
        msg(1, '산딸기', t),
        msg(2, '나', t.add(const Duration(minutes: 10)), mine: true),
        msg(3, '산딸기', t.add(const Duration(minutes: 20))),
      ], lastReadAt: t.add(const Duration(minutes: 5)));
      final at = items.indexWhere((i) => i is ChatUnreadDivider);
      expect((items[at + 1] as ChatBubble).message.id, 3);
      expect(items.whereType<ChatUnreadDivider>(), hasLength(1));
    });

    test('지운 메시지·가린 메시지는 내용 대신 안내를 보여 준다', () {
      final deleted = ChatMessage(
        id: 1,
        senderNickname: '산딸기',
        senderTag: '0001',
        isMine: false,
        createdAt: t,
        state: MessageState.deleted,
      );
      expect(deleted.displayText, '삭제된 메시지예요');
      expect(MessageState.parse('hidden'), MessageState.hidden);
      expect(DirectStatus.parse('blocked').closed, isTrue);
    });
  });

  group('화면', () {
    FakeAuthRepository signedIn() => FakeAuthRepository(
      user: const AppUser(id: 'u1', provider: SocialProvider.google),
    );

    void tallScreen(WidgetTester tester) {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
    }

    Future<void> settle(WidgetTester tester) async {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 300)),
      );
      await tester.pumpAndSettle();
    }

    Future<void> open(
      WidgetTester tester,
      FakeChatRemote chats, {
      FakeClubRemote? clubs,
    }) async {
      tallScreen(tester);
      await pumpApp(
        tester,
        authRepository: signedIn(),
        chats: chats,
        clubs: clubs,
      );
      await settle(tester);
    }

    Future<void> push(
      WidgetTester tester,
      String location, {
      Object? extra,
    }) async {
      GoRouter.of(tester.element(find.text('등산 기록 시작')))
          .push(location, extra: extra);
      await settle(tester);
    }

    testWidgets('처음 보내는 1:1 메시지는 요청이 되고, 상대가 수락하기 전에는 더 보낼 수 없다', (
      tester,
    ) async {
      final chats = FakeChatRemote();
      await open(tester, chats);
      await push(
        tester,
        AppRoutes.chatNew,
        extra: const ChatTarget(nickname: '산딸기', tag: '0021'),
      );

      expect(
        find.textContaining('첫 메시지를 보내면 산딸기님에게 메시지 요청이 가요'),
        findsOneWidget,
      );
      await tester.enterText(find.byType(TextField), '범어사 코스 주차는 어디에 하세요?');
      await tester.pump();
      await tester.tap(find.byTooltip('보내기'));
      await settle(tester);

      expect(find.text('범어사 코스 주차는 어디에 하세요?'), findsOneWidget);
      expect(find.textContaining('메시지 요청을 보냈어요'), findsOneWidget);
      expect(find.text('상대가 수락하면 이어서 보낼 수 있어요'), findsOneWidget);
    });

    testWidgets('받은 메시지 요청은 내 정보 → 메시지에서 보고, 수락하면 대화를 이어 간다', (tester) async {
      final chats = FakeChatRemote();
      chats.addRoom(
        (id) => ChatRoomInfo(
          roomId: id,
          kind: ChatKind.direct,
          title: '고당봉지킴이',
          otherNickname: '고당봉지킴이',
          otherTag: '0002',
          status: DirectStatus.pending,
          iAmRequester: false,
          iAmLeader: false,
          canSend: false,
        ),
        lines: [('고당봉지킴이', '0002', '최단시간 기록 비결이 궁금해요!', false)],
      );
      await open(tester, chats);
      await tester.tap(find.text('내 정보'));
      await settle(tester);
      expect(find.text('메시지 요청 1'), findsOneWidget);

      await tester.tap(find.text('메시지'));
      await settle(tester);
      expect(find.text('메시지 요청 1'), findsOneWidget);
      await tester.tap(find.text('고당봉지킴이#0002'));
      await settle(tester);

      expect(find.textContaining('수락하면 대화할 수 있어요'), findsOneWidget);
      await tester.tap(find.text('수락'));
      await settle(tester);
      expect(find.text('요청을 수락했어요. 이제 대화할 수 있어요'), findsOneWidget);

      await tester.enterText(find.byType(TextField), '아침 일찍 출발해요');
      // "요청을 수락했어요" 알림이 보내기 버튼을 가리지 않게 치운다.
      tester
          .state<ScaffoldMessengerState>(find.byType(ScaffoldMessenger).first)
          .removeCurrentSnackBar();
      await tester.pump();
      await tester.tap(find.byTooltip('보내기'));
      await settle(tester);
      expect(find.text('아침 일찍 출발해요'), findsOneWidget);
      // 보냈으면 입력칸이 비고, 글은 말풍선에만 있다.
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller?.text,
        isEmpty,
      );
    });

    testWidgets('새 메시지 신호가 오면 바로 보이고, 내 메시지는 길게 눌러 지운다', (tester) async {
      final chats = FakeChatRemote();
      final id = chats.addRoom(
        (id) => ChatRoomInfo(
          roomId: id,
          kind: ChatKind.direct,
          title: '산딸기',
          otherNickname: '산딸기',
          otherTag: '0021',
          status: DirectStatus.accepted,
          iAmRequester: true,
          iAmLeader: false,
          canSend: true,
        ),
        lines: [('등산객AB12', '0369', '내일 같이 가요', true)],
      );
      await open(tester, chats);
      await push(tester, AppRoutes.chat(id));

      chats.receive(id, '산딸기', '0021', '좋아요! 7시에 봬요');
      await settle(tester);
      expect(find.text('좋아요! 7시에 봬요'), findsOneWidget);

      await tester.longPress(find.text('내일 같이 가요'));
      await settle(tester);
      await tester.tap(find.text('지우기'));
      await settle(tester);
      expect(find.text('삭제된 메시지예요'), findsOneWidget);
    });

    testWidgets('동호회 탭 위쪽 채팅 아이콘을 누르면 바로 채팅방이 열린다', (tester) async {
      final clubs = FakeClubRemote();
      final clubId = clubs.addClub('금정산 새벽산행', mine: true);
      final chats = FakeChatRemote();
      chats.addRoom(
        (id) => ChatRoomInfo(
          roomId: id,
          kind: ChatKind.club,
          clubId: clubId,
          title: '금정산 새벽산행',
          status: DirectStatus.accepted,
          iAmRequester: false,
          iAmLeader: false,
          canSend: true,
        ),
        lines: [('회원1', '0001', '이번 주 토요일 5시 범어사!', false)],
      );
      await open(tester, chats, clubs: clubs);
      await tester.tap(find.text('동호회').last);
      await settle(tester);
      expect(find.text('채팅'), findsNothing); // 동호회 상세 안의 채팅 칸은 없앴다
      await tester.tap(find.byTooltip('동호회 채팅'));
      await settle(tester);
      expect(find.text('이번 주 토요일 5시 범어사!'), findsOneWidget);
      expect(find.text('회원1#0001'), findsOneWidget);
    });
  });
}
