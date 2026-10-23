import 'package:hiking_app/features/courses/data/competition_remote.dart';
import 'package:hiking_app/features/courses/domain/competition.dart';

/// 서버 대신 정해 둔 랭킹을 돌려주는 가짜. [failWith]를 정하면 그 오류를 던진다.
class FakeCompetitionRemote implements CompetitionRemote {
  /// (최다완등/최단시간, 역대 여부) → 랭킹
  final rankings = <(RankingKind, bool), List<RankingEntry>>{};
  CourseStats stats = const CourseStats(completionCount: 0);
  List<Conqueror> conquerors = const [];
  Object? failWith;
  final requests = <String>[];

  /// 전체 인원을 따로 정하고 싶을 때 (없으면 랭킹 줄 수)
  int? total;

  /// 전체 순위 화면 요청 기록: "offset limit 검색어"
  final pageRequests = <String>[];

  @override
  Future<RankingPage> fetchRanking(
    String courseId,
    RankingKind kind, {
    Season? season,
  }) async {
    requests.add('$courseId ${kind.name} ${season?.id ?? 'alltime'}');
    if (failWith case final error?) throw error;
    final all = rankings[(kind, season == null)] ?? const <RankingEntry>[];
    // 서버처럼 상위 10명 + 내 순위만 돌려준다.
    return RankingPage(
      entries: [
        for (final (i, e) in all.indexed)
          if (i < 10 || e.isMe) e,
      ],
      total: total ?? all.length,
    );
  }

  @override
  Future<RankingPage> fetchRankingPage(
    String courseId,
    RankingKind kind, {
    Season? season,
    int offset = 0,
    int limit = 30,
    String? query,
  }) async {
    pageRequests.add('$offset $limit ${query ?? ''}');
    if (failWith case final error?) throw error;
    final all = [
      for (final e
          in rankings[(kind, season == null)] ?? const <RankingEntry>[])
        if (query == null || query.isEmpty || e.displayName.contains(query)) e,
    ];
    return RankingPage(
      entries: all.skip(offset).take(limit).toList(),
      total: all.length,
    );
  }

  @override
  Future<CourseStats> fetchStats(String courseId) async {
    if (failWith case final error?) throw error;
    return stats;
  }

  @override
  Future<List<Conqueror>> fetchConquerors(Season season) async {
    if (failWith case final error?) throw error;
    return conquerors;
  }

  List<MyCompletion> myCompletions = const [];

  @override
  Future<List<MyCompletion>> fetchMyCompletions() async {
    if (failWith case final error?) throw error;
    return myCompletions;
  }
}

RankingEntry entry(int rank, String name, int value, {bool isMe = false}) =>
    RankingEntry(
      rank: rank,
      nickname: name,
      nicknameTag: '${1000 + rank}',
      value: value,
      isMe: isMe,
    );
