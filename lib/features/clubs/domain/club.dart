/// 동호회 모델과 규칙 (순수 Dart). CLAUDE.md 6-2장 "동호회"
library;

/// 클럽당 최대 인원
const clubMaxMembers = 50;

/// 동호회 개설비 (시연용, 실제 결제 없음). 개설할 때 한 번만 낸다.
const clubOpeningPriceLabel = '9,900원';

const clubBioMaxLength = 300;
const clubRegionMaxLength = 30;
const clubNoticeMaxLength = 500;
const clubEventTitleMaxLength = 40;
const clubEventPlaceMaxLength = 60;
const clubEventMemoMaxLength = 300;

/// 클럽 이름이 규칙(2~20자)에 맞지 않으면 이유를, 맞으면 null. 겹치는지는 서버가 검사한다.
String? clubNameError(String input) {
  final v = input.trim();
  if (v.length < 2 || v.length > 20) return '동호회 이름은 2~20자로 정해 주세요';
  return null;
}

/// 클럽과 나의 관계
enum ClubStatus {
  leader,
  member,

  /// 이 클럽에 가입 신청을 하고 기다리는 중
  pending,

  /// 다른 클럽에 소속돼 있다 (동시에 가입할 수 없다)
  otherClub,
  none;

  static ClubStatus parse(String? v) => switch (v) {
    'leader' => leader,
    'member' => member,
    'pending' => pending,
    'other_club' => otherClub,
    _ => none,
  };

  bool get isMember => this == leader || this == member;
}

/// 클럽 목록 한 줄 (누구나 본다)
class ClubSummary {
  const ClubSummary({
    required this.id,
    required this.name,
    required this.memberCount,
    required this.seasonCompletions,
    this.bio,
    this.region,
    this.photoUrl,
    this.maxMembers = clubMaxMembers,
  });

  final String id;
  final String name;
  final String? bio;
  final String? region;
  final String? photoUrl;
  final int memberCount;
  final int maxMembers;

  /// 이번 시즌 클럽 완등 횟수
  final int seasonCompletions;

  bool get isFull => memberCount >= maxMembers;
}

/// 클럽 상세 (누구나 본다) + 나와의 관계
class ClubDetail extends ClubSummary {
  const ClubDetail({
    required super.id,
    required super.name,
    required super.memberCount,
    required super.seasonCompletions,
    required this.leaderNickname,
    required this.leaderTag,
    required this.status,
    super.bio,
    super.region,
    super.photoUrl,
    super.maxMembers,
    this.pendingRequests = 0,
  });

  final String leaderNickname;
  final String leaderTag;
  final ClubStatus status;

  /// 기다리는 가입 신청 수 (클럽장에게만 0보다 크다)
  final int pendingRequests;
}

/// 동호회 탭 첫 화면: 내 소속 클럽과 기다리는 가입 신청
class MyClubStatus {
  const MyClubStatus({this.clubId, this.pendingClubId, this.pendingClubName});

  final String? clubId;
  final String? pendingClubId;
  final String? pendingClubName;
}

/// 회원 한 명 (회원끼리만 본다)
class ClubMember {
  const ClubMember({
    required this.userId,
    required this.nickname,
    required this.nicknameTag,
    required this.isLeader,
    required this.isMe,
    required this.seasonCompletions,
    this.avatarUrl,
  });

  final String userId;
  final String nickname;
  final String nicknameTag;
  final String? avatarUrl;
  final bool isLeader;
  final bool isMe;

  /// 가입한 뒤 이번 시즌에 완주한 횟수
  final int seasonCompletions;
}

/// 클럽장이 보는 가입 신청
class ClubJoinRequest {
  const ClubJoinRequest({
    required this.id,
    required this.nickname,
    required this.nicknameTag,
    required this.requestedAt,
    this.avatarUrl,
    this.region,
  });

  final int id;
  final String nickname;
  final String nicknameTag;
  final String? avatarUrl;
  final String? region;
  final DateTime requestedAt;
}

class ClubNotice {
  const ClubNotice({
    required this.id,
    required this.body,
    required this.authorNickname,
    required this.authorTag,
    required this.createdAt,
  });

  final int id;
  final String body;
  final String authorNickname;
  final String authorTag;
  final DateTime createdAt;
}

/// 참석 투표 답
enum EventAnswer {
  going('참석'),
  notGoing('불참');

  const EventAnswer(this.label);
  final String label;

  String get serverName => this == going ? 'going' : 'not_going';

  static EventAnswer? parse(String? v) => switch (v) {
    'going' => going,
    'not_going' => notGoing,
    _ => null,
  };
}

class ClubEvent {
  const ClubEvent({
    required this.id,
    required this.title,
    required this.startsAt,
    required this.going,
    required this.notGoing,
    this.place,
    this.memo,
    this.myAnswer,
  });

  final int id;
  final String title;
  final DateTime startsAt;
  final String? place;
  final String? memo;
  final int going;
  final int notGoing;
  final EventAnswer? myAnswer;

  /// 하루가 지난 일정은 투표를 닫는다.
  bool isPast(DateTime now) =>
      startsAt.isBefore(now.subtract(const Duration(days: 1)));
}

/// 일정 참석·불참 명단 한 줄
class EventVote {
  const EventVote({
    required this.nickname,
    required this.nicknameTag,
    required this.answer,
    this.avatarUrl,
  });

  final String nickname;
  final String nicknameTag;
  final String? avatarUrl;
  final EventAnswer answer;
}

/// 클럽 랭킹 한 줄 (누구나 전체를 본다)
class ClubRankingEntry {
  const ClubRankingEntry({
    required this.rank,
    required this.clubId,
    required this.name,
    required this.memberCount,
    required this.completions,
    required this.activeMembers,
    required this.isMine,
    this.photoUrl,
    this.region,
  });

  final int rank;
  final String clubId;
  final String name;
  final String? photoUrl;
  final String? region;
  final int memberCount;

  /// 시즌 클럽 완등 횟수 (소속 기간 안의 회원 완주 합)
  final int completions;

  /// 이번 시즌에 완주한 회원 수
  final int activeMembers;
  final bool isMine;
}
