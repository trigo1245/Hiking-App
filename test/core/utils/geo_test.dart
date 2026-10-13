import 'package:flutter_test/flutter_test.dart';
import 'package:hiking_app/core/utils/geo.dart';

void main() {
  test('같은 점 사이 거리는 0', () {
    expect(haversineMeters(37.5, 127.0, 37.5, 127.0), 0);
  });

  test('위도 1도는 약 111.2km', () {
    expect(haversineMeters(37.0, 127.0, 38.0, 127.0), closeTo(111195, 10));
  });

  test('서울시청-부산시청 직선거리는 약 325km', () {
    final d = haversineMeters(37.5663, 126.9779, 35.1798, 129.0750);
    expect(d / 1000, closeTo(325, 2));
  });
}
