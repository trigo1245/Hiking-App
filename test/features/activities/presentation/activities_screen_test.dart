import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:hiking_app/core/database/app_database.dart';
import 'package:hiking_app/features/activities/data/activities_repository.dart';
import 'package:hiking_app/features/activities/data/activity_uploader.dart';
import 'package:hiking_app/features/auth/domain/app_user.dart';
import 'package:hiking_app/features/courses/domain/competition.dart';
import 'package:hiking_app/features/recording/data/recording_repository.dart';
import 'package:hiking_app/features/recording/domain/track_point.dart';
import 'package:hiking_app/features/recording/domain/track_stats.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../helpers/gpx.dart';
import '../../../helpers/pump_app.dart';
import '../../auth/fake_auth_repository.dart';
import '../../courses/fake_competition_remote.dart';
import '../fake_activity_remote.dart';

void main() {
  final t0 = DateTime(2026, 10, 13, 9, 5);
  DateTime clock() => DateTime(2026, 10, 20, 12);

  FakeAuthRepository signedIn() => FakeAuthRepository(
    user: const AppUser(id: 'u1', provider: SocialProvider.kakao),
  );

  /// 기기 DB에 끝난 기록(업로드 대기)을 하나 만든다.
  Future<String> seedFinished(AppDatabase db) async {
    final repo = RecordingRepository(db);
    final session = await repo.start(t0, userId: 'u1');
    final calc = TrackStatsCalculator();
    for (final s in readGpx('test_data/synthetic_climb.gpx')) {
      final p = TrackPoint.fromSample(s, segment: 0);
      await repo.addPoint(session.activityId, p);
      calc.add(p);
    }
    await repo.finish(
      session.activityId,
      endedAt: t0.add(const Duration(hours: 1, minutes: 30)),
      stats: calc.stats,
      title: '금정산 고당봉',
    );
    return session.activityId;
  }

  /// 업로드(DB 작업)가 끝나도록 실제 시간으로 잠깐 기다린 뒤 화면을 다시 그린다.
  Future<void> settleUploads(WidgetTester tester) async {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await tester.pumpAndSettle();
  }

  /// 기록 탭을 연다. 처음에는 통계가 보이므로 [history]면 내역으로 바꾼다.
  Future<void> openRecordsTab(
    WidgetTester tester, {
    bool history = true,
  }) async {
    await tester.tap(find.text('기록').last);
    await tester.pumpAndSettle();
    if (history && find.text('내역').evaluate().isNotEmpty) {
      await tester.tap(find.text('내역'));
      await tester.pumpAndSettle();
    }
  }

  testWidgets('앱이 뜨면 올리지 못한 기록을 자동으로 올리고, 기록 탭에 완료로 보인다', (tester) async {
    final db = testDatabase();
    final remote = FakeActivityRemote();
    final id = await seedFinished(db);

    await pumpApp(
      tester,
      authRepository: signedIn(),
      database: db,
      remote: remote,
      clock: clock,
    );
    await settleUploads(tester);
    await openRecordsTab(tester);

    expect(remote.rows.keys, [id]);
    expect(find.text('이번 달'), findsOneWidget);
    expect(find.text('1 번'), findsOneWidget);
    expect(find.text('금정산 고당봉'), findsOneWidget);
    expect(find.text('업로드 완료'), findsOneWidget);
  });

  testWidgets('서버가 거절하면 실패로 보이고, 다시 시도해서 올릴 수 있다', (tester) async {
    final db = testDatabase();
    final remote = FakeActivityRemote()
      ..failWith = const PostgrestException(message: 'rejected');
    await seedFinished(db);

    await pumpApp(
      tester,
      authRepository: signedIn(),
      database: db,
      remote: remote,
      clock: clock,
    );
    await settleUploads(tester);
    await openRecordsTab(tester);

    expect(find.text('업로드 실패'), findsOneWidget);

    remote.failWith = null;
    await tester.tap(find.text('업로드에 실패했어요. 다시 시도할까요?'));
    await settleUploads(tester);

    expect(find.text('업로드 완료'), findsOneWidget);
    expect(find.text('업로드에 실패했어요. 다시 시도할까요?'), findsNothing);
  });

  testWidgets('네트워크가 안 되면 업로드 대기로 보인다', (tester) async {
    final db = testDatabase();
    final remote = FakeActivityRemote()
      ..failWith = Exception('Failed host lookup');
    await seedFinished(db);

    await pumpApp(
      tester,
      authRepository: signedIn(),
      database: db,
      remote: remote,
      clock: clock,
    );
    await settleUploads(tester);
    await openRecordsTab(tester);

    expect(find.text('업로드 대기'), findsOneWidget);
  });

  testWidgets('기록 탭은 통계부터 보여 주고, 완등 횟수는 서버 완주 기록으로 센다', (tester) async {
    // 통계 화면이 스크롤 없이 아래쪽까지 그려지도록 세로로 긴 화면을 쓴다.
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final db = testDatabase();
    await seedFinished(db);
    final competition = FakeCompetitionRemote()
      ..myCompletions = [
        MyCompletion(
          courseId: 'a',
          ascent: const Duration(minutes: 47),
          completedAt: t0,
        ),
      ];

    await pumpApp(
      tester,
      authRepository: signedIn(),
      database: db,
      remote: FakeActivityRemote(),
      competition: competition,
      clock: clock,
    );
    await settleUploads(tester);
    await openRecordsTab(tester, history: false);

    expect(find.text('통계'), findsOneWidget);
    expect(find.text('등반 주기'), findsOneWidget);
    expect(find.text('산행이 2번 이상 쌓이면 주기를 알려 드려요'), findsOneWidget);
    expect(find.text('월별 등산 횟수'), findsOneWidget);
    // 등산 1번, 완등 1번
    expect(find.text('1 번'), findsNWidgets(2));
    // 일반 사용자는 종합 분석 대신 안내를 본다.
    expect(find.text('내 산행을 종합해서 분석해 보세요'), findsOneWidget);
    expect(find.text('프리미엄 종합 분석'), findsNothing);
  });

  testWidgets('다른 휴대폰에서 올린 기록을 앱이 뜰 때 받아 내역에 보여 준다', (tester) async {
    // 예전 휴대폰: 기록을 만들어 서버에 올린다.
    final remote = FakeActivityRemote();
    final oldPhone = testDatabase();
    await tester.runAsync(() async {
      final id = await seedFinished(oldPhone);
      await ActivityUploader(
        activities: ActivitiesRepository(oldPhone),
        recording: RecordingRepository(oldPhone),
        remote: remote,
        loadCourses: () async => const [],
      ).upload(id, userId: 'u1');
    });
    expect(remote.rows, hasLength(1));

    // 새 휴대폰: 기기 DB가 비어 있어도 같은 계정으로 로그인하면 받아 온다.
    await pumpApp(
      tester,
      authRepository: signedIn(),
      database: testDatabase(),
      remote: remote,
      clock: clock,
    );
    await settleUploads(tester);
    await openRecordsTab(tester);

    expect(find.text('금정산 고당봉'), findsOneWidget);
    expect(find.text('업로드 완료'), findsOneWidget);
  });

  group('기록 지우기', () {
    /// 올라간 기록 하나를 만들고 그 기록 상세를 연다.
    Future<(FakeActivityRemote, String)> openUploadedDetail(
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(800, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final db = testDatabase();
      final remote = FakeActivityRemote();
      final id = await seedFinished(db);
      await pumpApp(
        tester,
        authRepository: signedIn(),
        database: db,
        remote: remote,
        clock: clock,
      );
      await settleUploads(tester);
      await openRecordsTab(tester);
      await tester.tap(find.text('금정산 고당봉'));
      await settleUploads(tester);
      return (remote, id);
    }

    testWidgets('주의사항을 확인하고 한 번 더 눌러야 서버와 기기에서 지워진다', (tester) async {
      final (remote, id) = await openUploadedDetail(tester);

      await tester.tap(find.text('이 기록 지우기'));
      await tester.pumpAndSettle();
      expect(find.text('이 기록을 지울까요?'), findsOneWidget);
      expect(find.text('되돌릴 수 없어요'), findsOneWidget);
      expect(find.text('서버에서도 지워요'), findsOneWidget);

      // 확인 체크 전에는 삭제 버튼이 눌리지 않는다.
      await tester.tap(find.text('삭제하기'));
      await tester.pumpAndSettle();
      expect(find.text('이 기록을 지울까요?'), findsOneWidget);
      expect(remote.deleted, isEmpty);

      await tester.tap(find.text('위 내용을 확인했어요'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('삭제하기'));
      await settleUploads(tester);

      expect(remote.deleted, [id]);
      expect(remote.rows, isEmpty);
      expect(find.text('기록을 지웠어요'), findsOneWidget);
      expect(find.text('아직 등산 기록이 없어요'), findsOneWidget);
    });

    testWidgets('취소하면 아무것도 지우지 않는다', (tester) async {
      final (remote, _) = await openUploadedDetail(tester);

      await tester.tap(find.text('이 기록 지우기'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('취소'));
      await tester.pumpAndSettle();

      expect(remote.deleted, isEmpty);
      expect(find.text('이 기록 지우기'), findsOneWidget);
    });

    testWidgets('인터넷이 없으면 지우지 않고 다시 시도하라고 알린다 (기기에서도 그대로)', (tester) async {
      final (remote, _) = await openUploadedDetail(tester);
      remote.failWith = Exception('Failed host lookup');

      await tester.tap(find.text('이 기록 지우기'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('위 내용을 확인했어요'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('삭제하기'));
      await settleUploads(tester);

      expect(find.text('지우지 못했어요. 인터넷에 연결된 뒤 다시 시도해 주세요'), findsOneWidget);
      // 기록 상세에 그대로 있다.
      expect(find.text('이 기록 지우기'), findsOneWidget);
      expect(remote.rows, hasLength(1));
    });
  });

  testWidgets('기록이 없으면 다음 행동을 안내한다', (tester) async {
    await pumpApp(tester, authRepository: signedIn(), clock: clock);
    await openRecordsTab(tester);

    expect(find.text('아직 등산 기록이 없어요'), findsOneWidget);
    expect(find.textContaining('등산 기록 시작'), findsWidgets);
  });
}
