import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../courses/data/course_repository.dart';
import '../../courses/domain/course.dart';
import '../../courses/domain/course_matching.dart';
import '../../recording/data/recording_repository.dart';
import '../domain/activity_summary.dart';
import '../domain/gpx_writer.dart';
import 'activities_repository.dart';
import 'activity_remote.dart';

/// 끝난 기록을 서버에 올린다.
/// 1) 경로를 GPX로 만들어 Storage에 올리고 2) 요약을 activities 테이블에 넣고
/// 3) 기기에 저장된 코스와 비교해 완주한 코스를 판정해 보낸다(랭킹 재료).
/// GPX를 먼저 올려서, 서버 행이 없는 파일을 가리키는 일이 없게 한다.
class ActivityUploader {
  ActivityUploader({
    required this._activities,
    required this._recording,
    required this._remote,
    required this._loadCourses,
  });

  final ActivitiesRepository _activities;
  final RecordingRepository _recording;
  final ActivityRemote _remote;
  final Future<List<Course>> Function() _loadCourses;

  /// 작업을 한 줄로 세워, 같은 기록을 동시에 두 번 올리지 않게 한다.
  Future<void> _queue = Future.value();

  /// 기록 하나를 올린다. 성공하면 true.
  /// [force]: 이미 올라간 기록도 다시 올린다 (기록 상세의 "다시 올리기").
  Future<bool> upload(
    String activityId, {
    required String userId,
    bool force = false,
  }) {
    final result = _queue.then(
      (_) => _upload(activityId, userId, force: force),
    );
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

  Future<bool> _upload(
    String activityId,
    String userId, {
    bool force = false,
  }) async {
    try {
      final summary = await _recording.loadSummary(activityId);
      if (!force && summary.uploadStatus == UploadStatus.done) return true;

      final points = await _recording.loadPoints(activityId);
      final path = gpxPathFor(userId, activityId);
      await _remote.uploadGpx(
        path: path,
        gpx: buildGpx(title: summary.title, points: points),
      );
      await _remote.upsertActivity(
        activityRow(summary, userId: userId, gpxPath: path),
      );
      // 속도 이상 기록은 완주·진행률을 인정하지 않는다. (서버도 한 번 더 확인한다)
      final courses = summary.isFlagged
          ? const <Course>[]
          : await _loadCourses();
      await _remote.recordCompletions(
        activityId,
        CourseMatcher.matchAll(courses, points),
      );
      // 정상까지 가지 않은 코스는 몇 %까지 갔는지 남긴다. (리뷰 자격, 기록 표시)
      await _remote.recordAttempts(
        activityId,
        CourseMatcher.progressAll(courses, points),
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
    loadCourses: () => ref.read(courseRepositoryProvider).watchAll().first,
  );
});
