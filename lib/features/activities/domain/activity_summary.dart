/// 끝난 기록 한 건의 요약. 기록 완료·목록·상세 화면에서 쓴다.
class ActivitySummary {
  const ActivitySummary({
    required this.id,
    required this.title,
    required this.startedAt,
    required this.endedAt,
    required this.elapsed,
    required this.moving,
    required this.distanceM,
    required this.elevationGainM,
    required this.maxAltitudeM,
    required this.pointCount,
    required this.isFlagged,
  });

  final String id;
  final String title;
  final DateTime startedAt;
  final DateTime endedAt;

  /// 시작부터 끝까지 전체 시간 (일시정지 포함)
  final Duration elapsed;

  /// 실제로 움직인 시간
  final Duration moving;
  final double distanceM;
  final double elevationGainM;
  final double? maxAltitudeM;
  final int pointCount;
  final bool isFlagged;
}
