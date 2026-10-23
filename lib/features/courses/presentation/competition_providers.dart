import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/clock.dart';
import '../data/competition_remote.dart';
import '../domain/competition.dart';

/// 지금 시즌 (한국 시간 기준 반기)
final currentSeasonProvider = Provider<Season>(
  (ref) => Season.of(ref.watch(clockProvider)()),
);

/// 랭킹 조회 조건
typedef RankingQuery = ({String courseId, RankingKind kind, bool allTime});

/// 코스 상세의 랭킹 (상위 10명 + 내 순위, 전체 인원). 화면을 벗어나면 버리고, 다시 들어오면 새로 받는다.
final courseRankingProvider = FutureProvider.autoDispose
    .family<RankingPage, RankingQuery>((ref, q) {
      return ref
          .watch(competitionRemoteProvider)
          .fetchRanking(
            q.courseId,
            q.kind,
            season: q.allTime ? null : ref.watch(currentSeasonProvider),
          );
    }, retry: _noRetry);

final courseStatsProvider = FutureProvider.autoDispose
    .family<CourseStats, String>((ref, courseId) {
      return ref.watch(competitionRemoteProvider).fetchStats(courseId);
    }, retry: _noRetry);

/// 이번 시즌 코스별 정복자. 인터넷이 없으면 빈 목록 (지도는 정복자 없이 그린다).
final conquerorsProvider = FutureProvider<List<Conqueror>>((ref) async {
  try {
    return await ref
        .watch(competitionRemoteProvider)
        .fetchConquerors(ref.watch(currentSeasonProvider));
  } catch (_) {
    return const [];
  }
});

/// 자동 재시도를 하지 않는다. 인터넷이 없을 때 로딩이 오래 이어지지 않고
/// 바로 "다시 시도" 안내가 뜨게 하기 위해서다. (화면의 다시 시도 버튼으로 재요청)
Duration? _noRetry(int retryCount, Object error) => null;
