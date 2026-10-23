import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_setup.dart';
import '../../courses/domain/course_matching.dart';
import '../domain/activity_summary.dart';

/// 서버로 기록을 보내는 창구. 테스트에서는 가짜로 바꿔 끼운다.
abstract interface class ActivityRemote {
  /// tracks 버킷의 [path]에 GPX를 올린다. 이미 있으면 덮어쓴다.
  Future<void> uploadGpx({required String path, required String gpx});

  /// activities 테이블에 요약을 넣는다. 같은 id가 있으면 덮어쓴다(upsert).
  Future<void> upsertActivity(Map<String, Object?> row);

  /// 앱이 판정한 코스 완주 결과를 저장한다. 같은 기록의 이전 결과는 바뀐다.
  Future<void> recordCompletions(
    String activityId,
    List<CourseCompletion> completions,
  );

  /// 정상까지 가지 않은 코스의 진행률을 저장한다. 같은 기록의 이전 결과는 바뀐다.
  Future<void> recordAttempts(String activityId, List<CourseProgress> attempts);

  /// 서버에 올라간 내 기록 요약 전체 (다른 기기에서 기록을 받을 때). RLS로 본인 행만 온다.
  Future<List<Map<String, dynamic>>> fetchMyActivities();

  /// tracks 버킷의 [path]에 있는 GPX를 받는다.
  Future<String> downloadGpx(String path);

  /// 기록을 서버에서 지운다. 요약 행을 지우면 완주·진행률 기록도 함께 지워진다(cascade).
  /// 서버에 없는 기록이면 아무 일도 하지 않는다. 인터넷이 없으면 오류를 던진다.
  Future<void> deleteActivity(String activityId, {required String gpxPath});
}

/// 서버가 요청을 받고 거절한 오류인지. (아니면 네트워크 문제로 본다)
bool isServerRejection(Object error) =>
    error is StorageException || error is PostgrestException;

class SupabaseActivityRemote implements ActivityRemote {
  SupabaseActivityRemote(this._client);

  final SupabaseClient _client;

  @override
  Future<void> uploadGpx({required String path, required String gpx}) async {
    await _client.storage
        .from('tracks')
        .uploadBinary(
          path,
          utf8.encode(gpx),
          fileOptions: const FileOptions(
            upsert: true,
            contentType: 'application/gpx+xml',
          ),
        );
  }

  @override
  Future<void> upsertActivity(Map<String, Object?> row) async {
    await _client.from('activities').upsert(row);
  }

  @override
  Future<void> recordCompletions(
    String activityId,
    List<CourseCompletion> completions,
  ) async {
    await _client.rpc(
      'record_course_completions',
      params: {
        'p_activity_id': activityId,
        'p_completions': [
          for (final c in completions)
            {
              'course_id': c.courseId,
              'ascent_s': c.ascent.inSeconds,
              'completed_at': c.reachedSummitAt.toUtc().toIso8601String(),
            },
        ],
      },
    );
  }

  @override
  Future<void> recordAttempts(
    String activityId,
    List<CourseProgress> attempts,
  ) async {
    await _client.rpc(
      'record_course_attempts',
      params: {
        'p_activity_id': activityId,
        'p_attempts': [
          for (final a in attempts)
            {
              'course_id': a.courseId,
              'progress': a.progress,
              'attempted_at': a.startedAt.toUtc().toIso8601String(),
            },
        ],
      },
    );
  }

  @override
  Future<List<Map<String, dynamic>>> fetchMyActivities() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return const [];
    return _client.from('activities').select().eq('user_id', userId);
  }

  @override
  Future<void> deleteActivity(
    String activityId, {
    required String gpxPath,
  }) async {
    // 행을 먼저 지운다. (다른 기기가 목록에서 다시 받아 가지 않도록)
    await _client.from('activities').delete().eq('id', activityId);
    try {
      await _client.storage.from('tracks').remove([gpxPath]);
    } catch (e) {
      // 파일만 남는 것은 문제가 되지 않는다. (아무도 가리키지 않는 파일)
      debugPrint('[delete] GPX 파일을 지우지 못했어요: $e');
    }
  }

  @override
  Future<String> downloadGpx(String path) async {
    final bytes = await _client.storage.from('tracks').download(path);
    return utf8.decode(bytes);
  }
}

/// 서버 activities 행을 요약으로 바꾼다. 서버에 있으니 업로드 상태는 "완료"다.
ActivitySummary activitySummaryFromServer(Map<String, dynamic> r) {
  DateTime time(String key) => DateTime.parse(r[key] as String).toLocal();
  double? real(String key) => (r[key] as num?)?.toDouble();
  final startedAt = time('started_at');
  return ActivitySummary(
    id: r['id'] as String,
    title: (r['title'] as String?) ?? '',
    startedAt: startedAt,
    endedAt: r['ended_at'] == null ? startedAt : time('ended_at'),
    elapsed: Duration(seconds: (r['elapsed_s'] as int?) ?? 0),
    moving: Duration(seconds: (r['moving_s'] as int?) ?? 0),
    distanceM: real('distance_m') ?? 0,
    elevationGainM: real('elevation_gain_m') ?? 0,
    maxAltitudeM: real('max_altitude_m'),
    pointCount: (r['point_count'] as int?) ?? 0,
    isFlagged: (r['is_flagged'] as bool?) ?? false,
    uploadStatus: UploadStatus.done,
  );
}

/// tracks 버킷 안의 GPX 경로 (CLAUDE.md 7장: {user_id}/{activity_id}.gpx)
String gpxPathFor(String userId, String activityId) =>
    '$userId/$activityId.gpx';

/// 서버 activities 테이블 한 행. (CLAUDE.md 7장)
Map<String, Object?> activityRow(
  ActivitySummary a, {
  required String userId,
  required String gpxPath,
}) => {
  'id': a.id,
  'user_id': userId,
  'title': a.title,
  'started_at': a.startedAt.toUtc().toIso8601String(),
  'ended_at': a.endedAt.toUtc().toIso8601String(),
  'elapsed_s': a.elapsed.inSeconds,
  'moving_s': a.moving.inSeconds,
  'distance_m': a.distanceM,
  'elevation_gain_m': a.elevationGainM,
  'max_altitude_m': a.maxAltitudeM,
  'point_count': a.pointCount,
  'gpx_path': gpxPath,
  'is_flagged': a.isFlagged,
};

final activityRemoteProvider = Provider<ActivityRemote>((ref) {
  return SupabaseActivityRemote(ref.watch(supabaseClientProvider));
});
