import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../recording/domain/recording_session.dart';
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
