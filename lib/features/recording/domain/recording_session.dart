import 'track_point.dart';

enum RecordingStatus { recording, paused, finished }

/// 진행 중인 기록의 시간 정보. 일시정지 시간을 빼고 "기록 시간"을 계산한다.
class RecordingSession {
  const RecordingSession({
    required this.activityId,
    required this.status,
    required this.startedAt,
    required this.segment,
    this.pausedTotal = Duration.zero,
    this.pausedAt,
  });

  final String activityId;
  final RecordingStatus status;
  final DateTime startedAt;
  final int segment;
  final Duration pausedTotal;
  final DateTime? pausedAt;

  /// 화면에 보여 줄 기록 시간: 시작부터 지금까지에서 일시정지한 시간을 뺀다.
  Duration activeDuration(DateTime now) {
    final end = pausedAt ?? now;
    final value = end.difference(startedAt) - pausedTotal;
    return value.isNegative ? Duration.zero : value;
  }
}

/// 앱을 다시 켰을 때 발견한 끝나지 않은 기록.
class UnfinishedRecording {
  const UnfinishedRecording({required this.session, required this.points});

  final RecordingSession session;
  final List<TrackPoint> points;
}

/// 기록 완료 화면의 기본 제목. 예: "10월 13일 등산"
String defaultActivityTitle(DateTime startedAt) =>
    '${startedAt.month}월 ${startedAt.day}일 등산';
