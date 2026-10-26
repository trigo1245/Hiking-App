import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_setup.dart';
import '../../courses/data/competition_remote.dart';
import '../../courses/domain/competition.dart';
import '../domain/achievements.dart';

/// 업적 계산에 필요한 서버 자료. 정복자 배지는 다른 사람 기록이 필요해 서버 함수가 계산한다.
abstract interface class AchievementRemote {
  /// 내가 코스 1위였던 기간 (get_my_lead_runs)
  Future<List<LeadRun>> fetchMyLeadRuns();

  /// 내가 쓴 리뷰의 작성 시각
  Future<List<DateTime>> fetchMyReviewDates();
}

class SupabaseAchievementRemote implements AchievementRemote {
  SupabaseAchievementRemote(this._client);

  final SupabaseClient _client;

  @override
  Future<List<LeadRun>> fetchMyLeadRuns() async {
    final rows = await _client.rpc<List<dynamic>>('get_my_lead_runs');
    return [
      for (final r in rows.cast<Map<String, dynamic>>())
        LeadRun(
          courseId: r['course_id'] as String,
          scope: r['scope'] as String,
          kind: RankingKind.values.byName(r['kind'] as String),
          startedAt: DateTime.parse(r['started_at'] as String),
          endedAt: r['ended_at'] == null
              ? null
              : DateTime.parse(r['ended_at'] as String),
          seasonFinal: r['season_final'] as bool,
        ),
    ];
  }

  @override
  Future<List<DateTime>> fetchMyReviewDates() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return const [];
    final rows = await _client
        .from('course_reviews')
        .select('created_at')
        .eq('user_id', userId);
    return [for (final r in rows) DateTime.parse(r['created_at'] as String)];
  }
}

final achievementRemoteProvider = Provider<AchievementRemote>((ref) {
  return SupabaseAchievementRemote(ref.watch(supabaseClientProvider));
});

/// 업적에 쓰는 서버 자료 묶음. 받지 못한 것은 null (인터넷 없음 등).
typedef AchievementServerData = ({
  List<MyCompletion>? completions,
  List<LeadRun>? leadRuns,
  List<DateTime>? reviewDates,
});

/// 서버 자료 세 가지를 함께 받는다. 하나가 실패해도 나머지는 쓴다.
Future<AchievementServerData> fetchAchievementServerData({
  required CompetitionRemote competition,
  required AchievementRemote achievements,
  Duration timeout = const Duration(seconds: 8),
}) async {
  Future<T?> attempt<T>(Future<T> Function() load) async {
    try {
      return await load().timeout(timeout);
    } catch (_) {
      return null;
    }
  }

  final (completions, leadRuns, reviewDates) = await (
    attempt(competition.fetchMyCompletions),
    attempt(achievements.fetchMyLeadRuns),
    attempt(achievements.fetchMyReviewDates),
  ).wait;
  return (
    completions: completions,
    leadRuns: leadRuns,
    reviewDates: reviewDates,
  );
}
