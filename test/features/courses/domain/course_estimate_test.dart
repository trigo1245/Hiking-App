import 'package:flutter_test/flutter_test.dart';
import 'package:hiking_app/features/activities/domain/activity_analysis.dart';
import 'package:hiking_app/features/activities/domain/activity_summary.dart';
import 'package:hiking_app/features/courses/domain/competition.dart';
import 'package:hiking_app/features/courses/domain/course.dart';
import 'package:hiking_app/features/courses/domain/course_estimate.dart';

/// 북쪽으로 10m씩 가는 코스. 구간마다 (걸음 수, 걸음당 고도 변화)
Course course(List<(int, double)> legs, {bool withElevations = true}) {
  final path = <GeoPoint>[const GeoPoint(35.0, 129.0)];
  final ele = <double>[100];
  for (final (steps, rise) in legs) {
    for (var i = 0; i < steps; i++) {
      path.add(GeoPoint(path.last.lat + 10 / 111195, 129.0));
      ele.add(ele.last + rise);
    }
  }
  return Course(
    id: 'c',
    mountainName: '산',
    name: '코스',
    startName: '들머리',
    endName: '정상',
    distanceM: (path.length - 1) * 10,
    path: path,
    summit: path.last,
    officialTimeMin: 30,
    elevations: withElevations ? ele : null,
  );
}

ActivitySummary hikeOn(int day) => ActivitySummary(
  id: 'h$day',
  title: '산행',
  startedAt: DateTime.utc(2026, 10, day),
  endedAt: DateTime.utc(2026, 10, day, 3),
  elapsed: const Duration(hours: 3),
  moving: const Duration(hours: 2),
  distanceM: 6000,
  elevationGainM: 500,
  maxAltitudeM: 600,
  pointCount: 100,
  isFlagged: false,
);

/// 오르막·평지·내리막 효율(표준 대비 내 속도)과 휴식을 정한 가짜 분석.
/// 오르막은 [uphillMinutes]분 걸었다.
ActivityAnalysis analysis({
  double up = 1,
  double flat = 1,
  double down = 1,
  int uphillMinutes = 60,
  Duration rest = Duration.zero,
  double? steepDown,
}) {
  GradeSummary g(GradeKind kind, double efficiency, int minutes) =>
      GradeSummary(
        kind: kind,
        distanceM: 1000,
        duration: Duration(minutes: minutes),
        verticalM: 100,
        standardDuration: Duration(
          milliseconds: (minutes * 60000 * efficiency).round(),
        ),
      );
  return ActivityAnalysis(
    elevationProfile: const [],
    totalDuration: const Duration(minutes: 100),
    rests: [if (rest > Duration.zero) TimeRange(Duration.zero, rest)],
    dangers: const [],
    grades: [
      g(GradeKind.uphill, up, uphillMinutes),
      g(GradeKind.flat, flat, 20),
      g(GradeKind.downhill, down, 20),
    ],
    splits: const [],
    dangerDownhill: steepDown == null
        ? null
        : g(GradeKind.downhill, steepDown, 5),
  );
}

List<(ActivitySummary, ActivityAnalysis)> hikes(
  int n,
  ActivityAnalysis Function(int i) make,
) => [for (var i = 0; i < n; i++) (hikeOn(i + 1), make(i))];

