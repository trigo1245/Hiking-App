import 'package:flutter_test/flutter_test.dart';
import 'package:hiking_app/features/activities/domain/activity_analysis.dart';
import 'package:hiking_app/features/activities/domain/activity_summary.dart';
import 'package:hiking_app/features/activities/domain/hiking_stats.dart';
import 'package:hiking_app/features/courses/domain/competition.dart';

ActivitySummary hikeOn(DateTime start, {double km = 5, double gain = 400}) =>
    ActivitySummary(
      id: start.toIso8601String(),
      title: '산행',
      startedAt: start,
      endedAt: start.add(const Duration(hours: 3)),
      elapsed: const Duration(hours: 3),
      moving: const Duration(hours: 2, minutes: 30),
      distanceM: km * 1000,
      elevationGainM: gain,
      maxAltitudeM: 500,
      pointCount: 100,
      isFlagged: false,
    );

MyCompletion done(String course, DateTime at, int minutes) => MyCompletion(
  courseId: course,
  ascent: Duration(minutes: minutes),
  completedAt: at,
);

/// 오르막·내리막 효율과 휴식만 정한 가짜 분석
ActivityAnalysis analysis({
  required double up,
  required double down,
  int rests = 0,
  Duration rest = Duration.zero,
  double? fatigue,
  double? steepDown,
}) {
  GradeSummary g(GradeKind kind, double efficiency) => GradeSummary(
    kind: kind,
    distanceM: 1000,
    duration: const Duration(minutes: 20),
    verticalM: 100,
    standardDuration: Duration(seconds: (1200 * efficiency).round()),
  );
  return ActivityAnalysis(
    elevationProfile: const [],
    totalDuration: const Duration(hours: 2),
    rests: [
      for (var i = 0; i < rests; i++)
        TimeRange(Duration(minutes: i * 30), Duration(minutes: i * 30) + rest),
    ],
    dangers: const [],
    grades: [
      g(GradeKind.uphill, up),
      g(GradeKind.flat, 1),
      g(GradeKind.downhill, down),
    ],
    splits: const [],
    fatigue: fatigue == null
        ? null
        : FatigueComparison(
            firstHalfClimbRate: 100,
            secondHalfClimbRate: 100 * fatigue,
          ),
    dangerDownhill: steepDown == null ? null : g(GradeKind.downhill, steepDown),
  );
}

