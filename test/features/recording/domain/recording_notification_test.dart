import 'package:flutter_test/flutter_test.dart';
import 'package:hiking_app/features/recording/domain/recording_notification.dart';

void main() {
  test('거리·현재 고도·오른 높이를 한 줄로 보여 주고, 시계는 일시정지를 뺀 시간만큼 앞에서 시작한다', () {
    final now = DateTime(2026, 10, 27, 10);
    final content = RecordingNotificationContent.of(
      active: const Duration(hours: 1, minutes: 2),
      now: now,
      distanceM: 3456,
      elevationGainM: 412.4,
      altitudeM: 633.6,
    );
    expect(content.title, '등산 기록 중이에요');
    expect(content.body, '3.46 km · 현재 634 m · 오른 높이 412 m');
    expect(content.chronometerBase, DateTime(2026, 10, 27, 8, 58));
  });

  test('아직 고도를 모르면 "-"로 보여 준다', () {
    final content = RecordingNotificationContent.of(
      active: Duration.zero,
      now: DateTime(2026, 10, 27),
      distanceM: 0,
      elevationGainM: 0,
    );
    expect(content.body, '0.00 km · 현재 - m · 오른 높이 0 m');
  });
}
