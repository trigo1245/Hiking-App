import 'package:hiking_app/features/achievements/data/achievement_remote.dart';
import 'package:hiking_app/features/achievements/domain/achievements.dart';

/// 서버 대신 1위 기간·리뷰 날짜를 돌려주는 가짜
class FakeAchievementRemote implements AchievementRemote {
  List<LeadRun> leadRuns = [];
  List<DateTime> reviewDates = [];

  /// true면 인터넷이 없는 것처럼 실패한다.
  bool offline = false;

  @override
  Future<List<LeadRun>> fetchMyLeadRuns() async {
    if (offline) throw Exception('offline');
    return leadRuns;
  }

  @override
  Future<List<DateTime>> fetchMyReviewDates() async {
    if (offline) throw Exception('offline');
    return reviewDates;
  }
}