void main() {
  group('코스 경사 구성', () {
    test('평지 1km는 표준 등산객이 약 11분 55초 걸린다', () {
      final p = CourseProfile.of(course([(100, 0)]))!;
      expect(p.distanceM, closeTo(1000, 1));
      expect(
        p.standard[GradeKind.flat]!.inSeconds,
        closeTo(1000 / toblerFlatKmh * 3.6, 2),
      );
      expect(p.gainM, closeTo(0, 0.01));
      expect(p.steepCount, 0);
    });

    test('15% 오르막 1km는 Tobler 속도(약 2.98km/h)로 계산한다', () {
      final p = CourseProfile.of(course([(100, 1.5)]))!;
      expect(
        p.standard[GradeKind.uphill]!.inSeconds,
        // 양 끝은 평균 낼 이웃 점이 적어 경사가 조금 완만하게 나온다 (약 1%).
        closeTo(1000 / toblerSpeedKmh(0.15) * 3.6, 25),
      );
      expect(p.gainM, closeTo(150, 3));
    });

    test('경사 30% 이상이 이어진 구간은 한 곳으로 센다', () {
      final p = CourseProfile.of(
        course([(30, 0), (20, 4), (30, 0), (15, 3.5), (30, 0)]),
      )!;
      expect(p.steepCount, 2);
      expect(p.steepLengthM, greaterThan(250));
    });

    test('고도가 없거나 경로와 개수가 다르면 계산하지 않는다', () {
      expect(
        CourseProfile.of(course([(10, 1)], withElevations: false)),
        isNull,
      );
      final c = course([(10, 1)]);
      final broken = Course(
        id: c.id,
        mountainName: c.mountainName,
        name: c.name,
        startName: c.startName,
        endName: c.endName,
        distanceM: c.distanceM,
        path: c.path,
        summit: c.summit,
        elevations: c.elevations!.sublist(1),
      );
      expect(CourseProfile.of(broken), isNull);
    });
  });

  group('예상 소요시간', () {
    final uphillCourse = CourseProfile.of(course([(100, 1.5)]))!;

    test('산행이 3번 미만이면 표준 등산객 기준', () {
      final e = CourseEstimate.of(
        profile: uphillCourse,
        hikes: hikes(2, (_) => analysis(up: 2)),
        myCompletions: const [],
      );
      expect(e.personal, isFalse);
      expect(
        e.walking.inSeconds,
        closeTo(uphillCourse.standardTotal.inSeconds, 1),
      );
      expect(e.difficulty, isNull);
    });

    test('오르막 속도가 표준의 125%면 오르막 시간이 그만큼 줄어든다', () {
      final e = CourseEstimate.of(
        profile: uphillCourse,
        hikes: hikes(5, (_) => analysis(up: 1.25)),
        myCompletions: const [],
      );
      expect(e.personal, isTrue);
      expect(e.basedOnHikes, 5);
      expect(
        e.walking.inSeconds,
        closeTo(uphillCourse.standardTotal.inSeconds / 1.25, 2),
      );
    });

    test('최근 10번만 쓴다 (오래된 느린 기록은 빠진다)', () {
      final e = CourseEstimate.of(
        profile: uphillCourse,
        // 1~5일은 느리고(50%), 6~15일은 표준 속도
        hikes: hikes(15, (i) => analysis(up: i < 5 ? 0.5 : 1)),
        myCompletions: const [],
      );
      expect(e.basedOnHikes, 10);
      expect(
        e.walking.inSeconds,
        closeTo(uphillCourse.standardTotal.inSeconds, 2),
      );
    });

    test('최근 산행의 휴식 비율만큼 휴식 시간을 더한다', () {
      // 전체 100분 중 20분 휴식 → 걷는 시간의 25%를 더한다
      final e = CourseEstimate.of(
        profile: uphillCourse,
        hikes: hikes(3, (_) => analysis(rest: const Duration(minutes: 20))),
        myCompletions: const [],
      );
      expect(e.rest.inSeconds, closeTo(e.walking.inSeconds * 0.25, 2));
      expect(e.total, e.walking + e.rest);
    });
  });

  group('맞춤 난이도', () {
    // 표준 오르막 약 20분 코스
    final uphillCourse = CourseProfile.of(course([(100, 1.5)]))!;

    PersonalDifficulty? difficultyFor(int usualUphillMinutes) =>
        CourseEstimate.of(
          profile: uphillCourse,
          hikes: hikes(3, (_) => analysis(uphillMinutes: usualUphillMinutes)),
          myCompletions: const [],
        ).difficulty;

    test('평소 오르막보다 1.25배 넘게 길면 힘든 편', () {
      expect(difficultyFor(10), PersonalDifficulty.harder);
    });

    test('비슷하면 평소 정도, 0.8배보다 짧으면 쉬운 편', () {
      expect(difficultyFor(20), PersonalDifficulty.usual);
      expect(difficultyFor(60), PersonalDifficulty.easier);
    });
  });

  group('비교와 내 기록', () {
    final profile = CourseProfile.of(course([(100, 1.5)]))!;

    test('완주자 평균이 있으면 그것과, 없으면 공식 시간과 비교한다', () {
      final withAverage = CourseEstimate.of(
        profile: profile,
        hikes: const [],
        myCompletions: const [],
        communityAverage: const Duration(minutes: 25),
        officialTimeMin: 30,
      );
      expect(withAverage.compareTo!.label, '완주자 평균');

      final official = CourseEstimate.of(
        profile: profile,
        hikes: const [],
        myCompletions: const [],
        officialTimeMin: 30,
      );
      expect(official.compareTo!.label, '공식 시간');
      expect(official.compareTo!.time, const Duration(minutes: 30));
    });

    test('이 코스를 완주했다면 내 기록 평균과 최고', () {
      final e = CourseEstimate.of(
        profile: profile,
        hikes: const [],
        myCompletions: [
          MyCompletion(
            courseId: 'c',
            ascent: const Duration(minutes: 20),
            completedAt: DateTime.utc(2026, 10, 1),
          ),
          MyCompletion(
            courseId: 'c',
            ascent: const Duration(minutes: 30),
            completedAt: DateTime.utc(2026, 10, 8),
          ),
        ],
      );
      expect(e.myRecords!.count, 2);
      expect(e.myRecords!.average, const Duration(minutes: 25));
      expect(e.myRecords!.best, const Duration(minutes: 20));
    });
  });

  group('안전 안내', () {
    final steep = CourseProfile.of(course([(30, 0), (20, 4), (30, 0)]))!;

    test('급경사가 있으면 알려 준다', () {
      final e = CourseEstimate.of(
        profile: steep,
        hikes: const [],
        myCompletions: const [],
      );
      expect(e.warnings.whereType<SteepSections>().single.count, 1);
    });

    test('급경사 내리막에서 빨라지는 습관이 있으면 같이 알려 준다', () {
      final e = CourseEstimate.of(
        profile: steep,
        hikes: hikes(3, (_) => analysis(down: 1, steepDown: 1.4)),
        myCompletions: const [],
      );
      expect(e.warnings.whereType<SteepDownhillHabit>(), hasLength(1));
    });

    test('급경사가 없으면 습관 안내도 하지 않는다', () {
      final e = CourseEstimate.of(
        profile: CourseProfile.of(course([(100, 1)]))!,
        hikes: hikes(3, (_) => analysis(steepDown: 1.4)),
        myCompletions: const [],
      );
      expect(e.warnings, isEmpty);
    });

    test('평소보다 힘든 코스면 준비 안내', () {
      final e = CourseEstimate.of(
        profile: CourseProfile.of(course([(300, 1.5)]))!,
        hikes: hikes(3, (_) => analysis(uphillMinutes: 10)),
        myCompletions: const [],
      );
      expect(e.difficulty, PersonalDifficulty.harder);
      expect(e.warnings.whereType<HarderThanUsual>(), hasLength(1));
    });
  });
}
