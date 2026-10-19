import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_setup.dart';
import '../domain/activity_summary.dart';

/// 서버로 기록을 보내는 창구. 테스트에서는 가짜로 바꿔 끼운다.
abstract interface class ActivityRemote {
  /// tracks 버킷의 [path]에 GPX를 올린다. 이미 있으면 덮어쓴다.
  Future<void> uploadGpx({required String path, required String gpx});

  /// activities 테이블에 요약을 넣는다. 같은 id가 있으면 덮어쓴다(upsert).
  Future<void> upsertActivity(Map<String, Object?> row);
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
}

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
