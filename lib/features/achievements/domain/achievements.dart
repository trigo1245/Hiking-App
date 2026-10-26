import '../../activities/domain/activity_summary.dart';
import '../../courses/domain/competition.dart';

/// 업적 화면의 묶음
enum BadgeGroup {
  record('산행 기록'),
  summit('완등'),
  conquest('정복'),
  community('리뷰');

  const BadgeGroup(this.label);
  final String label;
}

/// 배지 테두리 모양. 배지 종류마다 다르게 둔다. (그리기는 presentation/badge_medal.dart)
enum BadgeShape {
  circle,
  hexagon,
  roundedSquare,
  pentagon,
  octagon,
  sun,
  shield,
  diamond,
  seal,
  heptagon,
  star,
  burst,
  crown,
  pennant,
}

/// 단계 색. 3단계면 동·은·금, 2단계면 동·금, 1단계면 금.
enum BadgeTier {
  bronze('동'),
  silver('은'),
  gold('금');

  const BadgeTier(this.label);
  final String label;
}

/// 진행 값의 단위 (화면에서 "12/20km"처럼 보여 줄 때 쓴다)
enum BadgeUnit {
  count('번'),
  km('km'),
  meters('m'),
  weeks('주'),
  days('일'),
  courses('개'),
  reviews('개');

  const BadgeUnit(this.label);
  final String label;
}

/// 배지 한 종류. [goals]는 단계별 조건 문구, [thresholds]는 단계별 기준 값.
class BadgeDef {
  const BadgeDef({
    required this.id,
    required this.name,
    required this.group,
    required this.shape,
    required this.unit,
    required this.thresholds,
    required this.goals,
    this.fromServer = false,
  });

  final String id;
  final String name;
  final BadgeGroup group;
  final BadgeShape shape;
  final BadgeUnit unit;
  final List<double> thresholds;
  final List<String> goals;

  /// 서버 자료(완등·정복·리뷰)가 있어야 계산할 수 있다. 인터넷이 없으면 "확인할 수 없음".
  final bool fromServer;

  int get levels => thresholds.length;

  /// [level]번째 단계(1부터)의 색
  BadgeTier tierOf(int level) => switch (levels) {
    1 => BadgeTier.gold,
    2 => level == 1 ? BadgeTier.bronze : BadgeTier.gold,
    _ => BadgeTier.values[level - 1],
  };
}

