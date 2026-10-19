import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hiking_app/core/database/app_database.dart';
import 'package:hiking_app/features/activities/data/activities_repository.dart';
import 'package:hiking_app/features/activities/data/activity_uploader.dart';
import 'package:hiking_app/features/activities/domain/activity_summary.dart';
import 'package:hiking_app/features/recording/data/recording_repository.dart';
import 'package:hiking_app/features/recording/domain/track_point.dart';
import 'package:hiking_app/features/recording/domain/track_stats.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../helpers/gpx.dart';
import '../../../helpers/pump_app.dart';
import '../fake_activity_remote.dart';

void main() {
  late AppDatabase db;
  late RecordingRepository recording;
  late ActivitiesRepository activities;
  late FakeActivityRemote remote;
  late ActivityUploader uploader;
  var nextId = 0;
  final t0 = DateTime(2026, 10, 13, 9);

  /// GPX 경로로 끝난 기록 하나를 기기 DB에 만든다.
  Future<String> finishedActivity({String? userId = 'u1'}) async {
    final session = await recording.start(t0, userId: userId);
    final calc = TrackStatsCalculator();
    for (final s in readGpx('test_data/synthetic_climb.gpx')) {
      final p = TrackPoint.fromSample(s, segment: 0);
      await recording.addPoint(session.activityId, p);
      calc.add(p);
    }
    await recording.finish(
      session.activityId,
      endedAt: t0.add(const Duration(minutes: 10)),
      stats: calc.stats,
      title: '10월 13일 등산',
    );
    return session.activityId;
  }

  Future<UploadStatus> statusOf(String id) async =>
      (await recording.loadSummary(id)).uploadStatus;

  setUp(() {
    db = testDatabase();
    recording = RecordingRepository(db, newId: () => 'activity-${nextId++}');
    activities = ActivitiesRepository(db);
    remote = FakeActivityRemote();
    uploader = ActivityUploader(
      activities: activities,
      recording: recording,
      remote: remote,
    );
  });

  test('업로드하면 GPX는 {user_id}/{id}.gpx에, 요약은 activities에 올라간다', () async {
    final id = await finishedActivity();

    expect(await uploader.upload(id, userId: 'u1'), isTrue);

    final path = 'u1/$id.gpx';
    expect(remote.gpxFiles[path], contains('<trkpt '));
    final row = remote.rows[id]!;
    expect(row['user_id'], 'u1');
    expect(row['gpx_path'], path);
    expect(row['title'], '10월 13일 등산');
    expect(row['point_count'], 51);
    expect(row['elapsed_s'], 600);
    expect(row['distance_m'] as double, closeTo(556, 1));
    expect(row['started_at'], t0.toUtc().toIso8601String());
    expect(await statusOf(id), UploadStatus.done);
  });

  test('네트워크 오류면 "업로드 대기"로 남는다', () async {
    final id = await finishedActivity();
    remote.failWith = const SocketException('Failed host lookup');

    expect(await uploader.upload(id, userId: 'u1'), isFalse);
    expect(await statusOf(id), UploadStatus.pending);
  });

  test('서버가 거절하면 "업로드 실패"가 된다', () async {
    final id = await finishedActivity();
    remote.failWith = const PostgrestException(
      message: 'new row violates row-level security policy',
      code: '42501',
    );

    expect(await uploader.upload(id, userId: 'u1'), isFalse);
    expect(await statusOf(id), UploadStatus.failed);
  });

  test('올리지 못한 기록만 모아 다시 올린다 (다른 사용자 기록은 제외)', () async {
    final failed = await finishedActivity();
    final pending = await finishedActivity();
    final otherUser = await finishedActivity(userId: 'u2');
    final done = await finishedActivity();
    await activities.setUploadStatus(failed, UploadStatus.failed, userId: 'u1');
    await activities.setUploadStatus(done, UploadStatus.done, userId: 'u1');

    await uploader.uploadPending(userId: 'u1');

    expect(remote.rows.keys, unorderedEquals([failed, pending]));
    expect(await statusOf(failed), UploadStatus.done);
    expect(await statusOf(pending), UploadStatus.done);
    expect(await statusOf(otherUser), UploadStatus.pending);
  });

  test('같은 기록을 동시에 여러 번 요청해도 한 번만 올린다', () async {
    final id = await finishedActivity();

    await Future.wait([
      uploader.upload(id, userId: 'u1'),
      uploader.uploadPending(userId: 'u1'),
      uploader.upload(id, userId: 'u1'),
    ]);

    expect(remote.uploadCalls, 1);
  });

  test('사용자 ID가 없던 예전 기록은 업로드할 때 현재 사용자로 채운다', () async {
    final legacy = await finishedActivity(userId: null);

    await uploader.uploadPending(userId: 'u1');

    expect(remote.rows[legacy]?['user_id'], 'u1');
    final mine = await activities.watchFinished('u1').first;
    final others = await activities.watchFinished('u2').first;
    expect(mine.map((a) => a.id), contains(legacy));
    expect(others.map((a) => a.id), isNot(contains(legacy)));
  });
}
