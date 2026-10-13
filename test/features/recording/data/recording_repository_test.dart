import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hiking_app/core/database/app_database.dart';
import 'package:hiking_app/features/recording/data/recording_repository.dart';
import 'package:hiking_app/features/recording/domain/recording_session.dart';
import 'package:hiking_app/features/recording/domain/track_point.dart';
import 'package:hiking_app/features/recording/domain/track_stats.dart';

void main() {
  late AppDatabase db;
  late RecordingRepository repo;
  final t0 = DateTime(2026, 10, 13, 9);

  TrackPoint point(int segment, int second, {double accuracy = 5}) =>
      TrackPoint(
        segment: segment,
        latitude: 37.46,
        longitude: 126.95,
        altitude: 100,
        accuracy: accuracy,
        recordedAt: t0.add(Duration(seconds: second)),
      );

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = RecordingRepository(db, newId: () => 'activity-1');
  });
  tearDown(() => db.close());

  test('시작하면 기록 중 상태의 기록이 생긴다', () async {
    final session = await repo.start(t0);
    expect(session.activityId, 'activity-1');
    expect(session.status, RecordingStatus.recording);
    expect(session.segment, 0);
  });

  test('정확도가 나쁜 점도 원본 그대로 저장한다', () async {
    await repo.start(t0);
    await repo.addPoint('activity-1', point(0, 0));
    await repo.addPoint('activity-1', point(0, 3, accuracy: 80));
    final points = await repo.loadPoints('activity-1');
    expect(points.map((p) => p.accuracy), [5, 80]);
  });

  test('일시정지 후 다시 시작하면 일시정지 시간이 쌓이고 구간이 바뀐다', () async {
    await repo.start(t0);
    await repo.pause('activity-1', t0.add(const Duration(minutes: 10)));
    final session = await repo.resume(
      'activity-1',
      t0.add(const Duration(minutes: 15)),
    );
    expect(session.status, RecordingStatus.recording);
    expect(session.segment, 1);
    expect(session.pausedTotal, const Duration(minutes: 5));
    expect(
      session.activeDuration(t0.add(const Duration(minutes: 20))),
      const Duration(minutes: 15),
    );
  });

  test('앱이 기록 중에 꺼졌다면 마지막 위치 시각에 일시정지된 상태로 불러온다', () async {
    await repo.start(t0);
    await repo.addPoint('activity-1', point(0, 0));
    await repo.addPoint('activity-1', point(0, 60));

    final unfinished = await repo.loadUnfinished();
    expect(unfinished, isNotNull);
    expect(unfinished!.points, hasLength(2));
    expect(unfinished.session.status, RecordingStatus.paused);
    expect(unfinished.session.pausedAt, t0.add(const Duration(seconds: 60)));
  });

  test('끝난 기록은 다시 불러오지 않는다', () async {
    await repo.start(t0);
    await repo.finish(
      'activity-1',
      endedAt: t0.add(const Duration(hours: 2)),
      stats: const TrackStats(),
      title: '10월 13일 등산',
    );
    expect(await repo.loadUnfinished(), isNull);
  });

  test('종료하면 요약 수치와 기본 제목을 저장하고, 제목을 바꿀 수 있다', () async {
    await repo.start(t0);
    await repo.finish(
      'activity-1',
      endedAt: t0.add(const Duration(hours: 2, minutes: 30)),
      stats: const TrackStats(
        distanceM: 5230,
        elevationGainM: 612,
        maxAltitudeM: 836,
        moving: Duration(hours: 2),
        pointCount: 1800,
        isFlagged: true,
      ),
      title: '10월 13일 등산',
    );

    var summary = await repo.loadSummary('activity-1');
    expect(summary.title, '10월 13일 등산');
    expect(summary.elapsed, const Duration(hours: 2, minutes: 30));
    expect(summary.moving, const Duration(hours: 2));
    expect(summary.distanceM, 5230);
    expect(summary.isFlagged, isTrue);

    await repo.updateTitle('activity-1', '관악산 연주대');
    summary = await repo.loadSummary('activity-1');
    expect(summary.title, '관악산 연주대');
  });
}
