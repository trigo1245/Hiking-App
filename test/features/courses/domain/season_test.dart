import 'package:flutter_test/flutter_test.dart';
import 'package:hiking_app/features/courses/domain/competition.dart';

void main() {
  test('1~6월은 상반기, 7~12월은 하반기', () {
    expect(Season.of(DateTime.utc(2026, 3, 1)).id, '2026-H1');
    expect(Season.of(DateTime.utc(2026, 10, 20)).id, '2026-H2');
    expect(Season.of(DateTime.utc(2026, 10, 20)).label, '2026 하반기');
  });

  test('경계는 한국 시간 기준이다', () {
    // UTC 6월 30일 15:00 = 한국 7월 1일 0시 → 하반기
    expect(Season.of(DateTime.utc(2026, 6, 30, 15)).id, '2026-H2');
    expect(Season.of(DateTime.utc(2026, 6, 30, 14, 59)).id, '2026-H1');
    // UTC 12월 31일 15:00 = 한국 다음 해 1월 1일 → 다음 해 상반기
    expect(Season.of(DateTime.utc(2026, 12, 31, 15)).id, '2027-H1');
  });
}
