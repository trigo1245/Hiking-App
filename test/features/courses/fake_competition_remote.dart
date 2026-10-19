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

  @override
  Future<List<RankingEntry>> fetchRanking(
    String courseId,
    RankingKind kind, {
    Season? season,
  }) async {
    requests.add('$courseId ${kind.name} ${season?.id ?? 'alltime'}');
    if (failWith case final error?) throw error;
    return rankings[(kind, season == null)] ?? const [];
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
}

RankingEntry entry(int rank, String name, int value, {bool isMe = false}) =>
    RankingEntry(
      rank: rank,
      nickname: name,
      nicknameTag: '${1000 + rank}',
      value: value,
      isMe: isMe,
    );
