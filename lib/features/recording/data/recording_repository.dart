import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../activities/data/activities_repository.dart';
import '../../activities/domain/activity_summary.dart';
import '../domain/recording_session.dart';
import '../domain/track_point.dart';
import '../domain/track_stats.dart';

/// 기록 중인 데이터를 기기 DB에 저장한다. 모든 변경은 즉시 저장돼 앱이 꺼져도 남는다.
class RecordingRepository {
  RecordingRepository(this._db, {String Function()? newId})
    : _newId = newId ?? const Uuid().v4;

  final AppDatabase _db;
  final String Function() _newId;

  Future<RecordingSession> start(DateTime now, {String? userId}) async {
    final id = _newId();
    await _db
        .into(_db.activities)
        .insert(
          ActivitiesCompanion.insert(
            id: id,
            userId: Value(userId),
            status: RecordingStatus.recording.name,
            startedAt: now,
            createdAt: now,
          ),
        );
    return _loadSession(id);
  }

  Future<void> addPoint(String activityId, TrackPoint point) => _db
      .into(_db.trackPoints)
      .insert(
        TrackPointsCompanion.insert(
          activityId: activityId,
          segment: point.segment,
          latitude: point.latitude,
          longitude: point.longitude,
          altitude: Value(point.altitude),
          accuracy: point.accuracy,
          speed: Value(point.speed),
          recordedAt: point.recordedAt,
        ),
      );

  Future<RecordingSession> pause(String activityId, DateTime at) async {
    await _updateActivity(
      activityId,
      ActivitiesCompanion(
        status: Value(RecordingStatus.paused.name),
        pausedAt: Value(at),
      ),
    );
    return _loadSession(activityId);
  }

  /// 다시 시작하면 일시정지한 시간을 더하고, 새 구간을 연다.
  Future<RecordingSession> resume(String activityId, DateTime at) async {
    await _db.transaction(() async {
      final row = await _activityRow(activityId);
      final pausedAt = row.pausedAt;
      final pausedMs = pausedAt == null
          ? row.pausedMs
          : row.pausedMs + at.difference(pausedAt).inMilliseconds;
      await _updateActivity(
        activityId,
        ActivitiesCompanion(
          status: Value(RecordingStatus.recording.name),
          pausedAt: const Value(null),
          pausedMs: Value(pausedMs),
          currentSegment: Value(row.currentSegment + 1),
        ),
      );
    });
    return _loadSession(activityId);
  }

  Future<void> finish(
    String activityId, {
    required DateTime endedAt,
    required TrackStats stats,
    required String title,
  }) async {
    final row = await _activityRow(activityId);
    await _updateActivity(
      activityId,
      ActivitiesCompanion(
        status: Value(RecordingStatus.finished.name),
        title: Value(title),
        endedAt: Value(endedAt),
        pausedAt: const Value(null),
        elapsedS: Value(endedAt.difference(row.startedAt).inSeconds),
        movingS: Value(stats.moving.inSeconds),
        distanceM: Value(stats.distanceM),
        elevationGainM: Value(stats.elevationGainM),
        maxAltitudeM: Value(stats.maxAltitudeM),
        pointCount: Value(stats.pointCount),
        isFlagged: Value(stats.isFlagged),
      ),
    );
  }

  Future<void> updateTitle(String activityId, String title) =>
      _updateActivity(activityId, ActivitiesCompanion(title: Value(title)));

  /// 앱이 기록 중에 꺼졌다면 그 기록을 찾는다.
  /// "기록 중"이던 기록은 마지막 위치를 받은 시각에 일시정지한 것으로 바꾼다.
  /// (앱이 꺼져 있던 시간이 기록 시간에 들어가지 않도록)
  Future<UnfinishedRecording?> loadUnfinished() async {
    final row =
        await (_db.select(_db.activities)
              ..where(
                (a) => a.status.isIn([
                  RecordingStatus.recording.name,
                  RecordingStatus.paused.name,
                ]),
              )
              ..orderBy([(a) => OrderingTerm.desc(a.startedAt)])
              ..limit(1))
            .getSingleOrNull();
    if (row == null) return null;

    final points = await loadPoints(row.id);
    if (row.status == RecordingStatus.recording.name) {
      await pause(row.id, points.lastOrNull?.recordedAt ?? row.startedAt);
    }
    return UnfinishedRecording(
      session: await _loadSession(row.id),
      points: points,
    );
  }

  Future<List<TrackPoint>> loadPoints(String activityId) async {
    final rows =
        await (_db.select(_db.trackPoints)
              ..where((p) => p.activityId.equals(activityId))
              ..orderBy([(p) => OrderingTerm.asc(p.id)]))
            .get();
    return [
      for (final r in rows)
        TrackPoint(
          segment: r.segment,
          latitude: r.latitude,
          longitude: r.longitude,
          altitude: r.altitude,
          accuracy: r.accuracy,
          speed: r.speed,
          recordedAt: r.recordedAt,
        ),
    ];
  }

  Future<ActivitySummary> loadSummary(String activityId) async =>
      activitySummaryFromRow(await _activityRow(activityId));

  Future<ActivityRow> _activityRow(String id) =>
      (_db.select(_db.activities)..where((a) => a.id.equals(id))).getSingle();

  Future<void> _updateActivity(String id, ActivitiesCompanion values) =>
      (_db.update(_db.activities)..where((a) => a.id.equals(id))).write(values);

  Future<RecordingSession> _loadSession(String id) async {
    final r = await _activityRow(id);
    return RecordingSession(
      activityId: r.id,
      status: RecordingStatus.values.byName(r.status),
      startedAt: r.startedAt,
      segment: r.currentSegment,
      pausedTotal: Duration(milliseconds: r.pausedMs),
      pausedAt: r.pausedAt,
    );
  }
}

final recordingRepositoryProvider = Provider<RecordingRepository>((ref) {
  return RecordingRepository(ref.watch(appDatabaseProvider));
});
