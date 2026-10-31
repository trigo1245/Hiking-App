import 'package:flutter_test/flutter_test.dart';
import 'package:hiking_app/features/achievements/domain/achievements.dart';
import 'package:hiking_app/features/activities/domain/activity_summary.dart';
import 'package:hiking_app/features/courses/domain/competition.dart';

ActivitySummary hike(
  DateTime start, {
  double km = 5,
  double up = 300,
  bool flagged = false,
}) => ActivitySummary(
  id: start.toIso8601String(),
  title: '등산',
  startedAt: start,
  endedAt: start.add(const Duration(hours: 3)),
  elapsed: const Duration(hours: 3),
  moving: const Duration(hours: 2),
  distanceM: km * 1000,
  elevationGainM: up,
  maxAltitudeM: 500,
  pointCount: 100,
  isFlagged: flagged,
);

MyCompletion done(String course, DateTime at) => MyCompletion(
  courseId: course,
  ascent: const Duration(minutes: 50),
  completedAt: at,
);

void main() {
  final now = DateTime(2026, 10, 27, 12);

  Achievements calc({
    List<ActivitySummary> activities = const [],
    List<MyCompletion>? completions = const [],
    List<LeadRun>? runs = const [],
    List<DateTime>? reviews = const [],
  }) => Achievements.of(
    activities: activities,
    completions: completions,
    leadRuns: runs,
    reviewDates: reviews,
    now: now,
  );

  group('산행 기록 배지 (기기에서 계산)', () {
    test('기준을 처음 넘은 기록의 날짜에 단계를 얻고, 속도 이상 기록은 넣지 않는다', () {
      final a = calc(
        activities: [
          for (var i = 0; i < 6; i++)
            hike(DateTime(2026, 9, 1 + i * 3, 9), km: 2, up: 100),
          hike(DateTime(2026, 10, 1, 9), km: 100, up: 5000, flagged: true),
        ],
      );
      expect(a.statusOf(Badges.firstStep).achievedAt, [
        DateTime(2026, 9, 1, 12),
      ]);
      final hikes = a.statusOf(Badges.hikes);
      expect(hikes.level, 1);
      expect(hikes.tier, BadgeTier.bronze);
      expect(hikes.achievedAt.single, DateTime(2026, 9, 13, 12));
      expect(hikes.value, 6);
      expect(hikes.nextGoal, 20);

      final distance = a.statusOf(Badges.distance);
      expect(distance.value, 12);
      expect(distance.achievedAt.single, DateTime(2026, 9, 13, 12));
      // 600m: 롯데월드타워(555m)만 넘었다.
      expect(a.statusOf(Badges.elevation).level, 1);
    });

    test('한 번에 여러 단계를 넘으면 같은 날짜로 모두 얻는다', () {
      final a = calc(activities: [hike(DateTime(2026, 9, 1), km: 60)]);
      expect(a.statusOf(Badges.distance).achievedAt, [
        DateTime(2026, 9, 1, 3),
        DateTime(2026, 9, 1, 3),
      ]);
      expect(a.statusOf(Badges.distance).tier, BadgeTier.silver);
    });

    test('연속 주 산행은 가장 길었던 기간으로 센다 (지금 끊겨 있어도 남는다)', () {
      final a = calc(
        activities: [
          // 9월 첫 주부터 5주 연속 (같은 주 두 번은 한 주)
          for (final d in [1, 3, 9, 16, 23, 30]) hike(DateTime(2026, 9, d, 9)),
          // 한 주 쉬고 다시 1주
          hike(DateTime(2026, 10, 14, 9)),
        ],
      );
      final streak = a.statusOf(Badges.streak);
      expect(streak.value, 5);
      expect(streak.level, 1);
      expect(streak.achievedAt.single, DateTime(2026, 9, 23, 12));
    });

    test('오전 6시 전에 출발하면 새벽 산행', () {
      final a = calc(
        activities: [
          hike(DateTime(2026, 9, 1, 6, 30)),
          hike(DateTime(2026, 9, 8, 5, 40)),
        ],
      );
      expect(
        a.statusOf(Badges.dawn).achievedAt.single,
        DateTime(2026, 9, 8, 8, 40),
      );
      expect(a.statusOf(Badges.dawn).tier, BadgeTier.gold);
    });
  });

  group('완등·리뷰 배지 (서버 자료)', () {
    test('완등 횟수, 서로 다른 코스 수, 한 코스 최다 완등', () {
      final a = calc(
        completions: [
          for (var i = 0; i < 6; i++) done('c1', DateTime(2026, 8, 1 + i)),
          done('c2', DateTime(2026, 8, 10)),
          done('c3', DateTime(2026, 8, 3)),
        ],
      );
      expect(
        a.statusOf(Badges.summits).achievedAt.single,
        DateTime(2026, 8, 1),
      );
      expect(a.statusOf(Badges.summits).value, 8);
      expect(
        a.statusOf(Badges.explorer).achievedAt.single,
        DateTime(2026, 8, 10),
      );
      final regular = a.statusOf(Badges.regular);
      expect(regular.value, 6);
      expect(regular.achievedAt.single, DateTime(2026, 8, 5));
    });

    test('리뷰는 2단계라 동·금', () {
      final a = calc(
        reviews: [for (var i = 1; i <= 5; i++) DateTime(2026, 9, i)],
      );
      final r = a.statusOf(Badges.reviews);
      expect(r.achievedAt, [DateTime(2026, 9, 1), DateTime(2026, 9, 5)]);
      expect(Badges.reviews.tierOf(1), BadgeTier.bronze);
      expect(r.tier, BadgeTier.gold);
    });

    test('서버 자료를 받지 못하면 그 배지는 "확인할 수 없음"', () {
      final a = calc(completions: null, runs: null, reviews: null);
      expect(a.statusOf(Badges.summits).available, isFalse);
      expect(a.statusOf(Badges.hold).available, isFalse);
      expect(a.statusOf(Badges.reviews).available, isFalse);
      expect(a.statusOf(Badges.firstStep).available, isTrue);
      expect(a.partial, isTrue);
    });
  });

  group('정복 배지 (서버가 알려 준 1위 기간)', () {
    LeadRun run(
      RankingKind kind,
      DateTime start, {
      DateTime? end,
      String scope = '2026-H2',
      String course = 'c1',
      bool seasonFinal = false,
    }) => LeadRun(
      courseId: course,
      scope: scope,
      kind: kind,
      startedAt: start,
      endedAt: end,
      seasonFinal: seasonFinal,
    );

    test('분야별로 처음 1위가 된 순간 (명예의 전당 포함)', () {
      final a = calc(
        runs: [
          run(RankingKind.most, DateTime(2026, 8, 1)),
          run(RankingKind.most, DateTime(2026, 3, 1), scope: LeadRun.allTime),
          run(
            RankingKind.fastest,
            DateTime(2026, 9, 1),
            end: DateTime(2026, 9, 2),
          ),
        ],
      );
      expect(
        a.statusOf(Badges.firstMost).achievedAt.single,
        DateTime(2026, 3, 1),
      );
      expect(
        a.statusOf(Badges.firstFastest).achievedAt.single,
        DateTime(2026, 9, 1),
      );
    });

    test('1위 지키기는 시즌 1위를 끊기지 않고 지킨 가장 긴 구간만 센다 (합산·명예의 전당 제외)', () {
      final a = calc(
        runs: [
          // 25일 + 25일: 합치면 50일이지만 따로 센다.
          run(
            RankingKind.most,
            DateTime(2026, 7, 1),
            end: DateTime(2026, 7, 26),
          ),
          run(
            RankingKind.most,
            DateTime(2026, 8, 1),
            end: DateTime(2026, 8, 26),
          ),
          // 명예의 전당 1위 200일은 넣지 않는다.
          run(RankingKind.most, DateTime(2026, 3, 1), scope: LeadRun.allTime),
          // 지금도 1위: 9월 1일 정오부터 오늘(10월 27일 정오)까지 56일
          run(RankingKind.fastest, DateTime(2026, 9, 1, 12)),
        ],
      );
      final hold = a.statusOf(Badges.hold);
      expect(hold.value, 56);
      expect(hold.achievedAt, [DateTime(2026, 10, 1, 12)]);
      expect(hold.tier, BadgeTier.bronze);
    });

    test('같은 코스·같은 기간에 두 분야 1위가 겹치면 두 개의 왕관', () {
      final a = calc(
        runs: [
          run(
            RankingKind.most,
            DateTime(2026, 8, 1),
            end: DateTime(2026, 9, 1),
          ),
          run(RankingKind.fastest, DateTime(2026, 8, 20)),
          // 다른 코스의 최단시간 1위는 짝이 아니다.
          run(RankingKind.fastest, DateTime(2026, 7, 2), course: 'c2'),
        ],
      );
      expect(
        a.statusOf(Badges.doubleCrown).achievedAt.single,
        DateTime(2026, 8, 20),
      );

      final apart = calc(
        runs: [
          run(
            RankingKind.most,
            DateTime(2026, 8, 1),
            end: DateTime(2026, 8, 10),
          ),
          run(RankingKind.fastest, DateTime(2026, 8, 10)),
        ],
      );
      expect(apart.statusOf(Badges.doubleCrown).earned, isFalse);
    });

    test('끝난 시즌 마지막까지 1위면 분야마다 시즌 정복 배지를 따로 받는다', () {
      final a = calc(
        runs: [
          run(
            RankingKind.most,
            DateTime(2026, 4, 1),
            end: Season(2026, 1).end,
            scope: '2026-H1',
            seasonFinal: true,
          ),
          run(
            RankingKind.fastest,
            DateTime(2026, 4, 1),
            end: Season(2026, 1).end,
            scope: '2026-H1',
            seasonFinal: true,
          ),
        ],
      );
      expect(a.seasons, hasLength(2));
      expect(a.seasons.first.achievedAt, DateTime.utc(2026, 6, 30, 15));
      expect(a.seasons.map((s) => s.kind), containsAll(RankingKind.values));
      expect(a.earned.where((e) => e.season != null), hasLength(2));
    });
  });

  test('시즌 정복 기록은 시즌·분야별로 묶고, 1위로 끝낸 코스를 모두 담는다', () {
    LeadRun last(String course, String scope, RankingKind kind) => LeadRun(
      courseId: course,
      scope: scope,
      kind: kind,
      startedAt: DateTime(2025, 8, 1),
      endedAt: Season.parse(scope).end,
      seasonFinal: true,
    );
    final a = calc(
      runs: [
        last('c1', '2025-H2', RankingKind.most),
        last('c1', '2026-H1', RankingKind.fastest),
        last('c2', '2026-H1', RankingKind.most),
        last('c1', '2026-H1', RankingKind.most),
      ],
    );
    final groups = a.seasonGroups;
    expect(
      [for (final g in groups) '${g.season.id} ${g.kind.name} ${g.courseIds}'],
      ['2026-H1 most [c1, c2]', '2026-H1 fastest [c1]', '2025-H2 most [c1]'],
    );
    // 배지 개수는 코스마다 센다.
    expect(a.seasons, hasLength(4));
  });

  test('전체 배지 수: 14종, 단계까지 31개', () {
    expect(Badges.all, hasLength(14));
    expect(Badges.totalLevels, 31);
    expect({for (final b in Badges.all) b.shape}, hasLength(14));
  });

  group('새로 얻은 배지', () {
    test('이 기록이 없을 때와 비교해 새로 생긴 단계만 고른다', () {
      final old = [for (var i = 0; i < 4; i++) hike(DateTime(2026, 9, 1 + i))];
      final before = calc(activities: old);
      final after = calc(activities: [...old, hike(DateTime(2026, 10, 1))]);
      final gained = Achievements.gained(before, after);
      // 5번째 산행: 산행 5번 달성. 거리(25km)는 이미 얻은 10km 단계 그대로다.
      expect(gained.map((e) => e.key), ['hikes:1']);
      expect(gained.map((e) => e.key), isNot(contains('first_step:1')));
    });

    test('저장 전에 서버 자료를 받지 못했으면 서버 배지를 새 배지로 보지 않는다', () {
      final before = calc(completions: null, runs: null, reviews: null);
      final after = calc(
        completions: [done('c1', DateTime(2026, 10, 1))],
        reviews: [DateTime(2026, 9, 1)],
      );
      expect(Achievements.gained(before, after), isEmpty);
    });
  });
}