void main() {
  // 2026년 10월 20일 (화) 정오, 한국 시간
  final now = DateTime.utc(2026, 10, 20, 3);

  final activities = [
    hikeOn(DateTime.utc(2026, 3, 1)), // 상반기
    hikeOn(DateTime.utc(2026, 10, 1)), // 목요일
    hikeOn(DateTime.utc(2026, 10, 6)), // 화요일
    hikeOn(DateTime.utc(2026, 10, 13)), // 화요일
    hikeOn(DateTime.utc(2026, 10, 19)), // 월요일 (이번 주)
  ];

  group('기간', () {
    test('이번 시즌은 하반기(7월 1일, 한국 시간)부터', () {
      expect(StatsPeriod.season.startAt(now), DateTime.utc(2026, 6, 30, 15));
      expect(StatsPeriod.year.startAt(now), DateTime.utc(2025, 12, 31, 15));
      expect(StatsPeriod.all.startAt(now), isNull);
    });
  });

  group('모두가 보는 통계', () {
    test('기간 안의 등산 횟수와 누적 거리·오른 높이', () {
      final season = HikingStats.of(
        activities: activities,
        completions: null,
        period: StatsPeriod.season,
        now: now,
      );
      expect(season.hikeCount, 4);
      expect(season.distanceM, 20000);
      expect(season.elevationGainM, 1600);
      expect(season.everestRatio, closeTo(1600 / 8849, 1e-9));

      final all = HikingStats.of(
        activities: activities,
        completions: null,
        period: StatsPeriod.all,
        now: now,
      );
      expect(all.hikeCount, 5);
    });

    test('등반 주기: 평균 간격과 마지막 산행 후 지난 날', () {
      final s = HikingStats.of(
        activities: activities,
        completions: null,
        period: StatsPeriod.season,
        now: now,
      );
      // 10/1 → 10/19 = 18일, 간격 3번
      expect(s.averageIntervalDays, closeTo(18 / 3, 0.01));
      expect(s.daysSinceLast, 1);
    });

    test('산행이 하나뿐이면 주기를 계산하지 않는다', () {
      final s = HikingStats.of(
        activities: [activities.last],
        completions: null,
        period: StatsPeriod.all,
        now: now,
      );
      expect(s.averageIntervalDays, isNull);
    });

    test('연속 주: 이번 주부터 거꾸로 센다', () {
      final s = HikingStats.of(
        activities: activities,
        completions: null,
        period: StatsPeriod.all,
        now: now,
      );
      // 10/19 주, 10/12 주, 10/5 주, 9/28 주 → 4주 연속
      expect(s.weekStreak, 4);
    });

    test('이번 주에 아직 안 갔으면 지난주부터 센다', () {
      final s = HikingStats.of(
        activities: activities.take(4).toList(),
        completions: null,
        period: StatsPeriod.all,
        now: now,
      );
      expect(s.weekStreak, 3);
    });

    test('월별 횟수는 늘 최근 6개월', () {
      final s = HikingStats.of(
        activities: activities,
        completions: null,
        period: StatsPeriod.season,
        now: now,
      );
      expect(s.monthly.map((m) => m.month), [5, 6, 7, 8, 9, 10]);
      expect(s.monthly.map((m) => m.count), [0, 0, 0, 0, 0, 4]);
    });

    test('완등 횟수와 자주 간 코스는 서버 완주 기록으로 센다', () {
      final s = HikingStats.of(
        activities: activities,
        completions: [
          done('a', DateTime.utc(2026, 10, 4), 50),
          done('a', DateTime.utc(2026, 10, 13), 47),
          done('b', DateTime.utc(2026, 10, 19), 20),
          done('c', DateTime.utc(2026, 3, 1), 30), // 지난 시즌
        ],
        period: StatsPeriod.season,
        now: now,
      );
      expect(s.completionCount, 3);
      expect(s.topCourses.map((c) => c.courseId), ['a', 'b']);
      expect(s.topCourses.first.count, 2);
      expect(s.topCourses.first.best, const Duration(minutes: 47));
    });

    test('서버에서 받지 못하면 완등 횟수는 null', () {
      final s = HikingStats.of(
        activities: activities,
        completions: null,
        period: StatsPeriod.all,
        now: now,
      );
      expect(s.completionCount, isNull);
      expect(s.topCourses, isEmpty);
    });
  });

  group('구독자 종합 분석', () {
    test('오르막이 내리막보다 10% 넘게 빠르면 오르막형', () {
      final p = PremiumStats.of(
        hikes: [(activities[3], analysis(up: 1.2, down: 0.9))],
        completions: null,
        period: StatsPeriod.all,
        now: now,
      );
      expect(p.climbStyle, ClimbStyle.uphill);
      expect(p.uphillEfficiency, closeTo(1.2, 0.01));
    });

    test('차이가 10% 이내면 균형형', () {
      final p = PremiumStats.of(
        hikes: [(activities[3], analysis(up: 1.0, down: 1.05))],
        completions: null,
        period: StatsPeriod.all,
        now: now,
      );
      expect(p.climbStyle, ClimbStyle.balanced);
    });

    test('휴식 패턴: 몇 분 걷고 한 번 쉬는지, 휴식 비율', () {
      final p = PremiumStats.of(
        hikes: [
          (
            activities[3],
            analysis(
              up: 1,
              down: 1,
              rests: 2,
              rest: const Duration(minutes: 10),
            ),
          ),
        ],
        completions: null,
        period: StatsPeriod.all,
        now: now,
      );
      // 2시간 중 휴식 20분 → 걸은 100분 / 휴식 2번
      expect(p.walkMinutesPerRest, closeTo(50, 0.01));
      expect(p.restRatio, closeTo(20 / 120, 0.001));
    });

    test('급경사 내리막에서 평소 내리막보다 빠르면 비율이 1보다 크다', () {
      final p = PremiumStats.of(
        hikes: [(activities[3], analysis(up: 1, down: 1, steepDown: 1.3))],
        completions: null,
        period: StatsPeriod.all,
        now: now,
      );
      expect(p.steepDownhillRatio, closeTo(1.3, 0.01));
      expect(p.steepDownhillRatio! > PremiumStats.steepDownhillWarn, isTrue);
    });

    test('추이는 기간 안의 산행을 날짜 순서로, 최근 10개까지', () {
      final many = [
        for (var d = 1; d <= 12; d++)
          (
            hikeOn(DateTime.utc(2026, 9, d)),
            analysis(up: 1, down: 1, fatigue: 0.9),
          ),
      ];
      final p = PremiumStats.of(
        hikes: many.reversed.toList(),
        completions: null,
        period: StatsPeriod.all,
        now: now,
      );
      expect(p.efficiencyTrend, hasLength(10));
      expect(p.efficiencyTrend.first.date, DateTime.utc(2026, 9, 3));
      expect(p.fatigueTrend.last.value, closeTo(0.9, 1e-9));
    });

    test('코스별 최고 기록', () {
      final p = PremiumStats.of(
        hikes: const [],
        completions: [
          done('a', DateTime.utc(2026, 10, 4), 50),
          done('a', DateTime.utc(2026, 10, 13), 47),
        ],
        period: StatsPeriod.all,
        now: now,
      );
      expect(p.courseBests.single.best, const Duration(minutes: 47));
      expect(p.climbStyle, isNull);
    });
  });
}
