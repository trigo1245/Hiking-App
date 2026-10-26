import '../../../core/utils/format.dart';

/// 기록 중 상단 고정 알림에 보여 줄 내용. (순수 Dart, 단위 테스트 대상)
///
/// 시간은 안드로이드 알림의 스톱워치 기능으로 흘러가게 한다.
/// [chronometerBase]에서부터 센 시간이 표시되므로, "지금 - 기록한 시간(일시정지 제외)"을 넣는다.
class RecordingNotificationContent {
  const RecordingNotificationContent({
    required this.title,
    required this.body,
    required this.chronometerBase,
  });

  factory RecordingNotificationContent.of({
    required Duration active,
    required DateTime now,
    required double distanceM,
    required double elevationGainM,
    double? altitudeM,
  }) {
    return RecordingNotificationContent(
      title: '등산 기록 중이에요',
      body:
          '${formatKm(distanceM)} km · 현재 ${formatMeters(altitudeM)} m · '
          '오른 높이 ${formatMeters(elevationGainM)} m',
      chronometerBase: now.subtract(active),
    );
  }

  final String title;
  final String body;
  final DateTime chronometerBase;
}
