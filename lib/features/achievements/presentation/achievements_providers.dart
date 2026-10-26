import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/clock.dart';
import '../../activities/data/activities_repository.dart';
import '../../activities/domain/activity_summary.dart';
import '../../activities/presentation/activities_providers.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../courses/data/competition_remote.dart';
import '../../courses/data/course_repository.dart';
import '../data/achievement_remote.dart';
import '../domain/achievements.dart';

/// 내 업적. 기록이 바뀌면(새 기록·업로드 완료·삭제) 서버 자료까지 다시 받아 계산한다.
final myAchievementsProvider = FutureProvider<Achievements>((ref) async {
  final activities = await ref.watch(myActivitiesProvider.future);
  final server = await ref.read(achievementCheckerProvider).fetchServer();
  return achievementsOf(activities, server, ref.read(clockProvider)());
});

Achievements achievementsOf(
  List<ActivitySummary> activities,
  AchievementServerData server,
  DateTime now,
) => Achievements.of(
  activities: activities,
  completions: server.completions,
  leadRuns: server.leadRuns,
  reviewDates: server.reviewDates,
  now: now,
);

/// 코스 id → "산 이름 코스 이름" (시즌 정복 배지 이름에 쓴다)
final courseNamesProvider = Provider<Map<String, String>>((ref) {
  final courses = ref.watch(coursesProvider).value ?? const [];
  return {for (final c in courses) c.id: '${c.mountainName} ${c.name}'};
});

/// 기록 저장 전후의 업적을 비교해 새로 얻은 배지를 찾는다.
class AchievementChecker {
  AchievementChecker(this._ref);

  final Ref _ref;

  Future<AchievementServerData> fetchServer({
    Duration timeout = const Duration(seconds: 8),
  }) => fetchAchievementServerData(
    competition: _ref.read(competitionRemoteProvider),
    achievements: _ref.read(achievementRemoteProvider),
    timeout: timeout,
  );

  DateTime get _now => _ref.read(clockProvider)();

  /// 기기에 저장된 내 끝난 기록. (지켜보는 화면이 없을 때도 바로 읽히도록 저장소에서 직접 읽는다)
  Future<List<ActivitySummary>> _activities() async {
    final userId = _ref.read(authRepositoryProvider).currentUser?.id;
    if (userId == null) return const [];
    return _ref.read(activitiesRepositoryProvider).watchFinished(userId).first;
  }

  /// [activityId] 기록이 없었을 때와 있을 때의 업적. 서버 자료는 [server]를 함께 쓴다.
  Future<(Achievements, Achievements)> deviceBeforeAfter(
    String activityId,
    AchievementServerData server,
  ) async {
    final all = await _activities();
    final without = [
      for (final a in all)
        if (a.id != activityId) a,
    ];
    return (
      achievementsOf(without, server, _now),
      achievementsOf(all, server, _now),
    );
  }

  /// 서버 자료만 새로 받아 다시 계산한다 (업로드 뒤 완등·정복 배지 확인).
  Future<Achievements> refreshed() async {
    final all = await _activities();
    return achievementsOf(all, await fetchServer(), _now);
  }
}

final achievementCheckerProvider = Provider<AchievementChecker>(
  AchievementChecker.new,
);
