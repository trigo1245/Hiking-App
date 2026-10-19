import 'package:flutter_test/flutter_test.dart';
import 'package:hiking_app/features/activities/domain/activity_summary.dart';

ActivitySummary _activity(DateTime startedAt, double km, int minutes) =>
    ActivitySummary(
      id: '$startedAt',
      title: 't',
      startedAt: startedAt,
      endedAt: startedAt.add(Duration(minutes: minutes)),
      elapsed: Duration(minutes: minutes),
      moving: Duration(minutes: minutes),
      distanceM: km * 1000,
      elevationGainM: 0,
      maxAltitudeM: null,
      pointCount: 0,
      isFlagged: false,
    );

void main() {
  test('이번 달에 시작한 기록만 더한다', () {
    final now = DateTime(2026, 10, 20);
    final summary = MonthSummary.of([
      _activity(DateTime(2026, 10, 1, 9), 5, 120),
      _activity(DateTime(2026, 10, 19, 8), 3.5, 90),
      _activity(DateTime(2026, 9, 30, 23), 10, 300), // 지난달
      _activity(DateTime(2025, 10, 5), 7, 200), // 작년 같은 달
    ], now);

    expect(summary.count, 2);
    expect(summary.distanceM, 8500);
    expect(summary.elapsed, const Duration(minutes: 210));
  });

  test('기록이 없으면 0', () {
    final summary = MonthSummary.of(const [], DateTime(2026, 10, 20));
    expect(summary.count, 0);
    expect(summary.distanceM, 0);
    expect(summary.elapsed, Duration.zero);
  });
}
