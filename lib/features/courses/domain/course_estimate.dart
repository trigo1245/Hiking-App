import 'dart:math' as math;

import '../../../core/utils/geo.dart';
import '../../activities/domain/activity_analysis.dart';
import '../../activities/domain/activity_summary.dart';
import '../../activities/domain/hiking_stats.dart';
import 'competition.dart';
import 'course.dart';

/// 코스(들머리 → 정상)의 경사 구성. 경로와 점마다의 고도로 계산한다.
class CourseProfile {
  const CourseProfile({
    required this.distanceM,
    required this.gainM,
    required this.standard,
    required this.steepCount,
    required this.steepLengthM,
  });

  /// 경사를 잴 구간 길이 (기록 분석과 같은 50m)
  static const windowM = ActivityAnalyzer.windowM;

  final double distanceM;

  /// 오른 높이의 합 (흔들림을 줄인 고도 기준)
  final double gainM;

  /// 오르막·평지·내리막마다 표준 등산객(Tobler)이 걷는 시간
  final Map<GradeKind, Duration> standard;

  /// 경사 30% 이상 급경사가 몇 곳인지 (이어진 구간은 한 곳)
  final int steepCount;
  final double steepLengthM;

  Duration get standardTotal =>
      standard.values.fold(Duration.zero, (s, d) => s + d);

  /// 고도가 없거나 경로와 개수가 다르면 null
  static CourseProfile? of(Course course) {
    final raw = course.elevations;
    final path = course.path;
    if (raw == null || raw.length != path.length || path.length < 2) {
      return null;
    }
    // 기록 분석과 같이 앞뒤 2점씩 평균 내서 흔들림을 줄인다.
    const k = ActivityAnalyzer.altitudeSmoothing;
    final ele = [
      for (var i = 0; i < raw.length; i++)
        () {
          final from = math.max(0, i - k);
          final to = math.min(raw.length - 1, i + k);
          var sum = 0.0;
          for (var j = from; j <= to; j++) {
            sum += raw[j];
          }
          return sum / (to - from + 1);
        }(),
    ];

    final standard = {for (final kind in GradeKind.values) kind: Duration.zero};
    var total = 0.0;
    var gain = 0.0;
    var steepCount = 0;
    var steepLength = 0.0;
    var wasSteep = false;
    var start = 0;
    var distance = 0.0;

    void closeWindow(int end) {
      final rise = ele[end] - ele[start];
      final grade = rise / distance;
      final kind = grade > ActivityAnalyzer.gradeThreshold
          ? GradeKind.uphill
          : grade < -ActivityAnalyzer.gradeThreshold
          ? GradeKind.downhill
          : GradeKind.flat;
      standard[kind] =
          standard[kind]! +
          Duration(
            milliseconds: (distance / 1000 / toblerSpeedKmh(grade) * 3600000)
                .round(),
          );
      if (rise > 0) gain += rise;
      final steep = grade.abs() >= ActivityAnalyzer.dangerGrade;
      if (steep) {
        steepLength += distance;
        if (!wasSteep) steepCount++;
      }
      wasSteep = steep;
      start = end;
      distance = 0;
    }

    for (var i = 1; i < path.length; i++) {
      final step = haversineMeters(
        path[i - 1].lat,
        path[i - 1].lon,
        path[i].lat,
        path[i].lon,
      );
      distance += step;
      total += step;
      if (distance >= windowM) closeWindow(i);
    }
    // 남은 짧은 끝부분도 시간에는 넣는다.
    if (distance > 0) closeWindow(path.length - 1);

    return CourseProfile(
      distanceM: total,
      gainM: gain,
      standard: standard,
      steepCount: steepCount,
      steepLengthM: steepLength,
    );
  }
}

/// 내 평소 산행과 비교한 이 코스의 난이도
enum PersonalDifficulty { easier, usual, harder }

/// 코스 화면에 띄우는 안전 안내
sealed class SafetyWarning {
  const SafetyWarning();
}

/// 경사 30% 이상 급경사 구간이 있다.
class SteepSections extends SafetyWarning {
  const SteepSections(this.count, this.lengthM);

  final int count;
  final double lengthM;
}

/// 급경사 내리막에서 빨라지는 습관이 있다 (같은 길로 내려올 때 주의).
class SteepDownhillHabit extends SafetyWarning {
  const SteepDownhillHabit(this.ratio);

  /// 급경사 내리막 속도 / 평소 내리막 속도 (경사 보정)
  final double ratio;
}

/// 평소 산행보다 힘든 코스다.
class HarderThanUsual extends SafetyWarning {
  const HarderThanUsual();
}

/// 구독자용 "나에게 맞춘 예상" (오르는 시간 기준, 휴식 포함)
class CourseEstimate {
  const CourseEstimate({
    required this.personal,
    required this.basedOnHikes,
    required this.walking,
    required this.rest,
    required this.warnings,
    this.workloadRatio,
    this.difficulty,
    this.compareTo,
    this.myRecords,
  });

  /// 최근 몇 번의 산행으로 계산할지
  static const recentHikes = 10;

  /// 이보다 산행이 적으면 표준 등산객 기준으로 보여 준다.
  static const minHikes = 3;

  /// 평소 대비 이보다 작으면 쉬운 편, 크면 힘든 편
  static const easierBelow = 0.8;
  static const harderAbove = 1.25;

  /// 휴식 비율 상한 (예외적으로 오래 쉰 기록에 끌려가지 않게)
  static const maxRestRatio = 0.5;