/// 업적 목록 (CLAUDE.md 6-2장 "업적·배지")
abstract final class Badges {
  static const firstStep = BadgeDef(
    id: 'first_step',
    name: '첫 걸음',
    group: BadgeGroup.record,
    shape: BadgeShape.circle,
    unit: BadgeUnit.count,
    thresholds: [1],
    goals: ['첫 산행을 기록해요'],
  );
  static const hikes = BadgeDef(
    id: 'hikes',
    name: '산을 좋아하는 사람',
    group: BadgeGroup.record,
    shape: BadgeShape.hexagon,
    unit: BadgeUnit.count,
    thresholds: [5, 20, 50],
    goals: ['산행 5번', '산행 20번', '산행 50번'],
  );
  static const distance = BadgeDef(
    id: 'distance',
    name: '걸어온 길',
    group: BadgeGroup.record,
    shape: BadgeShape.roundedSquare,
    unit: BadgeUnit.km,
    thresholds: [10, 50, 200],
    goals: ['누적 거리 10km', '누적 거리 50km', '누적 거리 200km'],
  );
  static const elevation = BadgeDef(
    id: 'elevation',
    name: '오른 높이',
    group: BadgeGroup.record,
    shape: BadgeShape.pentagon,
    unit: BadgeUnit.meters,
    thresholds: [555, 1947, 8849],
    goals: [
      '롯데월드타워만큼 오르기 (누적 555m)',
      '한라산만큼 오르기 (누적 1,947m)',
      '에베레스트만큼 오르기 (누적 8,849m)',
    ],
  );
  static const streak = BadgeDef(
    id: 'streak',
    name: '꾸준한 발걸음',
    group: BadgeGroup.record,
    shape: BadgeShape.octagon,
    unit: BadgeUnit.weeks,
    thresholds: [4, 8, 12],
    goals: ['4주 연속 산행', '8주 연속 산행', '12주 연속 산행'],
  );
  static const dawn = BadgeDef(
    id: 'dawn',
    name: '새벽 산행',
    group: BadgeGroup.record,
    shape: BadgeShape.sun,
    unit: BadgeUnit.count,
    thresholds: [1],
    goals: ['오전 6시 전에 출발해요'],
  );
  static const summits = BadgeDef(
    id: 'summits',
    name: '정상에 서다',
    group: BadgeGroup.summit,
    shape: BadgeShape.shield,
    unit: BadgeUnit.count,
    thresholds: [1, 10, 30],
    goals: ['첫 완등', '완등 10번', '완등 30번'],
    fromServer: true,
  );
  static const explorer = BadgeDef(
    id: 'explorer',
    name: '여러 산 탐험',
    group: BadgeGroup.summit,
    shape: BadgeShape.diamond,
    unit: BadgeUnit.courses,
    thresholds: [3, 5, 10],
    goals: ['서로 다른 코스 3개 완등', '서로 다른 코스 5개 완등', '서로 다른 코스 10개 완등'],
    fromServer: true,
  );
  static const regular = BadgeDef(
    id: 'regular',
    name: '내 산',
    group: BadgeGroup.summit,
    shape: BadgeShape.seal,
    unit: BadgeUnit.count,
    thresholds: [5, 10, 20],
    goals: ['한 코스를 5번 완등', '한 코스를 10번 완등', '한 코스를 20번 완등'],
    fromServer: true,
  );
  static const firstMost = BadgeDef(
    id: 'first_most',
    name: '첫 정복 · 최다완등',
    group: BadgeGroup.conquest,
    shape: BadgeShape.star,
    unit: BadgeUnit.count,
    thresholds: [1],
    goals: ['어느 코스든 최다완등 1위가 돼요 (시즌·명예의 전당)'],
    fromServer: true,
  );
  static const firstFastest = BadgeDef(
    id: 'first_fastest',
    name: '첫 정복 · 최단시간',
    group: BadgeGroup.conquest,
    shape: BadgeShape.burst,
    unit: BadgeUnit.count,
    thresholds: [1],
    goals: ['어느 코스든 최단시간 1위가 돼요 (시즌·명예의 전당)'],
    fromServer: true,
  );
  static const hold = BadgeDef(
    id: 'hold',
    name: '1위 지키기',
    group: BadgeGroup.conquest,
    shape: BadgeShape.heptagon,
    unit: BadgeUnit.days,
    thresholds: [30, 60, 90],
    goals: [
      '한 코스·한 분야 시즌 1위를 1개월(30일) 연속 지켜요',
      '2개월(60일) 연속 지켜요',
      '3개월(90일) 연속 지켜요',
    ],
    fromServer: true,
  );
  static const doubleCrown = BadgeDef(
    id: 'double_crown',
    name: '두 개의 왕관',
    group: BadgeGroup.conquest,
    shape: BadgeShape.crown,
    unit: BadgeUnit.count,
    thresholds: [1],
    goals: ['한 코스에서 최다완등·최단시간 1위를 동시에 해요'],
    fromServer: true,
  );
  static const reviews = BadgeDef(
    id: 'reviews',
    name: '길잡이',
    group: BadgeGroup.community,
    shape: BadgeShape.pennant,
    unit: BadgeUnit.reviews,
    thresholds: [1, 5],
    goals: ['첫 리뷰 쓰기', '리뷰 5개 쓰기'],
    fromServer: true,
  );

  static const all = [
    firstStep,
    hikes,
    distance,
    elevation,
    streak,
    dawn,
    summits,
    explorer,
    regular,
    firstMost,
    firstFastest,
    hold,
    doubleCrown,
    reviews,
  ];

  /// 단계까지 센 전체 배지 수 (시즌 정복 기록은 개수가 정해져 있지 않아 빼고 센다)
  static int get totalLevels => all.fold(0, (s, d) => s + d.levels);

  /// 새벽 산행 기준 시각 (이 시각 전에 출발)
  static const dawnHour = 6;
}

/// 서버가 알려 준 "내가 코스 1위였던 기간" (get_my_lead_runs)
class LeadRun {
  const LeadRun({
    required this.courseId,
    required this.scope,
    required this.kind,
    required this.startedAt,
    this.endedAt,
    this.seasonFinal = false,
  });

