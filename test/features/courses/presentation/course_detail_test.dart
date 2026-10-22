import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hiking_app/app/routes.dart';
import 'package:hiking_app/core/map/route_preview_map.dart';
import 'package:hiking_app/features/auth/domain/app_user.dart';
import 'package:hiking_app/features/courses/domain/competition.dart';

import '../../../helpers/pump_app.dart';
import '../../auth/fake_auth_repository.dart';
import '../fake_competition_remote.dart';
import '../fake_course_remote.dart';

void main() {
  DateTime clock() => DateTime(2026, 10, 20, 12);

  /// 코스 상세 화면을 연다.
  Future<void> openDetail(
    WidgetTester tester,
    FakeCompetitionRemote competition,
  ) async {
    // 랭킹까지 한 화면에 보이도록 세로로 긴 화면을 쓴다.
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pumpApp(
      tester,
      authRepository: FakeAuthRepository(
        user: const AppUser(id: 'u1', provider: SocialProvider.google),
      ),
      courseRemote: FakeCourseRemote([
        testCourse(id: 'a', mountainName: '금정산', name: '범어사 코스'),
      ]),
      competition: competition,
      clock: clock,
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await tester.pumpAndSettle();
    final router = GoRouter.of(tester.element(find.text('등산 기록 시작')));
    router.push(AppRoutes.course('a'));
    await tester.pumpAndSettle();
  }

  testWidgets('코스 정보, 이번 시즌 정복자, 랭킹, 안전 문구를 보여 준다', (tester) async {
    final competition = FakeCompetitionRemote()
      ..stats = const CourseStats(
        completionCount: 42,
        averageAscent: Duration(minutes: 52),
        myBestAscent: Duration(minutes: 47, seconds: 10),
        myCount: 6,
      )
      ..conquerors = const [
        Conqueror(
          courseId: 'a',
          kind: RankingKind.most,
          nickname: '김세민',
          nicknameTag: '0421',
          value: 6,
        ),
        Conqueror(
          courseId: 'a',
          kind: RankingKind.fastest,
          nickname: '새벽등산러',
          nicknameTag: '0005',
          value: 1720,
        ),
      ]
      ..rankings[(RankingKind.most, false)] = [
        entry(1, '김세민', 6, isMe: true),
        entry(2, '고당봉지킴이', 5),
      ];
    await openDetail(tester, competition);

    expect(find.text('금정산 범어사 코스'), findsOneWidget);
    // 코스 전체 경로 지도 (들머리 → 정상)
    expect(find.byType(RoutePreviewMap), findsOneWidget);
    expect(find.text('▲ 금정산 정상'), findsOneWidget);
    expect(find.text('완주 기록 42회 · 평균 52분'), findsOneWidget);
    expect(find.text('내 완주 6회 · 최고 0:47:10'), findsOneWidget);

    expect(find.text('2026 하반기 정복자'), findsOneWidget);
    expect(find.text('새벽등산러#0005'), findsOneWidget);
    expect(find.text('0:28:40'), findsOneWidget);

    expect(find.text('김세민#1001 (나)'), findsOneWidget);
    expect(find.text('고당봉지킴이#1002'), findsOneWidget);
    expect(find.textContaining('무리한 속도 경쟁은 사고로'), findsOneWidget);
  });

  testWidgets('명예의 전당·최단시간으로 바꾸면 그 랭킹을 요청하고, 순위 밖 내 기록은 따로 보인다', (
    tester,
  ) async {
    final competition = FakeCompetitionRemote()
      ..rankings[(RankingKind.fastest, true)] = [
        for (var r = 1; r <= 10; r++) entry(r, '등산러$r', 1500 + r * 60),
        entry(13, '김세민', 2400, isMe: true),
      ];
    await openDetail(tester, competition);

    await tester.tap(find.text('명예의 전당'));
    await tester.pumpAndSettle();
    // "최단시간"은 정복자 카드 제목에도 있어서, 아래쪽 탭을 누른다.
    await tester.tap(find.text('최단시간').last);
    await tester.pumpAndSettle();

    expect(competition.requests.last, 'a fastest alltime');
    await tester.scrollUntilVisible(find.text('김세민#1013 (나)'), 200);
    expect(find.text('···'), findsOneWidget);
    expect(find.text('0:40:00'), findsOneWidget);
  });

  testWidgets('이번 시즌 기록이 없으면 첫 정복자가 되어 보라고 안내한다', (tester) async {
    await openDetail(tester, FakeCompetitionRemote());

    expect(find.text('이번 시즌 첫 정복자가 되어 보세요'), findsOneWidget);
    expect(find.text('아직 완주 기록이 없어요. 첫 완주에 도전해 보세요.'), findsOneWidget);
  });

  testWidgets('인터넷이 안 되면 다시 시도할 수 있다', (tester) async {
    final competition = FakeCompetitionRemote()
      ..failWith = const SocketException('offline');
    await openDetail(tester, competition);

    expect(find.text('인터넷에 연결되면 랭킹을 볼 수 있어요'), findsOneWidget);

    competition.failWith = null;
    competition.rankings[(RankingKind.most, false)] = [entry(1, '고당봉지킴이', 5)];
    await tester.tap(find.text('다시 시도'));
    await tester.pumpAndSettle();

    expect(find.text('고당봉지킴이#1001'), findsOneWidget);
  });
}
