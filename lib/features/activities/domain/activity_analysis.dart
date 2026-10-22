import 'dart:math' as math;

import '../../../core/utils/geo.dart';
import '../../recording/domain/track_point.dart';
import '../../recording/domain/track_stats.dart';

/// 경사에 따른 구간 종류
enum GradeKind { uphill, flat, downhill }

/// Tobler 등산 함수: 경사(오른 높이 / 걸은 거리)에 따른 표준 등산객의 걷는 속도(km/h).
/// 약간 내리막(-5%)에서 가장 빠르고(6km/h), 오르막이든 내리막이든 가파를수록 느려진다.
double toblerSpeedKmh(double grade) =>
    6 * math.exp(-3.5 * (grade + 0.05).abs());

/// 평지(경사 0)에서 표준 등산객의 속도. 약 5.04km/h
final double toblerFlatKmh = toblerSpeedKmh(0);

/// 기록 시작부터 잰 시간 범위 (그래프의 가로축과 같은 기준)
class TimeRange {
  const TimeRange(this.start, this.end);

  final Duration start;
  final Duration end;

  Duration get length => end - start;

  bool contains(Duration t) => t >= start && t <= end;
}

/// 고도 그래프의 한 점
class ElevationSample {
  const ElevationSample(this.elapsed, this.altitudeM);

  /// 기록 시작부터 지난 시간 (쉬거나 일시정지한 시간 포함)
  final Duration elapsed;
  final double altitudeM;
}

/// 오르막·평지·내리막 중 한 종류의 합계
class GradeSummary {
  const GradeSummary({
    required this.kind,
    required this.distanceM,
    required this.duration,
    required this.verticalM,
    required this.standardDuration,
  });

  final GradeKind kind;
  final double distanceM;

  /// 걸은 시간 (휴식 제외)
  final Duration duration;

  /// 오르거나 내려간 높이의 합 (항상 양수)
  final double verticalM;

  /// 같은 길을 표준 등산객(Tobler)이 걸었을 때 걸리는 시간
  final Duration standardDuration;

  /// 실제 평균 속도 (km/h)
  double get speedKmh =>
      duration.inSeconds == 0 ? 0 : distanceM / duration.inSeconds * 3.6;

  /// 표준 대비 내 속도. 1.1이면 표준보다 10% 빠르다. 걸은 시간이 없으면 null.
  double? get efficiency => duration.inSeconds == 0
      ? null
      : standardDuration.inMilliseconds / duration.inMilliseconds;

  /// 경사 보정 페이스(GAP): 이 속도로 평지를 걸었다면 1km에 걸리는 시간
  Duration? get gradeAdjustedPace => switch (efficiency) {
    final e? when e > 0 => Duration(
      milliseconds: (3600 * 1000 / toblerFlatKmh / e).round(),
    ),
    _ => null,
  };
}

/// 1km마다 걸린 시간
class KmSplit {
  const KmSplit({
    required this.km,
    required this.duration,
    required this.gainM,
  });

  /// 몇 번째 km인지 (1부터)
  final int km;
  final Duration duration;

  /// 이 1km에서 오른 높이
  final double gainM;
}

/// 전반·후반의 오르막 속도 비교 (기획서 6.4 "전반/후반 피로도")
class FatigueComparison {
  const FatigueComparison({
    required this.firstHalfClimbRate,
    required this.secondHalfClimbRate,
  });

  /// 오르막에서 한 시간에 오른 높이(m/h)
  final double firstHalfClimbRate;
  final double secondHalfClimbRate;

  /// 후반 오르막 속도 / 전반 오르막 속도. 1보다 작을수록 후반에 지쳤다는 뜻.
  double get ratio => secondHalfClimbRate / firstHalfClimbRate;
}

/// 구독자용 기록 상세 분석 결과
class ActivityAnalysis {
  const ActivityAnalysis({
    required this.elevationProfile,
    required this.totalDuration,
    required this.rests,
    required this.dangers,
    required this.grades,
    required this.splits,
    this.fatigue,
    this.dangerDownhill,
  });

  final List<ElevationSample> elevationProfile;

