import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hiking_app/features/auth/domain/app_user.dart';
import 'package:hiking_app/features/recording/data/location_service.dart';
import 'package:hiking_app/features/recording/data/recording_repository.dart';
import 'package:hiking_app/features/recording/domain/track_point.dart';
import 'package:hiking_app/features/recording/presentation/recording_map.dart';

import '../../../helpers/gpx.dart';
import '../../../helpers/pump_app.dart';
import '../../activities/fake_activity_remote.dart';
import '../../auth/fake_auth_repository.dart';
import '../fake_location_service.dart';

/// 저장 전후 업적 비교(DB 읽기)와 업로드는 실제 비동기 작업이라, 가짜 시간 밖에서 조금씩 기다린다.
Future<void> waitForSave(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump();
  }
  await tester.pumpAndSettle();
}

void main() {
  FakeAuthRepository signedIn() => FakeAuthRepository(
    user: const AppUser(id: 'u1', provider: SocialProvider.kakao),
  );

  testWidgets('기록 시작 → 위치 수신 → 일시정지 → 종료 → 제목 저장', (tester) async {
    final location = FakeLocationService();
    final remote = FakeActivityRemote();
    var now = DateTime(2026, 10, 13, 9);
    await pumpApp(
      tester,
      authRepository: signedIn(),
      location: location,
      clock: () => now,
      remote: remote,
    );

    await tester.tap(find.text('등산 기록 시작'));
    await tester.pumpAndSettle();
    expect(find.text('위치를 찾고 있어요'), findsOneWidget);
    // 기록 화면에 지도가 있다 (내 위치·걸은 경로·코스 선)
    expect(find.byType(RecordingMap), findsOneWidget);

    for (final sample in readGpx('test_data/synthetic_climb.gpx')) {
      location.emit(sample);
    }
    now = now.add(const Duration(minutes: 8, seconds: 20));
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('기록 중이에요'), findsOneWidget);
    expect(find.text('0:08:20'), findsOneWidget);
    expect(find.text('0.56 km'), findsOneWidget);
    expect(find.text('200 m'), findsOneWidget); // 현재 고도
    expect(find.text('100 m'), findsOneWidget); // 오른 높이

    await tester.tap(find.text('일시정지'));
    // 일시정지는 쌓인 위치 51개의 DB 저장이 끝나길 기다린다.
    // 위젯 테스트의 가짜 시간 밖에서 잠시 실제로 기다려 DB 작업을 끝낸다.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await tester.pumpAndSettle();
    expect(find.text('일시정지했어요'), findsOneWidget);
    expect(find.text('다시 시작'), findsOneWidget);

    await tester.tap(find.text('종료'));
    await tester.pumpAndSettle();
    expect(find.text('기록을 끝낼까요?'), findsOneWidget);
    await tester.tap(find.text('끝내기'));
    await tester.pumpAndSettle();

    expect(find.text('수고했어요!'), findsOneWidget);
    expect(find.text('10월 13일 등산'), findsOneWidget); // 기본 제목

    await tester.enterText(find.byType(TextField), '관악산 연주대');
    await tester.tap(find.text('저장하기'));
    await waitForSave(tester);

    // 첫 기록이라 "첫 걸음" 배지를 얻는다.
    expect(find.text('새 배지를 얻었어요'), findsOneWidget);
    expect(find.text('첫 걸음'), findsOneWidget);
    await tester.tap(find.text('확인'));
    await tester.pumpAndSettle();

    expect(find.text('기록을 저장했어요'), findsOneWidget);

    // 저장하면 바로 서버 업로드를 시도한다.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    expect(remote.rows.values.single['title'], '관악산 연주대');
    expect(find.text('등산 기록 시작'), findsOneWidget);
  });

  testWidgets('위치 권한이 영구 거부면 설정으로 이동하는 안내 화면을 보여 준다', (tester) async {
    final location = FakeLocationService(access: LocationAccess.deniedForever);
    await pumpApp(tester, authRepository: signedIn(), location: location);

    await tester.tap(find.text('등산 기록 시작'));
    await tester.pumpAndSettle();
    expect(find.text('위치 권한이 필요해요'), findsOneWidget);

    await tester.tap(find.text('설정으로 이동'));
    await tester.pumpAndSettle();
    expect(location.opened, ['app']);

    // 설정에서 허용하고 돌아와 다시 시도
    location.access = LocationAccess.granted;
    await tester.tap(find.text('다시 시도'));
    await tester.pumpAndSettle();
    expect(find.text('위치를 찾고 있어요'), findsOneWidget);
  });

  testWidgets('앱이 기록 중에 꺼졌다면 다시 켰을 때 이어서 할지 묻는다', (tester) async {
    final db = testDatabase();
    final repo = RecordingRepository(db);
    final t0 = DateTime(2026, 10, 13, 9, 5);
    final session = await repo.start(t0);
    await repo.addPoint(
      session.activityId,
      TrackPoint(
        segment: 0,
        latitude: 37.46,
        longitude: 126.95,
        altitude: 120,
        accuracy: 5,
        recordedAt: t0.add(const Duration(minutes: 30)),
      ),
    );

    await pumpApp(tester, authRepository: signedIn(), database: db);
    expect(find.text('끝나지 않은 기록이 있어요'), findsOneWidget);
    expect(find.textContaining('10월 13일 오전 9:05'), findsOneWidget);

    await tester.tap(find.text('여기까지 저장하기'));
    await tester.pumpAndSettle();
    expect(find.text('수고했어요!'), findsOneWidget);

    // 저장하고 홈으로 돌아오면, 방금 끝낸 기록을 다시 묻지 않는다.
    await tester.tap(find.text('저장하기'));
    await waitForSave(tester);
    // 첫 기록이라 새 배지 카드가 뜬다.
    await tester.tap(find.text('확인'));
    await tester.pumpAndSettle();
    expect(find.text('등산 기록 시작'), findsOneWidget);
    expect(find.text('끝나지 않은 기록이 있어요'), findsNothing);
  });
}
