import 'package:flutter_test/flutter_test.dart';
import 'package:hiking_app/features/courses/domain/course.dart';

import '../fake_course_remote.dart';

void main() {
  final courses = [
    testCourse(id: 'a', mountainName: '승학산', name: '동아대 코스'),
    testCourse(id: 'b', mountainName: '금정산', name: '범어사 코스'),
    testCourse(id: 'c', mountainName: '금정산', name: '산성마을 코스'),
  ];

  test('산 이름으로 찾는다', () {
    expect(searchCourses(courses, '금정').map((c) => c.id), ['b', 'c']);
  });

  test('코스 이름으로 찾고, 띄어쓰기는 무시한다', () {
    expect(searchCourses(courses, '범 어사').map((c) => c.id), ['b']);
    expect(searchCourses(courses, '금정산범어사').map((c) => c.id), ['b']);
  });

  test('들머리 이름으로도 찾는다', () {
    expect(searchCourses(courses, '승학캠퍼스'), hasLength(3));
  });

  test('빈 검색어면 결과가 없다', () {
    expect(searchCourses(courses, '  '), isEmpty);
  });

  test('경로의 첫 점이 들머리다', () {
    final c = testCourse();
    expect(c.start.lat, c.path.first.lat);
    expect(c.fullName, '승학산 동아대 코스');
  });
}
