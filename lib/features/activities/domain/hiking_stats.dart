import '../../courses/domain/competition.dart';
import 'activity_analysis.dart';
import 'activity_summary.dart';

/// 통계를 볼 기간. 시즌은 랭킹과 같은 반기(한국 시간)다.
enum StatsPeriod {
  season,
  year,
  all;

  /// 이 기간이 시작되는 시각. 전체면 null.
  DateTime? startAt(DateTime now) {
    const kstOffset = Duration(hours: 9);
    final kst = now.toUtc().add(kstOffset);
    return switch (this) {
      StatsPeriod.season => DateTime.utc(
        kst.year,
        kst.month <= 6 ? 1 : 7,
      ).subtract(kstOffset),
      StatsPeriod.year => DateTime.utc(kst.year).subtract(kstOffset),
      StatsPeriod.all => null,
    };
  }

  bool includes(DateTime time, DateTime now) {
    final start = startAt(now);
    return start == null || !time.isBefore(start);
  }
}

/// 월별 등산 횟수 한 칸
typedef MonthCount = ({int year, int month, int count});

/// 코스별 횟수·최고 기록
typedef CourseRecord = ({String courseId, int count, Duration best});

/// 모두가 보는 통계
class HikingStats {
  const HikingStats({
    required this.hikeCount,
    required this.completionCount,
    required this.distanceM,
    required this.elevationGainM,
    required this.elapsed,
    required this.monthly,
    required this.weekStreak,
    required this.topCourses,
    this.averageIntervalDays,
    this.daysSinceLast,
  });

  /// 에베레스트 높이 (누적 오른 높이 비유에 쓴다)
  static const everestM = 8849.0;

  final int hikeCount;

  /// 서버에 기록된 코스 완주 수. 서버에서 받지 못했으면 null.
  final int? completionCount;
  final double distanceM;
  final double elevationGainM;
  final Duration elapsed;

  /// 등산과 등산 사이 평균 며칠. 기록이 2개 이상이어야 계산된다.
  final double? averageIntervalDays;

  /// 마지막 등산 후 지난 날 수
  final int? daysSinceLast;

  /// 최근 6개월 (오래된 달부터). 기간 선택과 관계없이 늘 최근 6개월이다.
  final List<MonthCount> monthly;

  /// 이번 주(또는 지난주)부터 거꾸로 세어 등산한 주가 몇 주 이어졌는지
  final int weekStreak;

  /// 많이 완주한 코스 최대 3개
  final List<CourseRecord> topCourses;

  double get everestRatio => elevationGainM / everestM;

  static HikingStats of({
    required List<ActivitySummary> activities,
    required List<MyCompletion>? completions,
    required StatsPeriod period,
    required DateTime now,
  }) {
    final inPeriod = [
      for (final a in activities)
        if (period.includes(a.startedAt, now)) a,
    ]..sort((a, b) => a.startedAt.compareTo(b.startedAt));
    final done = completions == null
        ? null
        : [
            for (final c in completions)
              if (period.includes(c.completedAt, now)) c,
          ];

    double? interval;
    if (inPeriod.length >= 2) {
      final span = inPeriod.last.startedAt.difference(inPeriod.first.startedAt);
      interval = span.inMinutes / 60 / 24 / (inPeriod.length - 1);
    }

    return HikingStats(
      hikeCount: inPeriod.length,
      completionCount: done?.length,
      distanceM: inPeriod.fold(0, (s, a) => s + a.distanceM),
      elevationGainM: inPeriod.fold(0, (s, a) => s + a.elevationGainM),
      elapsed: inPeriod.fold(Duration.zero, (s, a) => s + a.elapsed),
      averageIntervalDays: interval,
      daysSinceLast: activities.isEmpty
          ? null
          : _dayOf(now)
                .difference(
                  _dayOf(
                    activities
                        .map((a) => a.startedAt)
                        .reduce((a, b) => a.isAfter(b) ? a : b),
                  ),
                )
                .inDays,
      monthly: _monthly(activities, now),
      weekStreak: _weekStreak(activities, now),
      topCourses: done == null
          ? const []
          : courseRecords(done).take(3).toList(),
    );
  }

  /// 코스별 완주 횟수와 최고 기록. 횟수가 많은 순서.
  static List<CourseRecord> courseRecords(List<MyCompletion> completions) {
    final byCourse = <String, List<MyCompletion>>{};
    for (final c in completions) {
      (byCourse[c.courseId] ??= []).add(c);
    }
    final out = [
      for (final MapEntry(key: id, value: list) in byCourse.entries)
        (
          courseId: id,
          count: list.length,
          best: list.map((c) => c.ascent).reduce((a, b) => a < b ? a : b),
        ),
    ]..sort((a, b) => b.count.compareTo(a.count));
    return out;
  }

  static DateTime _dayOf(DateTime t) {
    final local = t.toLocal();
    return DateTime(local.year, local.month, local.day);
  }

  static List<MonthCount> _monthly(
    List<ActivitySummary> activities,
    DateTime now,
  ) {
    final local = now.toLocal();
    return [
      for (var back = 5; back >= 0; back--)
        () {
          final m = DateTime(local.year, local.month - back);
          return (
            year: m.year,
            month: m.month,
            count: activities.where((a) {
              final t = a.startedAt.toLocal();
              return t.year == m.year && t.month == m.month;
            }).length,
          );
        }(),
    ];
  }

