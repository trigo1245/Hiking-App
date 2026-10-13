import 'dart:math' as math;

import '../../../core/utils/geo.dart';
import 'track_point.dart';

/// 기록의 요약 수치.
class TrackStats {
  const TrackStats({
    this.distanceM = 0,
    this.elevationGainM = 0,
    this.maxAltitudeM,
    this.moving = Duration.zero,
    this.pointCount = 0,
    this.isFlagged = false,
  });

  final double distanceM;
  final double elevationGainM;
  final double? maxAltitudeM;

  /// 움직인 시간. 일시정지 구간과 멈춰 있던 구간은 빠진다.
  final Duration moving;

  /// 저장한 점 개수 (정확도가 나빠 계산에서 뺀 점도 포함)
  final int pointCount;

  /// 인접한 점 사이 속도가 기준을 넘은 적이 있는지 (부정행위 의심 표시)
  final bool isFlagged;
}

/// 위치를 하나씩 받으면서 요약 수치를 누적 계산한다.
/// 기록 중 화면 표시와 기록 종료 후 저장에 같은 계산기를 쓴다.
class TrackStatsCalculator {
  /// 이보다 정확도가 나쁜(값이 큰) 점은 계산에서 뺀다.
  static const maxAccuracyM = 30.0;

  /// GPS 고도 흔들림을 무시하기 위한 최소 변화량
  static const elevationThresholdM = 3.0;

  /// 인접한 점 사이 속도가 이 값을 넘으면 기록에 표시한다.
  static const flagSpeedKmh = 15.0;

  /// 이보다 느리면 멈춰 있던 것으로 보고 이동 시간에서 뺀다. (0.3m/s ≈ 1.1km/h)
  static const minMovingSpeedMps = 0.3;

  int _pointCount = 0;
  double _distanceM = 0;
  double _elevationGainM = 0;
  double? _maxAltitudeM;
  Duration _moving = Duration.zero;
  bool _isFlagged = false;

  TrackPoint? _lastAccepted;

  /// 상승고도 계산의 기준 고도. 3m 이상 오르면 그만큼 더하고 기준을 올린다.
  /// 3m 이상 내려가면 더하지 않고 기준만 내린다.
  double? _altitudeRef;

  TrackStats get stats => TrackStats(
    distanceM: _distanceM,
    elevationGainM: _elevationGainM,
    maxAltitudeM: _maxAltitudeM,
    moving: _moving,
    pointCount: _pointCount,
    isFlagged: _isFlagged,
  );

  void addAll(Iterable<TrackPoint> points) => points.forEach(add);

  void add(TrackPoint point) {
    _pointCount++;
    if (point.accuracy > maxAccuracyM) return;

    _addAltitude(point.altitude);

    final previous = _lastAccepted;
    _lastAccepted = point;
    if (previous == null || previous.segment != point.segment) return;

    final seconds =
        point.recordedAt.difference(previous.recordedAt).inMilliseconds / 1000;
    if (seconds <= 0) return;

    final meters = haversineMeters(
      previous.latitude,
      previous.longitude,
      point.latitude,
      point.longitude,
    );
    _distanceM += meters;

    final speedMps = meters / seconds;
    if (speedMps * 3.6 > flagSpeedKmh) _isFlagged = true;
    if (speedMps >= minMovingSpeedMps) {
      _moving += point.recordedAt.difference(previous.recordedAt);
    }
  }

  void _addAltitude(double? altitude) {
    if (altitude == null) return;
    _maxAltitudeM = math.max(_maxAltitudeM ?? altitude, altitude);

    final ref = _altitudeRef;
    if (ref == null) {
      _altitudeRef = altitude;
    } else if (altitude - ref >= elevationThresholdM) {
      _elevationGainM += altitude - ref;
      _altitudeRef = altitude;
    } else if (ref - altitude >= elevationThresholdM) {
      _altitudeRef = altitude;
    }
  }
}
