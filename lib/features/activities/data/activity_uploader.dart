import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../recording/data/recording_repository.dart';
import '../domain/activity_summary.dart';
import '../domain/gpx_writer.dart';
import 'activities_repository.dart';
import 'activity_remote.dart';

/// 끝난 기록을 서버에 올린다.
/// 1) 경로를 GPX로 만들어 Storage에 올리고 2) 요약을 activities 테이블에 넣는다.
/// GPX를 먼저 올려서, 서버 행이 없는 파일을 가리키는 일이 없게 한다.
class ActivityUploader {
  ActivityUploader({
    required this._activities,
    required this._recording,
    required this._remote,
  });

  final ActivitiesRepository _activities;
  final RecordingRepository _recording;
  final ActivityRemote _remote;

  /// 작업을 한 줄로 세워, 같은 기록을 동시에 두 번 올리지 않게 한다.
  Future<void> _queue = Future.value();

  /// 기록 하나를 올린다. 성공하면 true.
  Future<bool> upload(String activityId, {required String userId}) {
    final result = _queue.then((_) => _upload(activityId, userId));
    _queue = result.then((_) {});
    return result;
  }

  /// 아직 올라가지 않은 기록을 모두 올린다.
  Future<void> uploadPending({required String userId}) {
    final result = _queue.then((_) async {
      for (final id in await _activities.pendingUploadIds(userId)) {
        await _upload(id, userId);
      }
    });
    _queue = result;
    return result;
  }

  Future<bool> _upload(String activityId, String userId) async {
    try {
      final summary = await _recording.loadSummary(activityId);
      if (summary.uploadStatus == UploadStatus.done) return true;

      final points = await _recording.loadPoints(activityId);
      final path = '$userId/$activityId.gpx';
      await _remote.uploadGpx(
        path: path,
        gpx: buildGpx(title: summary.title, points: points),
      );
      await _remote.upsertActivity(
        activityRow(summary, userId: userId, gpxPath: path),
      );
      await _activities.setUploadStatus(
        activityId,
        UploadStatus.done,
        userId: userId,
      );
      return true;
    } catch (error) {
      debugPrint('[upload] $activityId 업로드 실패: $error');
      // 서버가 거절했으면 "실패", 네트워크 문제면 "대기"로 두고 다음에 다시 시도한다.
      await _activities.setUploadStatus(
        activityId,
        isServerRejection(error) ? UploadStatus.failed : UploadStatus.pending,
        userId: userId,
      );
      return false;
    }
  }
}

final activityUploaderProvider = Provider<ActivityUploader>((ref) {
  return ActivityUploader(
    activities: ref.watch(activitiesRepositoryProvider),
    recording: ref.watch(recordingRepositoryProvider),
    remote: ref.watch(activityRemoteProvider),
  );
});
