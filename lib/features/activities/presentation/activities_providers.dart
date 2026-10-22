import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/auth_providers.dart';
import '../data/activities_repository.dart';
import '../data/activity_downloader.dart';
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

  /// 서버에 있지만 이 기기에 없는 내 기록을 받는다 (다른 기기·재설치).
  Future<void> downloadMissing() async {
    final userId = _userId;
    if (userId == null) return;
    await _ref.read(activityDownloaderProvider).downloadMissing(userId: userId);
  }
}

final uploadActionsProvider = Provider<UploadActions>(UploadActions.new);