  final String courseId;

  /// 시즌 id(예: 2026-H2) 또는 'all'(명예의 전당)
  final String scope;
  final RankingKind kind;
  final DateTime startedAt;

  /// 1위를 내준 시각 또는 시즌이 끝난 시각. 지금도 1위면 null.
  final DateTime? endedAt;

  /// 끝난 시즌의 마지막 순간까지 1위였다.
  final bool seasonFinal;

  static const allTime = 'all';

  bool get isSeason => scope != allTime;

  DateTime endOr(DateTime now) => endedAt ?? now;
}

/// 배지 한 종류의 상태
class BadgeStatus {
  const BadgeStatus({
    required this.def,
    required this.value,
    required this.achievedAt,
    this.available = true,
  });

  final BadgeDef def;

  /// 지금까지의 값 (가장 좋았던 값). 진행 막대에 쓴다.
  final double value;

  /// 얻은 단계마다 얻은 날짜. 길이 = 얻은 단계 수.
  final List<DateTime> achievedAt;

  /// 서버 자료를 받지 못해 확인할 수 없으면 false
  final bool available;

  int get level => achievedAt.length;
  bool get earned => level > 0;
  BadgeTier? get tier => earned ? def.tierOf(level) : null;
  bool get maxed => level >= def.levels;

  /// 다음 단계 기준 값. 모두 얻었으면 null.
  double? get nextGoal => maxed ? null : def.thresholds[level];

  /// 다음 단계까지 진행률 0~1
  double get progress {
    final goal = nextGoal;
    if (goal == null) return 1;
    return (value / goal).clamp(0, 1).toDouble();
  }
}

/// 시즌 정복 배지: 시즌이 끝났을 때 그 코스·분야 1위
class SeasonBadge {
  const SeasonBadge({
    required this.courseId,
    required this.season,
    required this.kind,
  });

  final String courseId;
  final Season season;
  final RankingKind kind;

  DateTime get achievedAt => season.end;
  String get key => 'season:$courseId:${season.id}:${kind.name}';
}

/// 얻은 배지 한 단계 (새 배지 카드·최근 배지에 쓴다)
class EarnedBadge {
  const EarnedBadge({
    required this.key,
    required this.achievedAt,
    this.def,
    this.level = 1,
    this.season,
  });

  final String key;
  final DateTime achievedAt;

  /// 일반 배지. 시즌 정복이면 null.
  final BadgeDef? def;
  final int level;
  final SeasonBadge? season;
}

/// 업적 전체. 저장하지 않고 기록에서 매번 다시 계산한다(기록을 지우면 배지도 빠진다).
class Achievements {
  const Achievements({required this.badges, required this.seasons});

  final List<BadgeStatus> badges;
  final List<SeasonBadge> seasons;

  /// 최근에 얻은 배지로 보는 기간 (업적 화면의 NEW 표시)
  static const newFor = Duration(days: 7);

  int get earnedLevels => badges.fold(0, (s, b) => s + b.level);

  /// 서버 자료 중 하나라도 받지 못했다.
  bool get partial => badges.any((b) => !b.available);

  BadgeStatus statusOf(BadgeDef def) => badges.firstWhere((b) => b.def == def);

  /// 얻은 배지 모든 단계와 시즌 정복. 최근에 얻은 순서.
  List<EarnedBadge> get earned => [
    for (final b in badges)
      for (var i = 0; i < b.level; i++)
        EarnedBadge(
          key: '${b.def.id}:${i + 1}',
          achievedAt: b.achievedAt[i],
          def: b.def,
          level: i + 1,
        ),
    for (final s in seasons)
      EarnedBadge(key: s.key, achievedAt: s.achievedAt, season: s),
  ]..sort((a, b) => b.achievedAt.compareTo(a.achievedAt));

  /// [before]에는 없고 [after]에 새로 생긴 배지.
  /// 한쪽이라도 서버 자료를 받지 못한 배지는 비교하지 않는다(받지 못해 생긴 차이를 새 배지로 보지 않도록).
  static List<EarnedBadge> gained(Achievements before, Achievements after) {
    final had = {for (final e in before.earned) e.key};
    final comparable = {
      for (final b in after.badges)
        if (b.available && before.statusOf(b.def).available) b.def.id,
    };
    final seasonsComparable =
        before.statusOf(Badges.firstMost).available &&
        after.statusOf(Badges.firstMost).available;
    return [
      for (final e in after.earned)
        if (!had.contains(e.key) &&
            (e.def == null
                ? seasonsComparable
                : comparable.contains(e.def!.id)))
          e,
    ];
  }

