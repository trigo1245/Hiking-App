import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hiking_app/app/routes.dart';
import 'package:hiking_app/core/database/app_database.dart';
import 'package:hiking_app/features/activities/data/demo_activity_generator.dart';
import 'package:hiking_app/features/auth/domain/app_user.dart';
import 'package:hiking_app/features/courses/domain/competition.dart';
import 'package:hiking_app/features/courses/domain/course.dart';
import 'package:hiking_app/features/courses/domain/review.dart';
import 'package:hiking_app/features/recording/data/recording_repository.dart';

import '../helpers/course_walk.dart';
import '../helpers/pump_app.dart';
import 'auth/fake_auth_repository.dart';
import 'courses/fake_competition_remote.dart';
import 'courses/fake_course_remote.dart';
import 'fakes_phase2.dart';

/// 실제 범어사 코스 (id는 테스트용)
Course beomeosa() {
  final c = loadCourse('geumjeongsan-beomeosa');
  return Course(
    id: 'beomeosa',
    mountainName: '금정산',
    name: '범어사 코스',
    startName: '범어사',
    endName: '고당봉',
    distanceM: 2800,
    officialTimeMin: 50,
    officialDifficulty: '하',
    path: c.path,
    summit: c.summit,
  );
}

void main() {
  DateTime clock() => DateTime(2026, 10, 20, 12);

  FakeAuthRepository signedIn() => FakeAuthRepository(
    user: const AppUser(id: 'u1', provider: SocialProvider.google),
  );

  /// 세로로 긴 화면 (스크롤 없이 아래쪽까지 그려지도록)
  void tallScreen(WidgetTester tester) {
    tester.view.physicalSize = const Size(800, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  /// DB 작업이 끝나도록 실제 시간으로 잠깐 기다린다.
  Future<void> settle(WidgetTester tester) async {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 500)),
    );
    await tester.pumpAndSettle();
  }

  Future<void> push(WidgetTester tester, String location) async {
    GoRouter.of(tester.element(find.text('등산 기록 시작'))).push(location);
    await settle(tester);
  }

  /// 범어사 코스를 완주한 시연용 기록을 하나 만든 DB
  Future<(AppDatabase, String)> dbWithHike(WidgetTester tester) async {
    final db = testDatabase();
    late List<String> ids;
    await tester.runAsync(() async {
      ids = await DemoActivityGenerator(RecordingRepository(db))
          .createDemoHikes(courses: [beomeosa()], userId: 'u1', now: clock());
    });
    return (db, ids.last);
  }

  group('기록 상세', () {
    testWidgets('기록 카드를 누르면 지도·수치·완주한 코스가 보이고, 일반 사용자에게는 프리미엄 안내가 뜬다', (
      tester,
    ) async {
      tallScreen(tester);
      final (db, _) = await dbWithHike(tester);
      await pumpApp(
        tester,
        authRepository: signedIn(),
        database: db,
        courseRemote: FakeCourseRemote([beomeosa()]),
        clock: clock,
      );
      await settle(tester);

      await tester.tap(find.text('기록').last);
      await settle(tester);
      await tester.tap(find.text('시연용 금정산 두 번째 산행'));
      await settle(tester);

      expect(find.text('거리'), findsOneWidget);
      expect(find.text('움직인 시간'), findsOneWidget);
      expect(find.text('금정산 범어사 코스'), findsOneWidget); // 완주한 코스
      expect(find.text('더 자세한 분석이 궁금하다면'), findsOneWidget);
      expect(find.text('상세 분석'), findsNothing);
    });

    testWidgets('프리미엄이면 고도 그래프·구간별 페이스·km별 기록·같은 코스 비교가 보인다', (tester) async {
      tallScreen(tester);
      final (db, id) = await dbWithHike(tester);
      await pumpApp(
        tester,
        authRepository: signedIn(),
        database: db,
        courseRemote: FakeCourseRemote([beomeosa()]),
        subscription: FakeSubscriptionRemote(active: true),
        clock: clock,
      );
      await settle(tester);
      await push(tester, AppRoutes.activity(id));

      expect(find.text('상세 분석'), findsOneWidget);
      expect(find.text('구간별 페이스'), findsOneWidget);
      expect(find.text('오르막'), findsOneWidget);
      expect(find.text('km별 기록'), findsOneWidget);
      expect(find.text('전반·후반 오르막 속도'), findsOneWidget);
      // 범어사 코스 2회 중 이번 기록이 더 빠르다.
      expect(find.text('금정산 범어사 코스 내 기록'), findsOneWidget);
      expect(find.textContaining('(이번 기록)'), findsOneWidget);
      expect(find.text('  최고'), findsOneWidget);
    });

    testWidgets('GPX 내보내기를 누르면 GPX 파일을 공유한다', (tester) async {
      final (db, id) = await dbWithHike(tester);
      final sharer = FakeGpxSharer();
      await pumpApp(
        tester,
        authRepository: signedIn(),
        database: db,
        courseRemote: FakeCourseRemote([beomeosa()]),
        gpxSharer: sharer,
        clock: clock,
      );
      await settle(tester);
      await push(tester, AppRoutes.activity(id));

      await tester.tap(find.text('GPX 내보내기'));
      await settle(tester);

      expect(sharer.shared.single.$1, endsWith('.gpx'));
      expect(sharer.shared.single.$2, contains('<trkpt '));
    });
  });

  group('프리미엄 구독', () {
    testWidgets('시연용 결제로 구독하고, 해지하면 바로 일반 사용자가 된다', (tester) async {
      final subscription = FakeSubscriptionRemote();
      await pumpApp(
        tester,
        authRepository: signedIn(),
        subscription: subscription,
        clock: clock,
      );
      await tester.tap(find.text('내 정보').last);
      await settle(tester);
      expect(find.text('프리미엄'), findsOneWidget);

      await tester.tap(find.text('프리미엄'));
      await settle(tester);
      await tester.tap(find.text('월 4,900원 구독하기'));
      await tester.pumpAndSettle();
      expect(find.textContaining('시연용 결제라 실제로 돈이 나가지 않아요'), findsOneWidget);
      await tester.tap(find.text('결제하기'));
      await settle(tester);

      expect(subscription.starts, 1);
      expect(find.text('프리미엄을 이용하고 있어요'), findsOneWidget);
      expect(find.textContaining('까지 이용할 수 있어요'), findsOneWidget);

      await tester.tap(find.text('구독 해지'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('해지하기'));
      await settle(tester);

      expect(subscription.cancels, 1);
      expect(find.text('월 4,900원 구독하기'), findsOneWidget);
    });

    testWidgets('코스 랭킹 아래에 일반은 "전체 순위 보기", 프리미엄은 전체 순위 안내가 뜬다', (tester) async {
      tallScreen(tester);
      await pumpApp(
        tester,
        authRepository: signedIn(),
        courseRemote: FakeCourseRemote([testCourse(id: 'a')]),
        subscription: FakeSubscriptionRemote(active: true),
        clock: clock,
      );
      await settle(tester);
      await push(tester, AppRoutes.course('a'));

      expect(find.text('프리미엄 · 전체 순위를 보고 있어요'), findsOneWidget);
    });
  });

  group('리뷰', () {
    Future<FakeReviewRemote> openCourse(
      WidgetTester tester, {
      required int myCount,
      List<dynamic> existing = const [],
    }) async {
      tallScreen(tester);
      final reviews = FakeReviewRemote()
        ..reviews.addAll(existing.cast())
        ..reviews.addAll([
          review('고당봉지킴이', 4, comment: '정상 조망이 정말 좋아요.'),
          review('주말산꾼', 2),
        ]);
      await pumpApp(
        tester,
        authRepository: signedIn(),
        courseRemote: FakeCourseRemote([testCourse(id: 'a')]),
        competition: FakeCompetitionRemote()
          ..stats = CourseStats(completionCount: 10, myCount: myCount),
        reviews: reviews,
        clock: clock,
      );
      await settle(tester);
      await push(tester, AppRoutes.course('a'));
      return reviews;
    }

    testWidgets('항목별 평균과 리뷰 목록을 보여 주고, 완주하지 않았으면 쓸 수 없다', (tester) async {
      await openCourse(tester, myCount: 0);

      expect(find.text('2개'), findsOneWidget);
      expect(find.text('3.0 · 보통'), findsNWidgets(4));
      expect(find.text('정상 조망이 정말 좋아요.'), findsOneWidget);
      expect(find.text('이 코스를 완주하면 리뷰를 쓸 수 있어요'), findsOneWidget);
      expect(find.text('리뷰 쓰기'), findsNothing);
    });

    testWidgets('완주했으면 네 항목을 골라 리뷰를 쓰고, 다시 들어가 고치거나 지울 수 있다', (tester) async {
      final reviews = await openCourse(tester, myCount: 2);

      await tester.tap(find.text('리뷰 쓰기'));
      await settle(tester);
      expect(find.text('네 항목을 모두 골라 주세요'), findsOneWidget);

      for (final aspect in ReviewAspect.values) {
        await tester.tap(find.bySemanticsLabel('${aspect.label} 4점'));
      }
      await tester.enterText(find.byType(TextField), '물을 넉넉히 챙기세요');
      await tester.pumpAndSettle();
      await tester.tap(find.text('저장하기'));
      await settle(tester);

      expect(reviews.saved.single.$2.values.toSet(), {4});
      expect(reviews.saved.single.$3, '물을 넉넉히 챙기세요');
      expect(find.text('김세민#0369 (나)'), findsOneWidget);
      expect(find.text('내 리뷰 고치기'), findsOneWidget);

      await tester.tap(find.text('내 리뷰 고치기'));
      await settle(tester);
      await tester.tap(find.text('내 리뷰 지우기'));
      await settle(tester);

      expect(reviews.deletes, 1);
      expect(find.text('김세민#0369 (나)'), findsNothing);
    });
  });
}
