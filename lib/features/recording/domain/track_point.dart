/// GPS가 알려 준 위치 한 개. 아직 어느 기록·구간에 속하는지 모른다.
class LocationSample {
  const LocationSample({
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.recordedAt,
    this.altitude,
    this.speed,
  });

  final double latitude;
  final double longitude;

  /// 해발 고도(m). 기기가 모르면 null.
  final double? altitude;

  /// 수평 정확도(m). 작을수록 정확하다.
  final double accuracy;

  /// 기기가 알려 준 속도(m/s). 계산에는 쓰지 않고 원본으로만 저장한다.
  final double? speed;
  final DateTime recordedAt;
}

/// 기록에 저장되는 위치 한 개.
class TrackPoint {
  const TrackPoint({
    required this.segment,
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.recordedAt,
    this.altitude,
    this.speed,
  });

  factory TrackPoint.fromSample(LocationSample s, {required int segment}) =>
      TrackPoint(
        segment: segment,
        latitude: s.latitude,
        longitude: s.longitude,
        altitude: s.altitude,
        accuracy: s.accuracy,
        speed: s.speed,
        recordedAt: s.recordedAt,
      );

  /// 일시정지할 때마다 바뀌는 구간 번호. 구간이 다른 점끼리는 거리를 더하지 않는다.
  final int segment;
  final double latitude;
  final double longitude;
  final double? altitude;
  final double accuracy;
  final double? speed;
  final DateTime recordedAt;
}
