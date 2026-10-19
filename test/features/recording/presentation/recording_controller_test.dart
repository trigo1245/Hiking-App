import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hiking_app/core/database/app_database.dart';
import 'package:hiking_app/core/utils/clock.dart';
import 'package:hiking_app/features/auth/domain/app_user.dart';
import 'package:hiking_app/features/auth/presentation/auth_providers.dart';
import 'package:hiking_app/features/recording/data/location_service.dart';
import 'package:hiking_app/features/recording/data/recording_repository.dart';
import 'package:hiking_app/features/recording/domain/recording_session.dart';
import 'package:hiking_app/features/recording/domain/track_point.dart';
import 'package:hiking_app/features/recording/presentation/recording_controller.dart';

import '../../../helpers/gpx.dart';
import '../../../helpers/pump_app.dart';
import '../../auth/fake_auth_repository.dart';
import '../fake_location_service.dart';

void main() {
  late FakeLocationService location;
  late AppDatabase db;
  late ProviderContainer container;
  var now = DateTime(2026, 10, 13, 9);

  RecordingController controller() =>
      container.read(recordingControllerProvider.notifier);
  RecordingState state() => container.read(recordingControllerProvider);

  setUp(() {
    now = DateTime(2026, 10, 13, 9);
    location = FakeLocationService();
    db = testDatabase();
    container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(
          FakeAuthRepository(
            user: const AppUser(id: 'u1', provider: SocialProvider.kakao),
          ),
        ),
        appDatabaseProvider.overrideWithValue(db),
        locationServiceProvider.overrideWithValue(location),
        clockProvider.overrideWithValue(() => now),
      ],
    );
    addTearDown(container.dispose);
  });

  /// 위치를 보내고 저장이 끝날 때까지 기다린다.
  Future<void> emitAll(Iterable<LocationSample> samples) async {
    for (final s in samples) {
      location.emit(s);
      await Future<void>.delayed(Duration.zero);
    }
  }

  test('권한이 없으면 기록을 시작하지 않는다', () async {
    location.access = LocationAccess.deniedForever;
    expect(await controller().start(), LocationAccess.deniedForever);
    expect(state().isActive, isFalse);
    expect(location.isListening, isFalse);
  });

  test('시작하면 알림 권한을 요청하고 위치 수집을 시작한다', () async {
    expect(await controller().start(), LocationAccess.granted);
    expect(state().session?.status, RecordingStatus.recording);
    expect(location.notificationRequests, 1);
    expect(location.isListening, isTrue);
  });

  test('GPX 경로를 받으면 수치가 쌓이고, 받은 점은 즉시 DB에 저장된다', () async {
    await controller().start();
    await emitAll(readGpx('test_data/synthetic_climb.gpx'));

    expect(state().stats.distanceM, closeTo(556, 1));
    expect(state().stats.elevationGainM, 100);
    expect(state().currentAltitude, 200);
    expect(state().hasFix, isTrue);

    final id = state().session!.activityId;
    final saved = await container
        .read(recordingRepositoryProvider)
        .loadPoints(id);
    expect(saved, hasLength(51));
  });

  test('일시정지하면 위치 수집을 멈추고, 다시 시작하면 새 구간으로 이어 간다', () async {
    await controller().start();
    await controller().pause();
    expect(state().isPaused, isTrue);
    expect(location.isListening, isFalse);

    now = now.add(const Duration(minutes: 5));
    await controller().resume();
    expect(state().isPaused, isFalse);
    expect(state().session!.segment, 1);
    expect(state().session!.pausedTotal, const Duration(minutes: 5));
    expect(location.isListening, isTrue);
  });

  test('종료하면 요약을 저장하고 기록 중 상태가 끝난다', () async {
    await controller().start();
    await emitAll(readGpx('test_data/synthetic_climb.gpx'));
    now = now.add(const Duration(minutes: 30));

    final id = await controller().finish();
    expect(state().isActive, isFalse);
    expect(location.isListening, isFalse);

    final summary = await container
        .read(recordingRepositoryProvider)
        .loadSummary(id!);
    expect(summary.title, '10월 13일 등산');
    expect(summary.elapsed, const Duration(minutes: 30));
    expect(summary.distanceM, closeTo(556, 1));
    expect(summary.pointCount, 51);
  });

  test('위치 수집 중 오류가 나면 신호 끊김을 표시하고, 위치가 다시 오면 지운다', () async {
    await controller().start();
    location.emitError(Exception('GPS off'));
    await Future<void>.delayed(Duration.zero);
    expect(state().signalLost, isTrue);

    await emitAll(readGpx('test_data/synthetic_climb.gpx').take(1));
    expect(state().signalLost, isFalse);
  });

  test('앱이 꺼졌던 기록을 복원하면 저장된 점으로 수치를 다시 계산한다', () async {
    await controller().start();
    await emitAll(readGpx('test_data/synthetic_climb.gpx'));
    // 앱이 강제 종료된 상황: 새 컨트롤러로 DB에서 다시 읽는다.
    final restarted = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(
          FakeAuthRepository(
            user: const AppUser(id: 'u1', provider: SocialProvider.kakao),
          ),
        ),
        appDatabaseProvider.overrideWithValue(db),
        locationServiceProvider.overrideWithValue(FakeLocationService()),
        clockProvider.overrideWithValue(() => now),
      ],
    );
    addTearDown(restarted.dispose);

    final restartedController = restarted.read(
      recordingControllerProvider.notifier,
    );
    final unfinished = await restartedController.findUnfinished();
    restartedController.restore(unfinished!);

    final restored = restarted.read(recordingControllerProvider);
    expect(restored.isPaused, isTrue);
    expect(restored.stats.distanceM, closeTo(556, 1));
    expect(restored.stats.elevationGainM, 100);
  });
}
