import 'package:flutter_test/flutter_test.dart';
import 'package:hiking_app/features/activities/data/activities_repository.dart';
import 'package:hiking_app/features/activities/data/activity_downloader.dart';
import 'package:hiking_app/features/activities/data/activity_uploader.dart';
import 'package:hiking_app/features/activities/domain/activity_analysis.dart';
import 'package:hiking_app/features/activities/domain/activity_summary.dart';
import 'package:hiking_app/features/recording/data/recording_repository.dart';
import 'package:hiking_app/features/recording/domain/track_point.dart';
import 'package:hiking_app/features/recording/domain/track_stats.dart';

import '../../../helpers/gpx.dart';
import '../../../helpers/pump_app.dart';
import '../fake_activity_remote.dart';

void main() {
  late FakeActivityRemote server;
  final t0 = DateTime(2026, 10, 13, 9);

  /// 휴대폰 한 대: 기기 DB와 그 위의 저장소들
  ({
    RecordingRepository recording,
    ActivitiesRepository activities,
    ActivityUploader uploader,
    ActivityDownloader downloader,
  })
  phone(String idPrefix) {
    final db = testDatabase();
    var n = 0;
    final recording = RecordingRepository(db, newId: () => '$idPrefix-${n++}');
    final activities = ActivitiesRepository(db);
    return (
      recording: recording,
      activities: activities,
      uploader: ActivityUploader(
        activities: activities,
        recording: recording,
        remote: server,
        loadCourses: () async => const [],
      ),
      downloader: ActivityDownloader(activities: activities, remote: server),
    );
  }

  /// 일시정지를 한 번 끼운 기록을 만든다.
  Future<String> record(
    RecordingRepository recording,
    DateTime start,
    String title,
  ) async {
    final session = await recording.start(start, userId: 'u1');
    final calc = TrackStatsCalculator();
    final samples = readGpx('test_data/synthetic_climb.gpx');
    for (final (i, s) in samples.indexed) {
      final p = TrackPoint.fromSample(
        s,
        segment: i < samples.length ~/ 2 ? 0 : 1,
      );
      await recording.addPoint(session.activityId, p);
      calc.add(p);
    }
    await recording.finish(
      session.activityId,
      endedAt: start.add(const Duration(hours: 1)),
      stats: calc.stats,
      title: title,
    );
    return session.activityId;
  }

  setUp(() => server = FakeActivityRemote());

  test('다른 휴대폰에서 로그인하면 서버의 기록을 요약·위치 점까지 그대로 받는다', () async {
    final old = phone('old');
    final id = await record(old.recording, t0, '금정산 고당봉');
    await old.uploader.uploadPending(userId: 'u1');

    final fresh = phone('new');
    expect(await fresh.downloader.downloadMissing(userId: 'u1'), 1);

    final before = await old.recording.loadSummary(id);
    final after = await fresh.recording.loadSummary(id);
    expect(after.title, '금정산 고당봉');
    expect(after.startedAt, before.startedAt);
    expect(after.distanceM, before.distanceM);
    expect(after.elevationGainM, before.elevationGainM);
    expect(after.moving, before.moving);
    // 서버에 있는 기록이니 다시 올리지 않는다.
    expect(after.uploadStatus, UploadStatus.done);

    final oldPoints = await old.recording.loadPoints(id);
    final newPoints = await fresh.recording.loadPoints(id);
    expect(newPoints, hasLength(oldPoints.length));
    expect(newPoints.map((p) => p.segment).toSet(), {0, 1});

    // 상세 분석(통계 재료)도 같은 결과가 나온다.
    final a = ActivityAnalyzer.analyze(oldPoints);
    final b = ActivityAnalyzer.analyze(newPoints);
    expect(b.efficiency, closeTo(a.efficiency!, 1e-9));
    expect(b.rests.length, a.rests.length);

    // 목록에도 보인다.
    final listed = await fresh.activities.watchFinished('u1').first;
    expect(listed.map((s) => s.id), [id]);
  });

  test('이미 기기에 있는 기록은 다시 받지 않는다', () async {
    final p = phone('p');
    await record(p.recording, t0, '첫 산행');
    await p.uploader.uploadPending(userId: 'u1');

    expect(await p.downloader.downloadMissing(userId: 'u1'), 0);
    expect(await p.activities.watchFinished('u1').first, hasLength(1));
  });

  test('두 번 받아도 중복되지 않는다', () async {
    final old = phone('old');
    await record(old.recording, t0, '첫 산행');
    await record(old.recording, t0.add(const Duration(days: 3)), '두 번째');
    await old.uploader.uploadPending(userId: 'u1');

    final fresh = phone('new');
    expect(await fresh.downloader.downloadMissing(userId: 'u1'), 2);
    expect(await fresh.downloader.downloadMissing(userId: 'u1'), 0);
    expect(await fresh.activities.watchFinished('u1').first, hasLength(2));
  });

  test('GPX 하나를 받지 못해도 나머지는 받고, 다음에 다시 시도한다', () async {
    final old = phone('old');
    final first = await record(old.recording, t0, '첫 산행');
    await record(old.recording, t0.add(const Duration(days: 3)), '두 번째');
    await old.uploader.uploadPending(userId: 'u1');
    server.brokenGpx.add('u1/$first.gpx');

    final fresh = phone('new');
    expect(await fresh.downloader.downloadMissing(userId: 'u1'), 1);

    server.brokenGpx.clear();
    expect(await fresh.downloader.downloadMissing(userId: 'u1'), 1);
    expect(await fresh.activities.watchFinished('u1').first, hasLength(2));
  });

  test('인터넷이 없으면 아무것도 받지 않고 조용히 끝난다', () async {
    final old = phone('old');
    await record(old.recording, t0, '첫 산행');
    await old.uploader.uploadPending(userId: 'u1');
    server.failWith = Exception('Failed host lookup');

    final fresh = phone('new');
    expect(await fresh.downloader.downloadMissing(userId: 'u1'), 0);
    expect(await fresh.activities.watchFinished('u1').first, isEmpty);
  });
}
