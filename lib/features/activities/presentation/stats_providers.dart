import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../courses/data/competition_remote.dart';
import '../../courses/domain/competition.dart';
import '../../recording/data/recording_repository.dart';
import '../domain/activity_analysis.dart';
import '../domain/activity_summary.dart';
import 'activities_providers.dart';

/// 서버에 기록된 내 코스 완주 (완등 횟수·자주 간 코스·코스별 최고 기록).
/// 인터넷이 없으면 null을 돌려주고, 통계 화면은 완등 칸만 "-"로 보여 준다.
final myCompletionsProvider = FutureProvider<List<MyCompletion>?>((ref) async {
  ref.watch(myActivitiesProvider); // 새 기록이 생기면 다시 받는다.
  try {
    return await ref.watch(competitionRemoteProvider).fetchMyCompletions();
  } catch (_) {
    return null;
  }
});

/// 구독자 종합 분석에 쓰는 산행별 상세 분석. 구독자 화면에서만 계산한다.
/// 기기에 저장된 위치 기록으로 계산하므로 인터넷이 없어도 된다.
final myAnalysesProvider =
    FutureProvider<List<(ActivitySummary, ActivityAnalysis)>>((ref) async {
      final activities = await ref.watch(myActivitiesProvider.future);
      final recording = ref.watch(recordingRepositoryProvider);
      return [
        for (final a in activities)
          (a, ActivityAnalyzer.analyze(await recording.loadPoints(a.id))),
      ];
    });
