import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hiking_app/features/achievements/domain/achievements.dart';
import 'package:hiking_app/features/auth/domain/app_user.dart';
import 'package:hiking_app/features/courses/domain/competition.dart';
import 'package:hiking_app/features/courses/domain/course.dart';

import '../../../helpers/course_walk.dart';
import '../../../helpers/pump_app.dart';
import '../../auth/fake_auth_repository.dart';
import '../../courses/fake_competition_remote.dart';
import '../../courses/fake_course_remote.dart';
import '../fake_achievement_remote.dart';

Course beomeosa() {
  final c = loadCourse('geumjeongsan-beomeosa');
  return Course(
    id: 'beomeosa',
    mountainName: '금정산',
    name: '범어사 코스',
    startName: '범어사',
    endName: '고당봉',
    distanceM: 2800,
    path: c.path,
    summit: c.summit,
  );
}

void main() {
  FakeAuthRepository signedIn() => FakeAuthRepository(
    user: const AppUser(id: 'u1', provider: SocialProvider.google),
  );

  void tallScreen(WidgetTester tester) {
    tester.view.physicalSize = const Size(800, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump();
    }
    await tester.pumpAndSettle();
  }

  Future<void> openAchievements(
    WidgetTester tester, {
    required FakeAchievementRemote achievements,
    FakeCompetitionRemote? competition,
  }) async {
    tallScreen(tester);
    await pumpApp(
      tester,
      authRepository: signedIn(),
      courseRemote: FakeCourseRemote([beomeosa()]),
      competition: competition,
      achievements: achievements,
      clock: () => DateTime(2026, 10, 27, 12),
    );
    await settle(tester);
    await tester.tap(find.text('내 정보'));
    await settle(tester);
    expect(find.text('업적'), findsOneWidget);
    await tester.tap(find.text('업적'));
    await settle(tester);
  }

  testWidgets('내 정보에서 업적으로 들어가 배지·시즌 정복 기록을 보고, 배지를 눌러 조건을 본다', (tester) async {
    final competition = FakeCompetitionRemote()
      ..myCompletions = [
        MyCompletion(
          courseId: 'beomeosa',
          ascent: const Duration(minutes: 50),
          completedAt: DateTime(2026, 4, 1),
        ),
      ];
    final achievements = FakeAchievementRemote()
      ..leadRuns = [
        LeadRun(
          courseId: 'beomeosa',
          scope: '2026-H1',
          kind: RankingKind.most,
          startedAt: DateTime(2026, 4, 1),
          endedAt: const Season(2026, 1).end,
          seasonFinal: true,
        ),
      ];

    await openAchievements(
      tester,
      achievements: achievements,
      competition: competition,
    );

    expect(find.text('배지 31개 중 5개를 얻었어요 · 시즌 정복 1번'), findsOneWidget);
    // 완등 1 + 첫 정복(최다완등) 1 + 1위 지키기 3 (4월 1일 ~ 6월 30일, 90일 넘게)
    for (final group in BadgeGroup.values) {
      expect(find.text(group.label), findsOneWidget);
    }
    expect(find.text('최다완등 정복자 · 2026 상반기'), findsOneWidget);
    expect(find.text('금정산 범어사 코스'), findsOneWidget);

    await tester.tap(find.text('정상에 서다'));
    await tester.pumpAndSettle();
    expect(find.text('첫 완등'), findsOneWidget);
    expect(find.text('2026년 4월 1일'), findsWidgets);
    expect(find.text('완등 10번'), findsOneWidget);
  });

  testWidgets('인터넷이 없으면 서버 배지는 확인할 수 없다고 알린다', (tester) async {
    await openAchievements(
      tester,
      achievements: FakeAchievementRemote()..offline = true,
    );
    expect(find.text('인터넷에 연결되면 완등·정복·리뷰 배지를 확인할 수 있어요'), findsOneWidget);
    expect(find.text('확인할 수 없음'), findsNWidgets(5));
  });
}
