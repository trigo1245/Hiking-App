/// 리뷰 평가 항목 (기획서 3.2, 실제 소요시간은 완주 기록 평균으로 따로 보여 준다)
enum ReviewAspect {
  difficulty('난이도', '쉬워요', '어려워요'),
  risk('경사·위험', '안전해요', '위험해요'),
  view('조망', '아쉬워요', '최고예요'),
  crowd('혼잡도', '한산해요', '붐벼요');

  const ReviewAspect(this.label, this.lowLabel, this.highLabel);

  final String label;

  /// 1점의 뜻
  final String lowLabel;

  /// 5점의 뜻
  final String highLabel;
}

/// 리뷰 한 개 (다른 사용자에게 보이는 정보만)
class CourseReview {
  const CourseReview({
    required this.nickname,
    required this.nicknameTag,
    required this.scores,
    required this.updatedAt,
    required this.isMine,
    this.avatarUrl,
    this.comment,
  });

  final String nickname;
  final String nicknameTag;
  final String? avatarUrl;

  /// 항목별 1~5점
  final Map<ReviewAspect, int> scores;
  final String? comment;
  final DateTime updatedAt;
  final bool isMine;

  String get displayName => '$nickname#$nicknameTag';
}

/// 코스의 항목별 평균
class ReviewSummary {
  const ReviewSummary({required this.count, this.averages = const {}});

  final int count;
  final Map<ReviewAspect, double> averages;
}

/// 한 줄 후기 최대 길이 (CLAUDE.md 6-2장)
const reviewCommentMaxLength = 200;
