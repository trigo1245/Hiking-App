import 'package:flutter/foundation.dart';
import 'package:hiking_app/features/clubs/data/club_remote.dart';
import 'package:hiking_app/features/clubs/domain/club.dart';
import 'package:hiking_app/features/courses/domain/competition.dart';

/// 서버 대신 동호회를 기억하는 가짜. 나는 등산객AB12#0369.
class FakeClubRemote implements ClubRemote {
  final _clubs = <String, _Club>{};
  String? myClubId;
  String? pendingClubId;
  int photoUploads = 0;
  var _next = 0;
  var _nextId = 0;

  static const _me = ClubMember(
    userId: 'u1',
    nickname: '등산객AB12',
    nicknameTag: '0369',
    isLeader: false,
    isMe: true,
    seasonCompletions: 3,
  );

  /// 시연용 클럽 하나를 넣는다. [mine]이면 내가 회원(또는 [leader]면 클럽장).
  String addClub(
    String name, {
    int others = 4,
    int completions = 10,
    String? region,
    String? bio,
    bool mine = false,
    bool leader = false,
    List<ClubJoinRequest> requests = const [],
  }) {
    final id = 'c${++_next}';
    _clubs[id] = _Club(
      id: id,
      name: name,
      region: region,
      bio: bio,
      completions: completions,
      leaderIsMe: leader,
      members: [
        if (mine || leader) _me,
        for (var i = 1; i <= others; i++)
          ClubMember(
            userId: 'o$i',
            nickname: '회원$i',
            nicknameTag: '000$i',
            isLeader: !leader && i == 1,
            isMe: false,
            seasonCompletions: i,
          ),
      ],
      requests: [...requests],
    );
    if (mine || leader) myClubId = id;
    return id;
  }

  ClubStatus _statusOf(String id) {
    final c = _clubs[id]!;
    if (myClubId == id) {
      return c.leaderIsMe ? ClubStatus.leader : ClubStatus.member;
    }
    if (pendingClubId == id) return ClubStatus.pending;
    if (myClubId != null) return ClubStatus.otherClub;
    return ClubStatus.none;
  }

  List<ClubMember> _membersOf(_Club c) => [
    for (final m in c.members)
      ClubMember(
        userId: m.userId,
        nickname: m.nickname,
        nicknameTag: m.nicknameTag,
        isLeader: m.isMe ? c.leaderIsMe : (!c.leaderIsMe && m.isLeader),
        isMe: m.isMe,
        seasonCompletions: m.seasonCompletions,
      ),
  ];

  ClubDetail _detail(_Club c) {
    final leader = _membersOf(c).firstWhere((m) => m.isLeader);
    return ClubDetail(
      id: c.id,
      name: c.name,
      bio: c.bio,
      region: c.region,
      memberCount: c.members.length,
      seasonCompletions: c.completions,
      leaderNickname: leader.nickname,
      leaderTag: leader.nicknameTag,
      status: _statusOf(c.id),
      pendingRequests: c.leaderIsMe && myClubId == c.id ? c.requests.length : 0,
    );
  }

  _Club _club(String id) => _clubs[id] ?? (throw StateError('없는 동호회'));

  @override
  Future<List<ClubSummary>> listClubs({String? query}) async => [
    for (final c in _clubs.values)
      if (query == null ||
          c.name.contains(query) ||
          (c.region ?? '').contains(query))
        _detail(c),
  ];

  @override
  Future<ClubDetail?> fetchClub(String clubId) async {
    final c = _clubs[clubId];
    return c == null ? null : _detail(c);
  }

  @override
  Future<MyClubStatus> fetchMyStatus() async => MyClubStatus(
    clubId: myClubId,
    pendingClubId: pendingClubId,
    pendingClubName: pendingClubId == null ? null : _clubs[pendingClubId]!.name,
  );

  @override
  Future<String> createClub({
    required String name,
    String? bio,
    String? region,
  }) async {
    if (_clubs.values.any((c) => c.name == name)) {
      throw StateError('이미 있는 동호회 이름이에요');
    }
    final id = addClub(
      name,
      others: 0,
      completions: 0,
      bio: bio,
      region: region,
      mine: true,
      leader: true,
    );
    pendingClubId = null;
    return id;
  }

  @override
  Future<void> updateClub(
    String clubId, {
    required String name,
    String? bio,
    String? region,
  }) async {
    final c = _club(clubId);
    c
      ..name = name
      ..bio = bio
      ..region = region;
  }

  @override
  Future<void> setClubPhoto(String clubId, Uint8List jpeg) async =>
      photoUploads++;

  @override
  Future<void> disbandClub(String clubId) async {
    _clubs.remove(clubId);
    if (myClubId == clubId) myClubId = null;
  }

  @override
  Future<void> transferLeader(String clubId, String userId) async {
    final c = _club(clubId);
    c.leaderIsMe = false;
    c.members = [
      for (final m in c.members)
        ClubMember(
          userId: m.userId,
          nickname: m.nickname,
          nicknameTag: m.nicknameTag,
          isLeader: m.userId == userId,
          isMe: m.isMe,
          seasonCompletions: m.seasonCompletions,
        ),
    ];
  }

