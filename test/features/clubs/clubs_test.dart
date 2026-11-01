import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hiking_app/features/auth/domain/app_user.dart';
import 'package:hiking_app/features/auth/domain/profile.dart';
import 'package:hiking_app/features/clubs/domain/club.dart';

import '../../helpers/pump_app.dart';
import '../auth/fake_auth_repository.dart';
import '../auth/fake_profile_remote.dart';
import 'fake_club_remote.dart';

void main() {
  group('규칙', () {
    test('동호회 이름은 2~20자', () {
      expect(clubNameError('금정산 새벽산행'), isNull);
      expect(clubNameError(' 산 '), isNotNull);
      expect(clubNameError('가' * 21), isNotNull);
    });

    test('서버의 관계 값을 읽고, 50명이면 가득 찬 것으로 본다', () {
      expect(ClubStatus.parse('other_club'), ClubStatus.otherClub);
      expect(ClubStatus.parse(null), ClubStatus.none);
      expect(ClubStatus.leader.isMember, isTrue);
      expect(ClubStatus.pending.isMember, isFalse);
      const full = ClubSummary(
        id: 'c',
        name: '산',
        memberCount: clubMaxMembers,
        seasonCompletions: 0,
      );
      expect(full.isFull, isTrue);
    });

    test('하루가 지난 일정은 지난 일정이다', () {
      final e = ClubEvent(
        id: 1,
        title: '정기 산행',
        startsAt: DateTime(2026, 11, 1, 8),
        going: 0,
        notGoing: 0,
      );
      expect(e.isPast(DateTime(2026, 11, 1, 20)), isFalse);
      expect(e.isPast(DateTime(2026, 11, 2, 9)), isTrue);
    });
  });

  group('화면', () {
    FakeAuthRepository signedIn() => FakeAuthRepository(
      user: const AppUser(id: 'u1', provider: SocialProvider.google),
    );

    void tallScreen(WidgetTester tester) {
      tester.view.physicalSize = const Size(800, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
    }

    Future<void> settle(WidgetTester tester) async {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 300)),
      );
      await tester.pumpAndSettle();
    }

    Future<void> openClubs(
      WidgetTester tester,
      FakeClubRemote clubs, {
      FakeProfileRemote? profiles,
    }) async {
      tallScreen(tester);
      await pumpApp(
        tester,
        authRepository: signedIn(),
        clubs: clubs,
        profiles: profiles,
      );
      await settle(tester);
      await tester.tap(find.text('동호회').last);
      await settle(tester);
    }

    testWidgets('소속이 없으면 동호회를 찾아 가입 신청하고, 승인 전에는 취소할 수 있다', (tester) async {
      final clubs = FakeClubRemote()
        ..addClub('금정산 새벽산행', region: '부산 금정구', completions: 42)
        ..addClub('승학산 노을회', region: '부산 사하구');
      await openClubs(tester, clubs);

      expect(find.text('아직 소속된 동호회가 없어요'), findsOneWidget);
      expect(
        find.textContaining('부산 금정구 · 회원 4/50 · 이번 시즌 완등 42회'),
        findsOneWidget,
      );

      await tester.tap(find.text('금정산 새벽산행'));
      await settle(tester);
      // 회원이 아니면 회원 목록·공지·일정은 보이지 않는다.
      expect(find.text('회원 목록·공지·일정은 회원만 볼 수 있어요'), findsOneWidget);
      await tester.tap(find.text('가입 신청하기'));
      await settle(tester);

      expect(clubs.pendingClubId, isNotNull);
      expect(find.text('가입 신청 취소하기'), findsOneWidget);
      await tester.tap(find.text('가입 신청 취소하기'));
      await settle(tester);
      expect(clubs.pendingClubId, isNull);
    });

    testWidgets('동호회를 만들면 개설비(시연용)를 한 번 결제하고 내가 클럽장이 된다', (tester) async {
      final clubs = FakeClubRemote();
      await openClubs(tester, clubs);

      await tester.tap(find.text('동호회 만들기'));
      await settle(tester);
      expect(find.textContaining('시연용 결제라 실제로 돈이 나가지 않아요'), findsOneWidget);

      await tester.enterText(find.byType(TextField).at(0), '산');
      await tester.pump();
      expect(find.text('동호회 이름은 2~20자로 정해 주세요'), findsOneWidget);
      await tester.enterText(find.byType(TextField).at(0), '금정산 새벽산행');
      await tester.enterText(find.byType(TextField).at(2), '부산 금정구');
      await tester.pump();
      await tester.tap(find.text('$clubOpeningPriceLabel 결제하고 만들기'));
      await settle(tester);

      expect(clubs.myClubId, isNotNull);
      expect(find.text('동호회를 만들었어요'), findsOneWidget);
      // 동호회 탭의 내 클럽으로 돌아와 클럽장 도구가 보인다.
      expect(find.text('금정산 새벽산행'), findsOneWidget);
      expect(find.text('가입 신청'), findsOneWidget);
      expect(find.text('공지 쓰기'), findsOneWidget);
    });

    testWidgets('회원은 공지를 보고 일정에 참석으로 답하고, 회원 목록을 본다', (tester) async {
      final clubs = FakeClubRemote();
      final id = clubs.addClub('금정산 새벽산행', mine: true);
      clubs.addEvent(
        id,
        ClubEvent(
          id: 99,
          title: '11월 정기 산행',
          startsAt: DateTime.now().add(const Duration(days: 5)),
          place: '범어사 매표소 앞',
          going: 3,
          notGoing: 1,
        ),
      );
      await openClubs(tester, clubs);

      expect(find.text('아직 공지가 없어요'), findsOneWidget);
      expect(find.text('공지 쓰기'), findsNothing); // 클럽장만 쓴다.

      await tester.tap(find.text('일정'));
      await settle(tester);
      expect(find.text('11월 정기 산행'), findsOneWidget);
      await tester.tap(find.text('참석 3'));
      await settle(tester);
      expect(find.text('참석 4'), findsOneWidget);

      await tester.tap(find.text('회원'));
      await settle(tester);
      expect(find.text('등산객AB12#0369 (나)'), findsOneWidget);
      expect(find.textContaining('클럽장 · 이번 시즌 완등'), findsOneWidget);
      expect(find.text('동호회 나가기'), findsOneWidget);
    });

    testWidgets('클럽장은 가입 신청을 승인하고, 공지를 올린다', (tester) async {
      final clubs = FakeClubRemote();
      clubs.addClub(
        '금정산 새벽산행',
        leader: true,
        requests: [
          ClubJoinRequest(
            id: 7,
            nickname: '산딸기',
            nicknameTag: '0021',
            region: '부산 금정구',
            requestedAt: DateTime(2026, 10, 30),
          ),
        ],
      );
      await openClubs(tester, clubs);

      expect(find.text('1'), findsOneWidget); // 기다리는 신청 수
      await tester.tap(find.text('가입 신청'));
      await settle(tester);
      expect(find.text('산딸기#0021'), findsOneWidget);
      await tester.tap(find.text('승인'));
      await settle(tester);
      expect(find.text('회원으로 받았어요'), findsOneWidget);
      expect(find.text('기다리는 가입 신청이 없어요'), findsOneWidget);

      await tester.pageBack();
      await settle(tester);
      await tester.tap(find.text('공지 쓰기'));
      await settle(tester);
      await tester.enterText(find.byType(TextField).last, '이번 주는 쉬어요');
      // 앞의 "회원으로 받았어요" 알림이 버튼을 가리지 않게 치운다.
      tester
          .state<ScaffoldMessengerState>(find.byType(ScaffoldMessenger).first)
          .removeCurrentSnackBar();
      await tester.pump();
      await tester.tap(find.text('올리기'));
      await settle(tester);
      expect(find.text('공지를 올렸어요'), findsOneWidget);
      expect(find.text('이번 주는 쉬어요'), findsOneWidget);
      expect(find.byType(TextField), findsNothing); // 시트가 닫혔다
    });

    testWidgets('클럽 랭킹은 누구나 전체를 보고, 내 클럽을 표시한다', (tester) async {
      final clubs = FakeClubRemote()
        ..addClub('승학산 노을회', completions: 12)
        ..addClub('금정산 새벽산행', completions: 40, mine: true)
        ..addClub('장산 주말반', completions: 3);
      await openClubs(tester, clubs);
      await tester.tap(find.text('클럽 랭킹'));
      await settle(tester);

      expect(find.text('금정산 새벽산행 (내 클럽)'), findsOneWidget);
      expect(find.text('40회'), findsOneWidget);
      final first = tester.getTopLeft(find.text('금정산 새벽산행 (내 클럽)')).dy;
      final last = tester.getTopLeft(find.text('장산 주말반')).dy;
      expect(first, lessThan(last));
    });

    testWidgets('클럽 랭킹은 이번 시즌과 명예의 전당(모든 시즌 합계)으로 본다', (tester) async {
      final clubs = FakeClubRemote()..addClub('승학산 노을회', completions: 12);
      await openClubs(tester, clubs);
      await tester.tap(find.text('클럽 랭킹'));
      await settle(tester);
      expect(find.text('지난 시즌'), findsNothing);

      await tester.tap(find.text('명예의 전당'));
      await settle(tester);
      expect(find.textContaining('역대 전체'), findsOneWidget);
      expect(clubs.rankingRequests.last, 'all');
    });

    testWidgets('클럽장은 회원 옆 메뉴에서 회원을 내보낸다', (tester) async {
      final clubs = FakeClubRemote()..addClub('금정산 새벽산행', leader: true);
      await openClubs(tester, clubs);
      await tester.tap(find.text('회원'));
      await settle(tester);
      expect(find.text('회원2#0002'), findsOneWidget);

      await tester.tap(
        find.descendant(
          of: find
              .ancestor(of: find.text('회원2#0002'), matching: find.byType(Row))
              .first,
          matching: find.byTooltip('회원 관리'),
        ),
      );
      await settle(tester);
      await tester.tap(find.text('동호회에서 내보내기'));
      await settle(tester);
      expect(find.text('회원2님을 동호회에서 내보낼까요?'), findsOneWidget);
      await tester.tap(find.text('내보내기'));
      await settle(tester);

      expect(find.text('회원2님을 내보냈어요'), findsOneWidget);
      expect(find.text('회원2#0002'), findsNothing);
    });
    testWidgets('공개 프로필에 소속 동호회가 보인다', (tester) async {
      final clubs = FakeClubRemote();
      final id = clubs.addClub('금정산 새벽산행', mine: true);
      final profiles = FakeProfileRemote()
        ..publicProfiles['회원2#0002'] = PublicProfile(
          nickname: '회원2',
          nicknameTag: '0002',
          clubId: id,
          clubName: '금정산 새벽산행',
        );
      await openClubs(tester, clubs, profiles: profiles);
      await tester.tap(find.text('회원'));
      await settle(tester);
      await tester.tap(find.text('회원2#0002'));
      await settle(tester);

      expect(find.text('금정산 새벽산행 동호회'), findsOneWidget);
    });
  });
}
