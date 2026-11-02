import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/auth_providers.dart';
import '../../recording/data/recording_repository.dart';
import '../data/activities_repository.dart';
import '../data/activity_downloader.dart';
import '../data/activity_remote.dart';
import '../data/activity_uploader.dart';
import '../domain/activity_summary.dart';

/// 로그인한 사용자의 끝난 기록 (최신순). 업로드 상태가 바뀌면 자동으로 새로 온다.
final myActivitiesProvider = StreamProvider<List<ActivitySummary>>((ref) {
  final userId = ref.watch(currentUserProvider.select((u) => u.value?.id));
  if (userId == null) return Stream.value(const []);
  return ref.watch(activitiesRepositoryProvider).watchFinished(userId);
});

/// 화면에서 업로드를 요청하는 창구. 로그인하지 않았으면 아무것도 하지 않는다.
class UploadActions {
  UploadActions(this._ref);

  final Ref _ref;

  String? get _userId => _ref.read(authRepositoryProvider).currentUser?.id;

  /// [force]: 이미 올라간 기록도 다시 올린다. 성공하면 true.
  Future<bool> upload(String activityId, {bool force = false}) async {
    final userId = _userId;
    if (userId == null) return false;
    return _ref
        .read(activityUploaderProvider)
        .upload(activityId, userId: userId, force: force);
  }

  Future<void> uploadPending() async {
    final userId = _userId;
    if (userId == null) return;
    await _ref.read(activityUploaderProvider).uploadPending(userId: userId);
  }

  /// 기록 제목을 바꾼다. 기기에 먼저 저장하고, 이미 올라간 기록이면 서버 제목도 바꾼다.
  /// 서버에 바꾸지 못하면(인터넷 없음 등) "업로드 대기"로 돌려, 다음 업로드 때 새 제목이 올라가게 한다.
  /// 서버까지 바꿨으면 true.
  Future<bool> rename(String activityId, String title) async {
    final recording = _ref.read(recordingRepositoryProvider);
    await recording.updateTitle(activityId, title);
    final userId = _userId;
    if (userId == null) return false;
    final summary = await recording.loadSummary(activityId);
    if (summary.uploadStatus != UploadStatus.done) return false;
    try {
      await _ref.read(activityRemoteProvider).updateTitle(activityId, title);
      return true;
    } catch (_) {
      await _ref
          .read(activitiesRepositoryProvider)
          .setUploadStatus(activityId, UploadStatus.pending, userId: userId);
      return false;
    }
  }

  /// 기록을 서버에서 지운다. 실패하면(인터넷 없음 등) 오류를 던지고, 이때는 기기에서도 지우지 않는다.
  /// (기기에서만 지우면 "기기 간 동기화"가 서버에서 다시 받아 오기 때문)
  Future<void> deleteFromServer(String activityId) async {
    final userId = _userId;
    if (userId == null) throw StateError('로그인이 필요해요');
    await _ref
        .read(activityRemoteProvider)
        .deleteActivity(activityId, gpxPath: gpxPathFor(userId, activityId));
  }

  /// 기록을 이 기기에서 지운다. [deleteFromServer]가 성공한 뒤에 부른다.
  Future<void> deleteFromDevice(String activityId) =>
      _ref.read(activitiesRepositoryProvider).deleteById(activityId);

  /// 서버에 있지만 이 기기에 없는 내 기록을 받는다 (다른 기기·재설치).
  Future<void> downloadMissing() async {
    final userId = _userId;
    if (userId == null) return;
    await _ref.read(activityDownloaderProvider).downloadMissing(userId: userId);
  }
}

final uploadActionsProvider = Provider<UploadActions>(UploadActions.new);
