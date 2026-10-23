import '../../courses/domain/review.dart';
import 'activity_summary.dart';

/// 기록을 지우기 전에 알려 줄 주의사항 한 가지
class DeletionNotice {
  const DeletionNotice(this.title, this.detail);

  final String title;
  final String detail;
}

/// 이 기록을 지우면 생기는 일을 정리한다. (순수 Dart, 단위 테스트 대상)
/// - [completedCourses]: 이 기록으로 완주한 코스 이름
/// - [attemptedCourses]: 이 기록으로 정상 전까지 다녀온 코스 이름과 진행률
List<DeletionNotice> deletionNotices({
  required ActivitySummary summary,
  required List<String> completedCourses,
  required List<(String, double)> attemptedCourses,
}) {
  final onServer = summary.uploadStatus != UploadStatus.pending;
  return [
    const DeletionNotice(
      '되돌릴 수 없어요',
      '지운 기록은 다시 살릴 수 없어요. 경로(GPX)와 수치가 모두 사라져요.',
    ),
    if (onServer)
      const DeletionNotice(
        '서버에서도 지워요',
        '다른 휴대폰에서 로그인해도 다시 받아지지 않아요. '
            '다만 다른 휴대폰에 이미 받아 둔 기록은 그 휴대폰에 남아요.',
      )
    else
      const DeletionNotice('아직 서버에 올라가지 않은 기록이에요', '이 휴대폰에서만 지워져요.'),
    if (completedCourses.isNotEmpty)
      DeletionNotice(
        '${completedCourses.join(', ')} 완주 기록이 사라져요',
        '랭킹 순위·완등 횟수·정복자가 바뀔 수 있어요. '
            '이미 끝난 시즌의 순위와 명예의 전당에서도 빠져요.',
      ),
    for (final (name, progress) in attemptedCourses)
      DeletionNotice(
        '$name 진행률(${(progress * 100).round()}%) 기록이 사라져요',
        // 40% 이상이어야 리뷰 자격이 생기므로, 그 미만이면 자격 이야기는 하지 않는다.
        progress >= reviewMinProgress
            ? '이 기록으로 얻은 리뷰 작성 자격이 없어질 수 있어요.'
            : '코스 상세의 "내 최고 진행률"에서 빠질 수 있어요.',
      ),
    if (completedCourses.isNotEmpty ||
        attemptedCourses.any((a) => a.$2 >= reviewMinProgress))
      const DeletionNotice(
        '이미 쓴 리뷰는 남아요',
        '리뷰도 지우려면 코스 상세에서 "내 리뷰 고치기"로 들어가 지워 주세요.',
      ),
    const DeletionNotice(
      '통계와 분석에서 빠져요',
      '등산 횟수·누적 거리·체력 추이·맞춤 예상 시간 계산에서 이 기록이 빠져요.',
    ),
  ];
}
