import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_setup.dart';
import '../domain/competition.dart';

/// 랭킹·정복자를 서버에서 받는 창구. 계산은 서버 DB 함수가 한다(조작 방지).
abstract interface class CompetitionRemote {
  /// [season]이 null이면 역대 기록(명예의 전당)
  Future<List<RankingEntry>> fetchRanking(
    String courseId,
    RankingKind kind, {
    Season? season,
  });

  Future<CourseStats> fetchStats(String courseId);

  Future<List<Conqueror>> fetchConquerors(Season season);

  /// 내 코스 완주 전체 (통계용). 다른 사람 행은 RLS로 막혀 있다.
  Future<List<MyCompletion>> fetchMyCompletions();
}

class SupabaseCompetitionRemote implements CompetitionRemote {
  SupabaseCompetitionRemote(this._client);

  final SupabaseClient _client;

  @override
  Future<List<RankingEntry>> fetchRanking(
    String courseId,
    RankingKind kind, {
    Season? season,
  }) async {
    final rows = await _client.rpc<List<dynamic>>(
      'get_course_ranking',
      params: {
        'p_course_id': courseId,
        'p_kind': kind.name,
        'p_season': season?.id,
      },
    );
    return [
      for (final r in rows.cast<Map<String, dynamic>>())
        RankingEntry(
          rank: r['rank_no'] as int,
          nickname: r['nickname'] as String,
          nicknameTag: r['nickname_tag'] as String,
          avatarUrl: r['avatar_url'] as String?,
          value: r['score'] as int,
          isMe: r['is_me'] as bool,
        ),
    ];
  }

  @override
  Future<CourseStats> fetchStats(String courseId) async {
    final rows = await _client.rpc<List<dynamic>>(
      'get_course_stats',
      params: {'p_course_id': courseId},
    );
    final r = rows.cast<Map<String, dynamic>>().first;
    Duration? seconds(Object? v) =>
        v == null ? null : Duration(seconds: v as int);
    return CourseStats(
      completionCount: r['completion_count'] as int,
      averageAscent: seconds(r['average_ascent_s']),
      myBestAscent: seconds(r['my_best_ascent_s']),
      myCount: r['my_count'] as int,
    );
  }

  @override
  Future<List<Conqueror>> fetchConquerors(Season season) async {
    final rows = await _client.rpc<List<dynamic>>(
      'get_conquerors',
      params: {'p_season': season.id},
    );
    return [
      for (final r in rows.cast<Map<String, dynamic>>())
        Conqueror(
          courseId: r['course_id'] as String,
          kind: RankingKind.values.byName(r['kind'] as String),
          nickname: r['nickname'] as String,
          nicknameTag: r['nickname_tag'] as String,
          avatarUrl: r['avatar_url'] as String?,
          value: r['score'] as int,
        ),
    ];
  }

  @override
  Future<List<MyCompletion>> fetchMyCompletions() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return const [];
    final rows = await _client
        .from('course_completions')
        .select('course_id, ascent_s, completed_at')
        .eq('user_id', userId);
    return [
      for (final r in rows)
        MyCompletion(
          courseId: r['course_id'] as String,
          ascent: Duration(seconds: r['ascent_s'] as int),
          completedAt: DateTime.parse(r['completed_at'] as String),
        ),
    ];
  }
}

final competitionRemoteProvider = Provider<CompetitionRemote>((ref) {
  return SupabaseCompetitionRemote(ref.watch(supabaseClientProvider));
});
