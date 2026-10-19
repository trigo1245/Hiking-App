import 'package:flutter_test/flutter_test.dart';
import 'package:hiking_app/core/database/app_database.dart';
import 'package:hiking_app/features/auth/domain/app_user.dart';
import 'package:hiking_app/features/recording/data/recording_repository.dart';
import 'package:hiking_app/features/recording/domain/track_point.dart';
import 'package:hiking_app/features/recording/domain/track_stats.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../helpers/gpx.dart';
import '../../../helpers/pump_app.dart';
import '../../auth/fake_auth_repository.dart';
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

  Future<void> openRecordsTab(WidgetTester tester) async {
    await tester.tap(find.text('기록').last);
    await tester.pumpAndSettle();
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

  testWidgets('기록이 없으면 다음 행동을 안내한다', (tester) async {
    await pumpApp(tester, authRepository: signedIn(), clock: clock);
    await openRecordsTab(tester);

    expect(find.text('아직 등산 기록이 없어요'), findsOneWidget);
    expect(find.textContaining('등산 기록 시작'), findsWidgets);
  });
}
