/// 서버 업로드 상태
enum UploadStatus {
  /// 아직 올리지 못함. 네트워크가 돌아오면 자동으로 다시 시도한다.
  pending,
  done,

  /// 서버가 거절함. 기록 탭에서 다시 시도할 수 있다.
  failed,
}

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
    this.uploadStatus = UploadStatus.pending,
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
  final UploadStatus uploadStatus;
}

/// 기록 탭 맨 위의 "이번 달 요약"
class MonthSummary {
  const MonthSummary({
    required this.count,
    required this.distanceM,
    required this.elapsed,
  });

  /// [activities] 중 [now]와 같은 달(기기 시간 기준)에 시작한 기록만 더한다.
  factory MonthSummary.of(Iterable<ActivitySummary> activities, DateTime now) {
    final thisMonth = activities.where(
      (a) => a.startedAt.year == now.year && a.startedAt.month == now.month,
    );
    return MonthSummary(
      count: thisMonth.length,
      distanceM: thisMonth.fold(0, (sum, a) => sum + a.distanceM),
      elapsed: thisMonth.fold(Duration.zero, (sum, a) => sum + a.elapsed),
    );
  }

  final int count;
  final double distanceM;
  final Duration elapsed;
}