  @override
  Future<void> requestJoin(String clubId) async => pendingClubId = clubId;

  @override
  Future<void> cancelJoinRequest() async => pendingClubId = null;

  @override
  Future<List<ClubJoinRequest>> fetchJoinRequests(String clubId) async => [
    ..._club(clubId).requests,
  ];

  @override
  Future<void> decideJoinRequest(int requestId, {required bool approve}) async {
    for (final c in _clubs.values) {
      final r = c.requests.where((r) => r.id == requestId).firstOrNull;
      if (r == null) continue;
      c.requests.remove(r);
      if (approve) {
        c.members.add(
          ClubMember(
            userId: 'r$requestId',
            nickname: r.nickname,
            nicknameTag: r.nicknameTag,
            isLeader: false,
            isMe: false,
            seasonCompletions: 0,
          ),
        );
      }
    }
  }

  @override
  Future<void> leaveClub() async {
    final id = myClubId;
    if (id == null) return;
    _club(id).members.removeWhere((m) => m.isMe);
    myClubId = null;
  }

  @override
  Future<List<ClubMember>> fetchMembers(String clubId) async =>
      _membersOf(_club(clubId));

  @override
  Future<List<ClubNotice>> fetchNotices(String clubId) async => [
    ..._club(clubId).notices,
  ];

  @override
  Future<void> postNotice(String clubId, String body) async =>
      _club(clubId).notices.insert(
        0,
        ClubNotice(
          id: ++_nextId,
          body: body,
          authorNickname: '등산객AB12',
          authorTag: '0369',
          createdAt: DateTime(2026, 11, 1),
        ),
      );

  @override
  Future<void> deleteNotice(int noticeId) async {
    for (final c in _clubs.values) {
      c.notices.removeWhere((n) => n.id == noticeId);
    }
  }

  @override
  Future<List<ClubEvent>> fetchEvents(String clubId) async => [
    ..._club(clubId).events,
  ];

  @override
  Future<void> createEvent(
    String clubId, {
    required String title,
    required DateTime startsAt,
    String? place,
    String? memo,
  }) async => _club(clubId).events.add(
    ClubEvent(
      id: ++_nextId,
      title: title,
      startsAt: startsAt,
      place: place,
      memo: memo,
      going: 0,
      notGoing: 0,
    ),
  );

  /// 시험용: 일정을 바로 넣는다.
  void addEvent(String clubId, ClubEvent event) =>
      _club(clubId).events.add(event);

  @override
  Future<void> deleteEvent(int eventId) async {
    for (final c in _clubs.values) {
      c.events.removeWhere((e) => e.id == eventId);
    }
  }

  @override
  Future<void> vote(int eventId, EventAnswer? answer) async {
    for (final c in _clubs.values) {
      for (var i = 0; i < c.events.length; i++) {
        final e = c.events[i];
        if (e.id != eventId) continue;
        int going = e.going, notGoing = e.notGoing;
        if (e.myAnswer == EventAnswer.going) going--;
        if (e.myAnswer == EventAnswer.notGoing) notGoing--;
        if (answer == EventAnswer.going) going++;
        if (answer == EventAnswer.notGoing) notGoing++;
        c.events[i] = ClubEvent(
          id: e.id,
          title: e.title,
          startsAt: e.startsAt,
          place: e.place,
          memo: e.memo,
          going: going,
          notGoing: notGoing,
          myAnswer: answer,
        );
      }
    }
  }

  @override
  Future<List<EventVote>> fetchEventVotes(int eventId) async {
    for (final c in _clubs.values) {
      final e = c.events.where((e) => e.id == eventId).firstOrNull;
      if (e?.myAnswer case final answer?) {
        return [
          EventVote(nickname: '등산객AB12', nicknameTag: '0369', answer: answer),
        ];
      }
    }
    return const [];
  }

  @override
  Future<List<ClubRankingEntry>> fetchRanking(Season season) async {
    final sorted = [..._clubs.values]
      ..sort((a, b) => b.completions.compareTo(a.completions));
    return [
      for (var i = 0; i < sorted.length; i++)
        ClubRankingEntry(
          rank: i + 1,
          clubId: sorted[i].id,
          name: sorted[i].name,
          memberCount: sorted[i].members.length,
          completions: sorted[i].completions,
          activeMembers: sorted[i].members.length,
          isMine: sorted[i].id == myClubId,
        ),
    ];
  }
}

class _Club {
  _Club({
    required this.id,
    required this.name,
    required this.completions,
    required this.leaderIsMe,
    required this.members,
    required this.requests,
    this.region,
    this.bio,
  });

  final String id;
  String name;
  String? region;
  String? bio;
  final int completions;
  bool leaderIsMe;
  List<ClubMember> members;
  final List<ClubJoinRequest> requests;
  final notices = <ClubNotice>[];
  final events = <ClubEvent>[];
}