  /// [completions]·[leadRuns]·[reviewDates]가 null이면 인터넷이 없어 받지 못한 것이다.
  static Achievements of({
    required List<ActivitySummary> activities,
    required List<MyCompletion>? completions,
    required List<LeadRun>? leadRuns,
    required List<DateTime>? reviewDates,
    required DateTime now,
  }) {
    // 속도 이상 기록은 랭킹처럼 배지에도 넣지 않는다.
    final hikes = [
      for (final a in activities)
        if (!a.isFlagged) a,
    ]..sort((a, b) => a.startedAt.compareTo(b.startedAt));

    final done = completions == null
        ? null
        : ([...completions]
            ..sort((a, b) => a.completedAt.compareTo(b.completedAt)));
    final runs = leadRuns ?? const <LeadRun>[];

    return Achievements(
      badges: [
        _cumulative(Badges.firstStep, [
          for (final a in hikes) (a.endedAt, 1.0),
        ]),
        _cumulative(Badges.hikes, [for (final a in hikes) (a.endedAt, 1.0)]),
        _cumulative(Badges.distance, [
          for (final a in hikes) (a.endedAt, a.distanceM / 1000),
        ]),
        _cumulative(Badges.elevation, [
          for (final a in hikes) (a.endedAt, a.elevationGainM),
        ]),
        _streak(hikes),
        _cumulative(Badges.dawn, [
          for (final a in hikes)
            if (a.startedAt.toLocal().hour < Badges.dawnHour) (a.endedAt, 1.0),
        ]),
        if (done == null) ...[
          _unavailable(Badges.summits),
          _unavailable(Badges.explorer),
          _unavailable(Badges.regular),
        ] else ...[
          _cumulative(Badges.summits, [
            for (final c in done) (c.completedAt, 1.0),
          ]),
          _explorer(done),
          _regular(done),
        ],
        if (leadRuns == null) ...[
          _unavailable(Badges.firstMost),
          _unavailable(Badges.firstFastest),
          _unavailable(Badges.hold),
          _unavailable(Badges.doubleCrown),
        ] else ...[
          _first(Badges.firstMost, runs, RankingKind.most),
          _first(Badges.firstFastest, runs, RankingKind.fastest),
          _hold(runs, now),
          _doubleCrown(runs, now),
        ],
        if (reviewDates == null)
          _unavailable(Badges.reviews)
        else
          _cumulative(Badges.reviews, [
            for (final d in [...reviewDates]..sort()) (d, 1.0),
          ]),
      ],
      seasons: [
        for (final r in runs)
          if (r.seasonFinal && r.isSeason)
            SeasonBadge(
              courseId: r.courseId,
              season: Season.parse(r.scope),
              kind: r.kind,
            ),
      ]..sort((a, b) => b.achievedAt.compareTo(a.achievedAt)),
    );
  }

  static BadgeStatus _unavailable(BadgeDef def) =>
      BadgeStatus(def: def, value: 0, achievedAt: const [], available: false);

  /// 시간 순서대로 값을 더해 가며 단계 기준을 처음 넘은 날짜를 찾는다.
  static BadgeStatus _cumulative(
    BadgeDef def,
    List<(DateTime, double)> events,
  ) {
    var total = 0.0;
    final dates = <DateTime>[];
    for (final (at, add) in events) {
      total += add;
      while (dates.length < def.levels &&
          total >= def.thresholds[dates.length]) {
        dates.add(at);
      }
    }
    return BadgeStatus(def: def, value: total, achievedAt: dates);
  }

  /// 값이 가장 컸던 순간까지 기준을 처음 넘은 날짜. [events]는 (날짜, 그때의 값) 시간 순서.
  static BadgeStatus _best(BadgeDef def, List<(DateTime, double)> events) {
    var best = 0.0;
    final dates = <DateTime>[];
    for (final (at, value) in events) {
      if (value > best) best = value;
      while (dates.length < def.levels &&
          best >= def.thresholds[dates.length]) {
        dates.add(at);
      }
    }
    return BadgeStatus(def: def, value: best, achievedAt: dates);
  }