  /// 첫 점부터 마지막 점까지의 시간 (그래프 가로축 길이)
  final Duration totalDuration;

  /// 휴식 구간: 한자리에 머문 구간과 일시정지한 구간
  final List<TimeRange> rests;

  /// 위험 구간: 짧은 거리에 고도가 크게 바뀌는 급경사 (오르막·내리막 모두)
  final List<TimeRange> dangers;

  /// 오르막·평지·내리막 순서
  final List<GradeSummary> grades;
  final List<KmSplit> splits;

  /// 전반·후반 모두 오르막이 있어야 계산된다.
  final FatigueComparison? fatigue;

  /// 급경사 내리막 구간만 모은 합계. 그런 구간이 없으면 null.
  final GradeSummary? dangerDownhill;

  GradeSummary grade(GradeKind kind) =>
      grades.firstWhere((g) => g.kind == kind);

  Duration get restDuration =>
      rests.fold(Duration.zero, (sum, r) => sum + r.length);

  /// 걸은 시간 전체로 본 표준 대비 내 속도 (경사 보정)
  double? get efficiency {
    final walked = grades.fold(Duration.zero, (s, g) => s + g.duration);
    if (walked == Duration.zero) return null;
    final standard = grades.fold(
      Duration.zero,
      (s, g) => s + g.standardDuration,
    );
    return standard.inMilliseconds / walked.inMilliseconds;
  }

  /// 걸은 시간 전체의 경사 보정 페이스 (1km당)
  Duration? get gradeAdjustedPace => switch (efficiency) {
    final e? when e > 0 => Duration(
      milliseconds: (3600 * 1000 / toblerFlatKmh / e).round(),
    ),
    _ => null,
  };
}

/// 위치 기록으로 상세 분석을 계산한다. (순수 Dart, 단위 테스트 대상)
abstract final class ActivityAnalyzer {
  /// 경사를 잴 구간 길이. GPS 고도 흔들림을 줄이려고 짧게 자르지 않는다.
  static const windowM = 50.0;

  /// 이보다 가파르면 오르막·내리막 (5%)
  static const gradeThreshold = 0.05;

  /// 이보다 가파르면 위험 구간 (30%, 약 17°). 오르막·내리막 모두
  static const dangerGrade = 0.30;

  /// 이 반경 안에 [restMinDuration] 이상 머물면 휴식. GPS는 가만히 있어도 몇 m씩 흔들린다.
  static const restRadiusM = 15.0;
  static const restMinDuration = Duration(minutes: 2);

  /// 고도를 앞뒤 몇 점씩 평균 내서 흔들림을 줄인다.
  static const altitudeSmoothing = 2;

  /// 고도 그래프에 쓸 최대 점 개수
  static const maxProfilePoints = 120;

  static ActivityAnalysis analyze(List<TrackPoint> track) {
    final points = [
      for (final p in track)
        if (p.accuracy <= TrackStatsCalculator.maxAccuracyM) p,
    ];
    if (points.isEmpty) {
      return ActivityAnalysis(
        elevationProfile: const [],
        totalDuration: Duration.zero,
        rests: const [],
        dangers: const [],
        grades: _grades(const []),
        splits: const [],
      );
    }
    final origin = points.first.recordedAt;
    final altitudes = _smoothAltitudes(points);
    final rests = _rests(points, origin);
    final windows = _windows(points, altitudes, rests, origin);
    final steepDown = windows.where((w) => w.isDanger && w.riseM < 0).toList();
    return ActivityAnalysis(
      elevationProfile: _profile(points, altitudes, origin),
      totalDuration: points.last.recordedAt.difference(origin),
      rests: rests,
      dangers: _merge([
        for (final w in windows)
          if (w.isDanger) TimeRange(w.start, w.end),
      ]),
      grades: _grades(windows),
      splits: _splits(points),
      fatigue: _fatigue(windows),
      dangerDownhill: steepDown.isEmpty
          ? null
          : _sum(GradeKind.downhill, steepDown),
    );
  }

  static double _step(TrackPoint a, TrackPoint b) =>
      haversineMeters(a.latitude, a.longitude, b.latitude, b.longitude);