  /// 내 기록으로 계산했는지 (false면 표준 등산객 기준)
  final bool personal;
  final int basedOnHikes;

  /// 걷는 시간
  final Duration walking;

  /// 더한 휴식 시간 (최근 산행의 휴식 비율)
  final Duration rest;

  Duration get total => walking + rest;

  /// 이 코스 걷는 시간 / 내가 평소 오르막을 걷는 시간(최근 산행 중간값)
  final double? workloadRatio;
  final PersonalDifficulty? difficulty;

  /// 비교 기준 (완주자 평균, 없으면 공식 시간)
  final ({String label, Duration time})? compareTo;

  /// 이 코스를 이미 완주했다면 내 기록
  final ({int count, Duration average, Duration best})? myRecords;

  final List<SafetyWarning> warnings;

  static CourseEstimate of({
    required CourseProfile profile,
    required List<(ActivitySummary, ActivityAnalysis)> hikes,
    required List<MyCompletion> myCompletions,
    Duration? communityAverage,
    int? officialTimeMin,
  }) {
    final recent = [
      for (final h in hikes)
        if (h.$2.efficiency != null) h,
    ]..sort((a, b) => b.$1.startedAt.compareTo(a.$1.startedAt));
    final used = recent.take(recentHikes).toList();
    final personal = used.length >= minHikes;

    // 여러 산행을 합친 경사 보정 속도 (표준 시간 합 / 실제 시간 합)
    double? efficiencyOf(Iterable<GradeSummary> gs) {
      final walked = gs.fold(Duration.zero, (s, g) => s + g.duration);
      if (walked == Duration.zero) return null;
      final standard = gs.fold(Duration.zero, (s, g) => s + g.standardDuration);
      return standard.inMilliseconds / walked.inMilliseconds;
    }

    final overall = efficiencyOf(used.expand((h) => h.$2.grades));
    double efficiency(GradeKind kind) => personal
        ? (efficiencyOf(used.map((h) => h.$2.grade(kind))) ?? overall ?? 1)
        : 1;

    var walkingMs = 0.0;
    for (final MapEntry(key: kind, value: standard)
        in profile.standard.entries) {
      walkingMs += standard.inMilliseconds / efficiency(kind);
    }
    final walking = Duration(milliseconds: walkingMs.round());

    // 휴식: 최근 산행에서 전체 시간 중 쉰 비율만큼 더한다.
    final totalTime = used.fold(
      Duration.zero,
      (s, h) => s + h.$2.totalDuration,
    );
    final restTime = used.fold(Duration.zero, (s, h) => s + h.$2.restDuration);
    final restRatio = totalTime == Duration.zero
        ? 0.0
        : math.min(maxRestRatio, restTime.inSeconds / totalTime.inSeconds);
    final rest = Duration(
      milliseconds: (walking.inMilliseconds * restRatio / (1 - restRatio))
          .round(),
    );

    // 맞춤 난이도: 평소 오르막 걷는 시간(중간값)과 비교
    double? ratio;
    PersonalDifficulty? difficulty;
    if (personal) {
      final climbs = [
        for (final h in used)
          if (h.$2.grade(GradeKind.uphill).duration > Duration.zero)
            h.$2.grade(GradeKind.uphill).duration.inSeconds,
      ]..sort();
      if (climbs.isNotEmpty) {
        final median = climbs.length.isOdd
            ? climbs[climbs.length ~/ 2].toDouble()
            : (climbs[climbs.length ~/ 2 - 1] + climbs[climbs.length ~/ 2]) / 2;
        ratio = walking.inSeconds / median;
        difficulty = ratio < easierBelow
            ? PersonalDifficulty.easier
            : ratio > harderAbove
            ? PersonalDifficulty.harder
            : PersonalDifficulty.usual;
      }
    }

    // 안전 안내
    final warnings = <SafetyWarning>[];
    if (profile.steepCount > 0) {
      warnings.add(SteepSections(profile.steepCount, profile.steepLengthM));
      final steepDown = efficiencyOf([
        for (final h in used) ?h.$2.dangerDownhill,
      ]);
      final down = efficiencyOf(
        used.map((h) => h.$2.grade(GradeKind.downhill)),
      );
      if (personal && steepDown != null && down != null && down > 0) {
        final habit = steepDown / down;
        if (habit > PremiumStats.steepDownhillWarn) {
          warnings.add(SteepDownhillHabit(habit));
        }
      }
    }
    if (difficulty == PersonalDifficulty.harder) {
      warnings.add(const HarderThanUsual());
    }

    ({int count, Duration average, Duration best})? mine;
    if (myCompletions.isNotEmpty) {
      final seconds = myCompletions.map((c) => c.ascent.inSeconds).toList();
      mine = (
        count: seconds.length,
        average: Duration(
          seconds: (seconds.reduce((a, b) => a + b) / seconds.length).round(),
        ),
        best: Duration(seconds: seconds.reduce(math.min)),
      );
    }

    return CourseEstimate(
      personal: personal,
      basedOnHikes: used.length,
      walking: walking,
      rest: rest,
      workloadRatio: ratio,
      difficulty: difficulty,
      compareTo: communityAverage != null
          ? (label: '완주자 평균', time: communityAverage)
          : officialTimeMin != null
          ? (label: '공식 시간', time: Duration(minutes: officialTimeMin))
          : null,
      myRecords: mine,
      warnings: warnings,
    );
  }
}
