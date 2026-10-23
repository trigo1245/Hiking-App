import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../recording/domain/recording_session.dart';
import '../../recording/domain/track_point.dart';
import '../domain/activity_summary.dart';

/// DB 행을 화면에서 쓰는 요약으로 바꾼다.
ActivitySummary activitySummaryFromRow(ActivityRow r) => ActivitySummary(
  id: r.id,
  title: r.title ?? defaultActivityTitle(r.startedAt),
  startedAt: r.startedAt,
  endedAt: r.endedAt ?? r.startedAt,
  elapsed: Duration(seconds: r.elapsedS ?? 0),
  moving: Duration(seconds: r.movingS ?? 0),
  distanceM: r.distanceM ?? 0,
  elevationGainM: r.elevationGainM ?? 0,
  maxAltitudeM: r.maxAltitudeM,
  pointCount: r.pointCount ?? 0,
  isFlagged: r.isFlagged,
  uploadStatus: UploadStatus.values.byName(r.uploadStatus),
);

/// 기기 DB에 저장된 끝난 기록 목록과 업로드 상태.
class ActivitiesRepository {
  ActivitiesRepository(this._db);

  final AppDatabase _db;

  /// [userId]의 끝난 기록을 최신순으로 보내고, 바뀔 때마다 다시 보낸다.
  /// 사용자 ID가 없던 예전 기록(스키마 1)도 함께 보여 준다.
  Stream<List<ActivitySummary>> watchFinished(String userId) {
    final query = _db.select(_db.activities)
      ..where(
        (a) =>
            a.status.equals(RecordingStatus.finished.name) &
            (a.userId.equals(userId) | a.userId.isNull()),
      )
      ..orderBy([(a) => OrderingTerm.desc(a.startedAt)]);
    return query.watch().map(
      (rows) => rows.map(activitySummaryFromRow).toList(),
    );
  }

  /// 아직 서버에 올라가지 않은 [userId]의 끝난 기록 ID (오래된 것부터)
  Future<List<String>> pendingUploadIds(String userId) async {
    final query = _db.select(_db.activities)
      ..where(
        (a) =>
            a.status.equals(RecordingStatus.finished.name) &
            a.uploadStatus.equals(UploadStatus.done.name).not() &
            (a.userId.equals(userId) | a.userId.isNull()),
      )
      ..orderBy([(a) => OrderingTerm.asc(a.startedAt)]);
    return [for (final r in await query.get()) r.id];
  }

  /// 기기에 있는 모든 기록 ID (기록 중인 것 포함, 계정 구분 없이)
  Future<Set<String>> localIds() async {
    final rows = await (_db.selectOnly(
      _db.activities,
    )..addColumns([_db.activities.id])).get();
    return {for (final r in rows) r.read(_db.activities.id)!};
  }

  /// [userId]의 기록 중 제목이 [prefix]로 시작하는 것을 지운다 (시연용 기록 정리용).
  /// 위치 점은 외래 키(cascade)로 함께 지워진다. 지운 개수를 돌려준다.
  Future<int> deleteByTitlePrefix(String userId, String prefix) {
    return (_db.delete(_db.activities)..where(
          (a) =>
              a.title.like('${prefix.replaceAll('%', r'\%')}%') &
              (a.userId.equals(userId) | a.userId.isNull()),
        ))
        .go();
  }

  /// 서버에서 받은 기록을 끝난 기록·업로드 완료 상태로 저장한다. 요약과 점을 한 번에 넣는다.
  Future<void> insertDownloaded(
    ActivitySummary s, {
    required String userId,
    required List<TrackPoint> points,
  }) async {
    await _db.transaction(() async {
      await _db
          .into(_db.activities)
          .insert(
            ActivitiesCompanion.insert(
              id: s.id,
              userId: Value(userId),
              title: Value(s.title.isEmpty ? null : s.title),
              status: RecordingStatus.finished.name,
              startedAt: s.startedAt,
              endedAt: Value(s.endedAt),
              currentSegment: Value(points.isEmpty ? 0 : points.last.segment),
              elapsedS: Value(s.elapsed.inSeconds),
              movingS: Value(s.moving.inSeconds),
              distanceM: Value(s.distanceM),
              elevationGainM: Value(s.elevationGainM),
              maxAltitudeM: Value(s.maxAltitudeM),
              pointCount: Value(s.pointCount),
              isFlagged: Value(s.isFlagged),
              uploadStatus: Value(UploadStatus.done.name),
              createdAt: s.startedAt,
            ),
          );
      await _db.batch(
        (b) => b.insertAll(_db.trackPoints, [
          for (final p in points)
            TrackPointsCompanion.insert(
              activityId: s.id,
              segment: p.segment,
              latitude: p.latitude,
              longitude: p.longitude,
              altitude: Value(p.altitude),
              accuracy: p.accuracy,
              recordedAt: p.recordedAt,
            ),
        ]),
      );
    });
  }

  /// 업로드 상태를 바꾼다. 사용자 ID가 없던 예전 기록은 이때 [userId]로 채운다.
  Future<void> setUploadStatus(
    String activityId,
    UploadStatus status, {
    required String userId,
  }) async {
    await _db.transaction(() async {
      await (_db.update(_db.activities)..where((a) => a.id.equals(activityId)))
          .write(ActivitiesCompanion(uploadStatus: Value(status.name)));
      await (_db.update(_db.activities)
            ..where((a) => a.id.equals(activityId) & a.userId.isNull()))
          .write(ActivitiesCompanion(userId: Value(userId)));
    });
  }
}

final activitiesRepositoryProvider = Provider<ActivitiesRepository>((ref) {
  return ActivitiesRepository(ref.watch(appDatabaseProvider));
});