  /// 같은 구간(일시정지 사이) 안에서 앞뒤 [altitudeSmoothing]개 점의 고도를 평균 낸다.
  static List<double?> _smoothAltitudes(List<TrackPoint> points) {
    return [
      for (var i = 0; i < points.length; i++)
        if (points[i].altitude == null)
          null
        else
          () {
            var sum = 0.0;
            var count = 0;
            for (
              var j = math.max(0, i - altitudeSmoothing);
              j <= math.min(points.length - 1, i + altitudeSmoothing);
              j++
            ) {
              final alt = points[j].altitude;
              if (alt == null || points[j].segment != points[i].segment) {
                continue;
              }
              sum += alt;
              count++;
            }
            return sum / count;
          }(),
    ];
  }

  /// 휴식 구간: 반경 15m 안에 2분 이상 머문 구간 + 일시정지한 구간
  static List<TimeRange> _rests(List<TrackPoint> points, DateTime origin) {
    Duration at(int i) => points[i].recordedAt.difference(origin);
    final out = <TimeRange>[];
    var i = 0;
    while (i < points.length) {
      var j = i + 1;
      while (j < points.length &&
          points[j].segment == points[i].segment &&
          _step(points[i], points[j]) <= restRadiusM) {
        j++;
      }
      // i ~ j-1이 i에서 반경 안에 머문 점들
      if (at(j - 1) - at(i) >= restMinDuration) {
        out.add(TimeRange(at(i), at(j - 1)));
        i = j;
      } else {
        i++;
      }
    }
    for (var k = 1; k < points.length; k++) {
      if (points[k].segment != points[k - 1].segment) {
        out.add(TimeRange(at(k - 1), at(k)));
      }
    }
    return _merge(out);
  }

  /// 겹치거나 맞닿은 범위를 하나로 합친다.
  static List<TimeRange> _merge(List<TimeRange> ranges) {
    if (ranges.isEmpty) return const [];
    final sorted = [...ranges]..sort((a, b) => a.start.compareTo(b.start));
    final out = <TimeRange>[sorted.first];
    for (final r in sorted.skip(1)) {
      final last = out.last;
      if (r.start <= last.end) {
        out[out.length - 1] = TimeRange(
          last.start,
          r.end > last.end ? r.end : last.end,
        );
      } else {
        out.add(r);
      }
    }
    return out;
  }

  /// 같은 구간(일시정지 사이) 안의 점들을 약 50m씩 묶는다. 휴식 중인 이동은 빼고 센다.
  static List<_Window> _windows(
    List<TrackPoint> points,
    List<double?> altitudes,
    List<TimeRange> rests,
    DateTime origin,
  ) {
    bool resting(Duration a, Duration b) {
      final mid = a + (b - a) ~/ 2;
      return rests.any((r) => r.contains(mid));
    }

    final out = <_Window>[];
    var startIndex = 0;
    var distance = 0.0;
    var duration = Duration.zero;
    for (var i = 1; i < points.length; i++) {
      final a = points[i - 1];
      final b = points[i];
      if (a.segment != b.segment) {
        startIndex = i;
        distance = 0;
        duration = Duration.zero;
        continue;
      }
      final ta = a.recordedAt.difference(origin);
      final tb = b.recordedAt.difference(origin);
      if (resting(ta, tb)) continue;
      distance += _step(a, b);
      duration += tb - ta;
      if (distance >= windowM) {
        final from = altitudes[startIndex];
        final to = altitudes[i];
        out.add(
          _Window(
            distanceM: distance,
            duration: duration,
            riseM: (from != null && to != null) ? to - from : 0,
            start: points[startIndex].recordedAt.difference(origin),
            end: tb,
          ),
        );
        startIndex = i;
        distance = 0;
        duration = Duration.zero;
      }
    }
    return out;
  }

  static GradeSummary _sum(GradeKind kind, Iterable<_Window> ws) =>
      GradeSummary(
        kind: kind,
        distanceM: ws.fold(0, (s, w) => s + w.distanceM),
        duration: ws.fold(Duration.zero, (s, w) => s + w.duration),
        verticalM: ws.fold(0, (s, w) => s + w.riseM.abs()),
        standardDuration: ws.fold(
          Duration.zero,
          (s, w) => s + w.standardDuration,
        ),
      );

