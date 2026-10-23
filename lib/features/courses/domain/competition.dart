/// 정복 랭킹의 두 기준 (기획서 4.2)
enum RankingKind {
  /// 완주 횟수가 가장 많은 사람
  most,

  /// 등정 시간(들머리 → 정상)이 가장 짧은 사람
  fastest,
}

/// 시즌: 상반기(1~6월) / 하반기(7~12월), 한국 시간 기준 (CLAUDE.md 6-2장)
class Season {
  const Season(this.year, this.half);

  factory Season.of(DateTime time) {
    final kst = time.toUtc().add(const Duration(hours: 9));
    return Season(kst.year, kst.month <= 6 ? 1 : 2);
  }

  final int year;

  /// 1 = 상반기, 2 = 하반기
  final int half;

  /// 서버에 저장하는 형태. 예: 2026-H2
  String get id => '$year-H$half';

  /// 화면 표시. 예: 2026 하반기
  String get label => '$year ${half == 1 ? '상반기' : '하반기'}';
}

/// 랭킹 한 줄 (다른 사용자에게 공개되는 정보만: 순위, 닉네임, 프로필, 기록)
class RankingEntry {
  const RankingEntry({
    required this.rank,
    required this.nickname,
    required this.nicknameTag,
    required this.value,
    required this.isMe,
    this.avatarUrl,
  });

  final int rank;
  final String nickname;
  final String nicknameTag;
  final String? avatarUrl;

  /// 최다완등이면 완주 횟수, 최단시간이면 등정 시간(초)
  final int value;
  final bool isMe;

  /// 표시용 이름. 예: 등산왕#0421
  String get displayName => '$nickname#$nicknameTag';
}

/// 코스 상세 화면 위쪽 요약
class CourseStats {
  const CourseStats({
    required this.completionCount,
    this.averageAscent,
    this.myBestAscent,
    this.myCount = 0,
  });

  /// 지금까지 이 코스를 완주한 기록 수
  final int completionCount;

  /// 완주 기록 평균 등정 시간
  final Duration? averageAscent;
  final Duration? myBestAscent;
  final int myCount;
}

/// 지도에 표시하는 코스별 정복자 (이번 시즌)
class Conqueror {
  const Conqueror({
    required this.courseId,
    required this.kind,
    required this.nickname,
    required this.nicknameTag,
    required this.value,
    this.avatarUrl,
  });

  final String courseId;
  final RankingKind kind;
  final String nickname;
  final String nicknameTag;
  final String? avatarUrl;
  final int value;
}

/// 서버에 기록된 내 코스 완주 한 건 (랭킹과 같은 기준, 시연용 완주 포함)
class MyCompletion {
  const MyCompletion({
    required this.courseId,
    required this.ascent,
    required this.completedAt,
  });

  final String courseId;

  /// 들머리 → 정상 시간
  final Duration ascent;
  final DateTime completedAt;
}

/// 랭킹 한 묶음: 받은 줄들과 전체 인원 (나눠 받을 때 끝을 알기 위해)
class RankingPage {
  const RankingPage({required this.entries, required this.total});

  final List<RankingEntry> entries;

  /// 조건(시즌·검색어)에 맞는 전체 인원. 코스 상세에서는 순위에 오른 전체 인원.
  final int total;
}
