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
    this.completionCount = 0,
    this.bestProgress,
  });

  final String nickname;
  final String nicknameTag;
  final String? avatarUrl;

  /// 항목별 1~5점. 조망은 정상까지 간 사람만 매기므로 없을 수 있다.
  final Map<ReviewAspect, int> scores;
  final String? comment;
  final DateTime updatedAt;
  final bool isMine;

  /// 작성자가 이 코스를 완등한 횟수
  final int completionCount;

  /// 작성자가 이 코스를 가장 멀리 간 비율 (완등이 없을 때 보여 준다)
  final double? bestProgress;

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

/// 리뷰를 쓸 수 있는 최소 진행률 (코스의 40% 이상 다녀왔어야 한다)
const reviewMinProgress = 0.4;

/// 리뷰 쓰기 자격
enum ReviewAccess {
  /// 완등했다: 모든 항목을 매길 수 있다.
  completed,

  /// 40% 이상 다녀왔다: 조망을 뺀 항목을 매길 수 있다.
  partial,

  /// 아직 쓸 수 없다.
  none;

  static ReviewAccess of({required int completions, double? bestProgress}) {
    if (completions > 0) return ReviewAccess.completed;
    if ((bestProgress ?? 0) >= reviewMinProgress) return ReviewAccess.partial;
    return ReviewAccess.none;
  }

  /// 이 자격으로 매기는 항목 (조망은 완등한 사람만)
  List<ReviewAspect> get aspects => switch (this) {
    ReviewAccess.completed => ReviewAspect.values,
    ReviewAccess.partial => [
      for (final a in ReviewAspect.values)
        if (a != ReviewAspect.view) a,
    ],
    ReviewAccess.none => const [],
  };
}

/// 리뷰 목록 정렬
enum ReviewSort {
  recent('최신순'),

  /// 그 코스를 많이 완등한 사람의 리뷰가 먼저
  completions('완등 많은 순');

  const ReviewSort(this.label);

  final String label;
}

/// 리뷰 한 묶음과 전체 개수
class ReviewPage {
  const ReviewPage({required this.reviews, required this.total});

  final List<CourseReview> reviews;
  final int total;
}

/// 내가 쓴 리뷰 (고치기 화면에 채워 넣는다)
class MyReview {
  const MyReview({required this.scores, this.comment});

  final Map<ReviewAspect, int> scores;
  final String? comment;
}