  static List<GradeSummary> _grades(List<_Window> windows) => [
    for (final k in GradeKind.values)
      _sum(k, windows.where((w) => w.kind == k)),
  ];

  /// 전체 시간을 반으로 나눠, 각 절반의 오르막 구간에서 시간당 오른 높이를 비교한다.
  static FatigueComparison? _fatigue(List<_Window> windows) {
    if (windows.length < 2) return null;
    final first = windows.first.start;
    final middle = first + (windows.last.end - first) ~/ 2;

    double? climbRate(Iterable<_Window> ws) {
      final up = ws.where((w) => w.kind == GradeKind.uphill);
      final seconds = up.fold(0, (s, w) => s + w.duration.inSeconds);
      if (seconds == 0) return null;
      return up.fold(0.0, (s, w) => s + w.riseM) / seconds * 3600;
    }

    final a = climbRate(windows.where((w) => w.end <= middle));
    final b = climbRate(windows.where((w) => w.end > middle));
    if (a == null || b == null || a <= 0) return null;
    return FatigueComparison(firstHalfClimbRate: a, secondHalfClimbRate: b);
  }

  static List<KmSplit> _splits(List<TrackPoint> points) {
    final out = <KmSplit>[];
    var distance = 0.0;
    var kmStartTime = points.first.recordedAt;
    var kmGain = 0.0;
    double? lastAltitude = points.first.altitude;
    for (var i = 1; i < points.length; i++) {
      final a = points[i - 1];
      final b = points[i];
      if (a.segment != b.segment) {
        // 일시정지 시간은 km 기록에 넣지 않는다.
        kmStartTime = kmStartTime.add(b.recordedAt.difference(a.recordedAt));
        continue;
      }
      distance += _step(a, b);
      if (b.altitude != null && lastAltitude != null) {
        kmGain += math.max(0, b.altitude! - lastAltitude);
      }
      lastAltitude = b.altitude ?? lastAltitude;
      if (distance >= (out.length + 1) * 1000) {
        out.add(
          KmSplit(
            km: out.length + 1,
            duration: b.recordedAt.difference(kmStartTime),
            gainM: kmGain,
          ),
        );
        kmStartTime = b.recordedAt;
        kmGain = 0;
      }
    }
    return out;
  }

  /// 고도 그래프: 지난 시간과 (흔들림을 줄인) 고도. 점이 많으면 고르게 솎아 낸다.
  static List<ElevationSample> _profile(
    List<TrackPoint> points,
    List<double?> altitudes,
    DateTime origin,
  ) {
    final all = [
      for (var i = 0; i < points.length; i++)
        if (altitudes[i] case final alt?)
          ElevationSample(points[i].recordedAt.difference(origin), alt),
    ];
    if (all.length <= maxProfilePoints) return all;
    final step = (all.length - 1) / (maxProfilePoints - 1);
    return [for (var i = 0; i < maxProfilePoints; i++) all[(i * step).round()]];
  }
}

class _Window {
  _Window({
    required this.distanceM,
    required this.duration,
    required this.riseM,
    required this.start,
    required this.end,
  });

  final double distanceM;
  final Duration duration;
  final double riseM;
  final Duration start;
  final Duration end;

  double get grade => riseM / distanceM;

  bool get isDanger => grade.abs() >= ActivityAnalyzer.dangerGrade;

  /// 표준 등산객(Tobler)이 이 구간을 걷는 데 걸리는 시간
  Duration get standardDuration => Duration(
    milliseconds: (distanceM / 1000 / toblerSpeedKmh(grade) * 3600 * 1000)
        .round(),
  );

  GradeKind get kind {
    if (grade > ActivityAnalyzer.gradeThreshold) return GradeKind.uphill;
    if (grade < -ActivityAnalyzer.gradeThreshold) return GradeKind.downhill;
    return GradeKind.flat;
  }
}
