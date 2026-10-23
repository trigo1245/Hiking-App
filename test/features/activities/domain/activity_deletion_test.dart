import 'package:flutter_test/flutter_test.dart';
import 'package:hiking_app/features/activities/domain/activity_deletion.dart';
import 'package:hiking_app/features/activities/domain/activity_summary.dart';

ActivitySummary summary(UploadStatus status) => ActivitySummary(
  id: 'a1',
  title: '10월 20일 등산',
  startedAt: DateTime(2026, 10, 20, 9),
  endedAt: DateTime(2026, 10, 20, 11),
  elapsed: const Duration(hours: 2),
  moving: const Duration(hours: 1, minutes: 40),
  distanceM: 5000,
  elevationGainM: 400,
  maxAltitudeM: 600,
  pointCount: 100,
  isFlagged: false,
  uploadStatus: status,
);

void main() {
  List<String> titles(List<DeletionNotice> n) => [for (final x in n) x.title];

  test('코스와 관계없는 기록: 되돌릴 수 없음, 서버에서도 지움, 통계에서 빠짐', () {
    final n = deletionNotices(
      summary: summary(UploadStatus.done),
      completedCourses: const [],
      attemptedCourses: const [],
    );
    expect(titles(n), ['되돌릴 수 없어요', '서버에서도 지워요', '통계와 분석에서 빠져요']);
  });

  test('아직 올리지 않은 기록이면 이 휴대폰에서만 지워진다고 알린다', () {
    final n = deletionNotices(
      summary: summary(UploadStatus.pending),
      completedCourses: const [],
      attemptedCourses: const [],
    );
    expect(titles(n), contains('아직 서버에 올라가지 않은 기록이에요'));
    expect(titles(n), isNot(contains('서버에서도 지워요')));
  });

  test('40% 미만 진행률은 리뷰 자격 이야기 없이 진행률이 빠진다고만 알린다', () {
    final n = deletionNotices(
      summary: summary(UploadStatus.done),
      completedCourses: const [],
      attemptedCourses: const [('승학산 구덕문화공원 코스', 0.31)],
    );
    final notice = n.firstWhere((x) => x.title.contains('31%'));
    expect(notice.detail, contains('내 최고 진행률'));
    expect(titles(n), isNot(contains('이미 쓴 리뷰는 남아요')));
  });

  test('완주·진행률 기록이 있으면 랭킹·리뷰 자격 변화와 남는 리뷰를 알린다', () {
    final n = deletionNotices(
      summary: summary(UploadStatus.done),
      completedCourses: const ['금정산 범어사 코스'],
      attemptedCourses: const [('금정산 산성마을 코스', 0.62)],
    );
    expect(titles(n), [
      '되돌릴 수 없어요',
      '서버에서도 지워요',
      '금정산 범어사 코스 완주 기록이 사라져요',
      '금정산 산성마을 코스 진행률(62%) 기록이 사라져요',
      '이미 쓴 리뷰는 남아요',
      '통계와 분석에서 빠져요',
    ]);
    expect(n[2].detail, contains('정복자'));
    expect(n[3].detail, contains('리뷰 작성 자격'));
  });
}
