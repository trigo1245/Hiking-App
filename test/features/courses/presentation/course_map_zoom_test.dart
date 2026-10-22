import 'package:flutter_test/flutter_test.dart';
import 'package:hiking_app/features/courses/presentation/course_map.dart';

void main() {
  test('부산 전체가 보일 만큼 멀면 코스 표시를 숨긴다', () {
    expect(showCourseMarkersAt(10.5), isFalse);
    expect(showCourseMarkersAt(12.4), isFalse);
  });

  test('산 몇 개가 보이는 정도에서는 코스 표시를 보여 준다', () {
    expect(showCourseMarkersAt(12.5), isTrue);
    expect(showCourseMarkersAt(14), isTrue);
    expect(showCourseMarkersAt(15), isTrue);
  });

  test('한 코스를 크게 볼 만큼 가까우면 다시 숨긴다', () {
    expect(showCourseMarkersAt(15.1), isFalse);
    expect(showCourseMarkersAt(17), isFalse);
  });
}
