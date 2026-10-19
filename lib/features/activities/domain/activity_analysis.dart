import 'dart:math' as math;

import '../../../core/utils/geo.dart';
import '../../recording/domain/track_point.dart';
import '../../recording/domain/track_stats.dart';

/// 경사에 따른 구간 종류
enum GradeKind { uphill, flat, downhill }

/// 고도 그래프의 한 점
class ElevationSample {
  const ElevationSample(this.distanceM, this.altitudeM);

  /// 출발점부터 걸은 거리
  final double distanceM;
  final double altitudeM;
}

/// 오르막·평지·내리막 중 한 종류의 합계
class GradeSummary {
  const GradeSummary({
    required this.kind,
    required this.distanceM,
    required this.duration,
    required this.verticalM,
  });

  final GradeKind kind;
  final double distanceM;
  final Duration duration;

  /// 오르거나 내려간 높이의 합 (항상 양수)
  final double verticalM;

  /// 평균 속도 (km/h)
  double get speedKmh =>
      duration.inSeconds == 0 ? 0 : distanceM / duration.inSeconds * 3.6;
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
    required this.grades,
    required this.splits,
    this.fatigue,
  });

  final List<ElevationSample> elevationProfile;

  /// 오르막·평지·내리막 순서
  final List<GradeSummary> grades;
  final List<KmSplit> splits;

  /// 전반·후반 모두 오르막이 있어야 계산된다.
  final FatigueComparison? fatigue;

  GradeSummary grade(GradeKind kind) =>
      grades.firstWhere((g) => g.kind == kind);
}

/// 위치 기록으로 상세 분석을 계산한다. (순수 Dart, 단위 테스트 대상)
abstract final class ActivityAnalyzer {
  /// 경사를 잴 구간 길이. GPS 고도 흔들림을 줄이려고 짧게 자르지 않는다.
  static const windowM = 50.0;

  /// 이보다 가파르면 오르막·내리막 (5%)
  static const gradeThreshold = 0.05;

  /// 고도 그래프에 쓸 최대 점 개수
  static const maxProfilePoints = 120;

  static ActivityAnalysis analyze(List<TrackPoint> track) {
    final points = [
      for (final p in track)
        if (p.accuracy <= TrackStatsCalculator.maxAccuracyM) p,
    ];
    final windows = _windows(points);
    return ActivityAnalysis(
      elevationProfile: _profile(points),
      grades: _grades(windows),
      splits: _splits(points),
      fatigue: _fatigue(windows),
    );
  }

  static double _step(TrackPoint a, TrackPoint b) =>
      haversineMeters(a.latitude, a.longitude, b.latitude, b.longitude);

  /// 같은 구간(일시정지 사이) 안의 점들을 약 50m씩 묶는다.
  static List<_Window> _windows(List<TrackPoint> points) {
    final out = <_Window>[];
    TrackPoint? start;
    TrackPoint? previous;
    var distance = 0.0;
    var duration = Duration.zero;
    for (final p in points) {
      if (previous == null || previous.segment != p.segment) {
        start = p;
        previous = p;
        distance = 0;
        duration = Duration.zero;
        continue;
      }
      distance += _step(previous, p);
      duration += p.recordedAt.difference(previous.recordedAt);
      previous = p;
      if (distance >= windowM) {
        final rise = (p.altitude != null && start!.altitude != null)
            ? p.altitude! - start.altitude!
            : 0.0;
        out.add(_Window(distance, duration, rise, p.recordedAt));
        start = p;
        distance = 0;
        duration = Duration.zero;
      }
    }
    return out;
  }

  static List<GradeSummary> _grades(List<_Window> windows) {
    GradeSummary sum(GradeKind kind) {
      final ws = windows.where((w) => w.kind == kind);
      return GradeSummary(
        kind: kind,
        distanceM: ws.fold(0, (s, w) => s + w.distanceM),
        duration: ws.fold(Duration.zero, (s, w) => s + w.duration),
        verticalM: ws.fold(0, (s, w) => s + w.riseM.abs()),
      );
    }

    return [for (final k in GradeKind.values) sum(k)];
  }

  /// 전체 시간을 반으로 나눠, 각 절반의 오르막 구간에서 시간당 오른 높이를 비교한다.
  static FatigueComparison? _fatigue(List<_Window> windows) {
    if (windows.length < 2) return null;
    final first = windows.first.endedAt.subtract(windows.first.duration);
    final middle = first.add(windows.last.endedAt.difference(first) ~/ 2);

    double? climbRate(Iterable<_Window> ws) {
      final up = ws.where((w) => w.kind == GradeKind.uphill);
      final seconds = up.fold(0, (s, w) => s + w.duration.inSeconds);
      if (seconds == 0) return null;
      return up.fold(0.0, (s, w) => s + w.riseM) / seconds * 3600;
    }

    final a = climbRate(windows.where((w) => !w.endedAt.isAfter(middle)));
    final b = climbRate(windows.where((w) => w.endedAt.isAfter(middle)));
    if (a == null || b == null || a <= 0) return null;
    return FatigueComparison(firstHalfClimbRate: a, secondHalfClimbRate: b);
  }

  static List<KmSplit> _splits(List<TrackPoint> points) {
    final out = <KmSplit>[];
    var distance = 0.0;
    var kmStartTime = points.isEmpty ? null : points.first.recordedAt;
    var kmGain = 0.0;
    double? lastAltitude = points.isEmpty ? null : points.first.altitude;
    for (var i = 1; i < points.length; i++) {
      final a = points[i - 1];
      final b = points[i];
      if (a.segment != b.segment) {
        // 일시정지 시간은 km 기록에 넣지 않는다.
        kmStartTime = kmStartTime!.add(b.recordedAt.difference(a.recordedAt));
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
            duration: b.recordedAt.difference(kmStartTime!),
            gainM: kmGain,
          ),
        );
        kmStartTime = b.recordedAt;
        kmGain = 0;
      }
    }
    return out;
  }

  /// 고도 그래프: 누적 거리와 고도. 점이 많으면 고르게 솎아 낸다.
  static List<ElevationSample> _profile(List<TrackPoint> points) {
    final all = <ElevationSample>[];
    var distance = 0.0;
    for (var i = 0; i < points.length; i++) {
      if (i > 0 && points[i - 1].segment == points[i].segment) {
        distance += _step(points[i - 1], points[i]);
      }
      final alt = points[i].altitude;
      if (alt != null) all.add(ElevationSample(distance, alt));
    }
    if (all.length <= maxProfilePoints) return all;
    final step = (all.length - 1) / (maxProfilePoints - 1);
    return [for (var i = 0; i < maxProfilePoints; i++) all[(i * step).round()]];
  }
}

class _Window {
  _Window(this.distanceM, this.duration, this.riseM, this.endedAt);

  final double distanceM;
  final Duration duration;
  final double riseM;
  final DateTime endedAt;

  GradeKind get kind {
    final grade = riseM / distanceM;
    if (grade > ActivityAnalyzer.gradeThreshold) return GradeKind.uphill;
    if (grade < -ActivityAnalyzer.gradeThreshold) return GradeKind.downhill;
    return GradeKind.flat;
  }
}
