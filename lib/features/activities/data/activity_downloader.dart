import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/gpx_reader.dart';
import 'activities_repository.dart';
import 'activity_remote.dart';

/// 서버에 올라간 내 기록 중 이 기기에 없는 것을 받아 저장한다.
/// 다른 기기에서 로그인하거나 앱을 다시 설치해도 기록·상세 분석·통계가 이어진다.
/// 1) 서버의 내 기록 요약 목록을 받고 2) 기기에 없는 기록만 골라 GPX를 받아
/// 3) 요약과 위치 점을 "업로드 완료" 상태로 기기 DB에 넣는다.
class ActivityDownloader {
  ActivityDownloader({required this._activities, required this._remote});

  final ActivitiesRepository _activities;
  final ActivityRemote _remote;

  /// 진행 중인 받기 작업. 앱을 여닫으며 여러 번 불려도 한 번만 돈다.
  Future<int>? _running;

  /// 받은 기록 수를 돌려준다. 인터넷이 없으면 0 (다음 기회에 다시 시도).
  Future<int> downloadMissing({required String userId}) =>
      _running ??= _download(userId).whenComplete(() => _running = null);

  Future<int> _download(String userId) async {
    final List<Map<String, dynamic>> rows;
    try {
      rows = await _remote.fetchMyActivities();
    } catch (error) {
      debugPrint('[download] 서버 기록 목록 받기 실패: $error');
      return 0;
    }
    final local = await _activities.localIds();
    var count = 0;
    for (final row in rows) {
      final id = row['id'] as String;
      final path = row['gpx_path'] as String?;
      if (local.contains(id) || path == null) continue;
      try {
        final points = parseGpx(await _remote.downloadGpx(path));
        await _activities.insertDownloaded(
          activitySummaryFromServer(row),
          userId: userId,
          points: points,
        );
        count++;
      } catch (error) {
        // 하나가 실패해도 나머지는 계속 받는다. 실패한 것은 다음에 다시 시도한다.
        debugPrint('[download] $id 받기 실패: $error');
      }
    }
    return count;
  }
}

final activityDownloaderProvider = Provider<ActivityDownloader>((ref) {
  return ActivityDownloader(
    activities: ref.watch(activitiesRepositoryProvider),
    remote: ref.watch(activityRemoteProvider),
  );
});