  /// 월요일 시작 주 단위. 이번 주에 아직 등산하지 않았으면 지난주부터 센다.
  static int _weekStreak(List<ActivitySummary> activities, DateTime now) {
    DateTime weekOf(DateTime t) {
      final day = _dayOf(t);
      return day.subtract(Duration(days: day.weekday - 1));
    }

    final weeks = {for (final a in activities) weekOf(a.startedAt)};
    var week = weekOf(now);
    if (!weeks.contains(week)) {
      week = DateTime(week.year, week.month, week.day - 7);
    }
    var streak = 0;
    while (weeks.contains(week)) {
      streak++;
      week = DateTime(week.year, week.month, week.day - 7);
    }
    return streak;
  }
}

/// 오르막과 내리막 중 어디에 강한지
enum ClimbStyle { uphill, downhill, balanced }

/// 구독자용 종합 분석 (상세 분석을 여러 산행에 걸쳐 모은 것)
class PremiumStats {
  const PremiumStats({
    required this.efficiencyTrend,
    required this.fatigueTrend,
    required this.courseBests,
    this.climbStyle,
    this.uphillEfficiency,
    this.downhillEfficiency,
    this.walkMinutesPerRest,
    this.restRatio,
    this.steepDownhillRatio,
  });

  /// 이보다 차이가 크면 한쪽에 강하다고 본다 (10%)
  static const styleMargin = 0.1;

  /// 급경사 내리막에서 평소 내리막보다 이만큼 빠르면 주의 안내 (10%)
  static const steepDownhillWarn = 1.1;

  /// 그래프에 보여 줄 최근 산행 수
  static const trendLength = 10;

  /// 산행마다 표준 대비 내 속도 (오래된 것부터, 최근 10개)
  final List<({DateTime date, double value})> efficiencyTrend;

  /// 산행마다 후반 / 전반 오르막 속도 (오래된 것부터, 최근 10개)
  final List<({DateTime date, double value})> fatigueTrend;

  final ClimbStyle? climbStyle;
  final double? uphillEfficiency;
  final double? downhillEfficiency;

  /// 평균 몇 분 걷고 한 번 쉬는지. 휴식이 없으면 null.
  final double? walkMinutesPerRest;

  /// 전체 시간 중 휴식 비율
  final double? restRatio;

  /// 급경사 내리막 속도 / 평소 내리막 속도 (둘 다 경사 보정). 1보다 크면 급경사에서 빨라진다는 뜻.
  final double? steepDownhillRatio;

  /// 코스별 완주 횟수와 최고 기록 (서버에서 받지 못했으면 빈 목록)
  final List<CourseRecord> courseBests;

  static PremiumStats of({
    required List<(ActivitySummary, ActivityAnalysis)> hikes,
    required List<MyCompletion>? completions,
    required StatsPeriod period,
    required DateTime now,
  }) {
    final inPeriod = [
      for (final h in hikes)
        if (period.includes(h.$1.startedAt, now)) h,
    ]..sort((a, b) => a.$1.startedAt.compareTo(b.$1.startedAt));
    List<T> recent<T>(List<T> list) => list.length <= trendLength
        ? list
        : list.sublist(list.length - trendLength);

    // 산행 여러 개를 합쳐 경사 보정 속도를 구한다 (표준 시간 합 / 실제 시간 합).
    double? efficiencyOf(Iterable<GradeSummary> gs) {
      final walked = gs.fold(Duration.zero, (s, g) => s + g.duration);
      if (walked == Duration.zero) return null;
      final standard = gs.fold(Duration.zero, (s, g) => s + g.standardDuration);
      return standard.inMilliseconds / walked.inMilliseconds;
    }

    final up = efficiencyOf(inPeriod.map((h) => h.$2.grade(GradeKind.uphill)));
    final down = efficiencyOf(
      inPeriod.map((h) => h.$2.grade(GradeKind.downhill)),
    );
    ClimbStyle? style;
    if (up != null && down != null) {
      style = up > down * (1 + styleMargin)
          ? ClimbStyle.uphill
          : down > up * (1 + styleMargin)
          ? ClimbStyle.downhill
          : ClimbStyle.balanced;
    }

    final restCount = inPeriod.fold(0, (s, h) => s + h.$2.rests.length);
    final restTotal = inPeriod.fold(
      Duration.zero,
      (s, h) => s + h.$2.restDuration,
    );
    final total = inPeriod.fold(
      Duration.zero,
      (s, h) => s + h.$2.totalDuration,
    );

    final steep = efficiencyOf([
      for (final h in inPeriod) ?h.$2.dangerDownhill,
    ]);

    final done = completions == null
        ? null
        : [
            for (final c in completions)
              if (period.includes(c.completedAt, now)) c,
          ];

    return PremiumStats(
      efficiencyTrend: recent([
        for (final (a, analysis) in inPeriod)
          if (analysis.efficiency case final e?) (date: a.startedAt, value: e),
      ]),
      fatigueTrend: recent([
        for (final (a, analysis) in inPeriod)
          if (analysis.fatigue case final f?)
            (date: a.startedAt, value: f.ratio),
      ]),
      climbStyle: style,
      uphillEfficiency: up,
      downhillEfficiency: down,
      walkMinutesPerRest: restCount == 0
          ? null
          : (total - restTotal).inSeconds / 60 / restCount,
      restRatio: total == Duration.zero
          ? null
          : restTotal.inSeconds / total.inSeconds,
      steepDownhillRatio: (steep != null && down != null && down > 0)
          ? steep / down
          : null,
      courseBests: done == null ? const [] : HikingStats.courseRecords(done),
    );
  }
}