  /// 월요일 시작 주 단위로, 산행한 주가 끊기지 않고 이어진 가장 긴 기간.
  static BadgeStatus _streak(List<ActivitySummary> hikes) {
    DateTime weekOf(DateTime t) {
      final l = t.toLocal();
      final day = DateTime(l.year, l.month, l.day);
      return DateTime(day.year, day.month, day.day - (day.weekday - 1));
    }

    DateTime? lastWeek;
    var run = 0;
    final events = <(DateTime, double)>[];
    for (final a in hikes) {
      final week = weekOf(a.startedAt);
      if (week == lastWeek) continue;
      final previous = lastWeek;
      run =
          previous != null &&
              DateTime(previous.year, previous.month, previous.day + 7) == week
          ? run + 1
          : 1;
      lastWeek = week;
      events.add((a.endedAt, run.toDouble()));
    }
    return _best(Badges.streak, events);
  }

  static BadgeStatus _explorer(List<MyCompletion> done) {
    final seen = <String>{};
    return _best(Badges.explorer, [
      for (final c in done)
        if (seen.add(c.courseId)) (c.completedAt, seen.length.toDouble()),
    ]);
  }

  static BadgeStatus _regular(List<MyCompletion> done) {
    final counts = <String, int>{};
    return _best(Badges.regular, [
      for (final c in done)
        (
          c.completedAt,
          (counts[c.courseId] = (counts[c.courseId] ?? 0) + 1).toDouble(),
        ),
    ]);
  }

  /// 처음 1위가 된 순간 (시즌·명예의 전당 어느 쪽이든)
  static BadgeStatus _first(
    BadgeDef def,
    List<LeadRun> runs,
    RankingKind kind,
  ) {
    final starts = [
      for (final r in runs)
        if (r.kind == kind) r.startedAt,
    ]..sort();
    return BadgeStatus(
      def: def,
      value: starts.isEmpty ? 0 : 1,
      achievedAt: starts.take(1).toList(),
    );
  }

  /// 한 코스·한 분야의 시즌 1위를 끊기지 않고 지킨 기간. 여러 구간을 더하지 않는다.
  static BadgeStatus _hold(List<LeadRun> runs, DateTime now) {
    final season = [
      for (final r in runs)
        if (r.isSeason) r,
    ];
    var bestDays = 0.0;
    for (final r in season) {
      final days = r.endOr(now).difference(r.startedAt).inHours / 24;
      if (days > bestDays) bestDays = days;
    }
    final dates = <DateTime>[];
    for (final goal in Badges.hold.thresholds) {
      final reached = [
        for (final r in season)
          if (r.endOr(now).difference(r.startedAt).inHours / 24 >= goal)
            r.startedAt.add(Duration(days: goal.toInt())),
      ]..sort();
      if (reached.isEmpty) break;
      dates.add(reached.first);
    }
    return BadgeStatus(
      def: Badges.hold,
      value: bestDays.floorToDouble(),
      achievedAt: dates,
    );
  }

  /// 같은 코스·같은 기간(시즌 또는 명예의 전당)에서 두 분야 1위였던 때가 겹친다.
  static BadgeStatus _doubleCrown(List<LeadRun> runs, DateTime now) {
    final overlaps = <DateTime>[];
    for (final a in runs) {
      if (a.kind != RankingKind.most) continue;
      for (final b in runs) {
        if (b.kind != RankingKind.fastest ||
            b.courseId != a.courseId ||
            b.scope != a.scope) {
          continue;
        }
        final start = a.startedAt.isAfter(b.startedAt)
            ? a.startedAt
            : b.startedAt;
        final aEnd = a.endOr(now);
        final bEnd = b.endOr(now);
        final end = aEnd.isBefore(bEnd) ? aEnd : bEnd;
        if (start.isBefore(end)) overlaps.add(start);
      }
    }
    overlaps.sort();
    return BadgeStatus(
      def: Badges.doubleCrown,
      value: overlaps.isEmpty ? 0 : 1,
      achievedAt: overlaps.take(1).toList(),
    );
  }
}
