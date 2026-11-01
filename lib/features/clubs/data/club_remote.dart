import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../core/supabase/supabase_setup.dart';
import '../../courses/domain/competition.dart';
import '../domain/club.dart';

/// 동호회 대표 사진을 담는 공개 버킷. 경로: {user_id}/{club_id}/{사진 id}.jpg
const clubPhotoBucket = 'club-photos';

/// 동호회를 서버와 주고받는 창구. 권한(클럽장·회원)은 서버 함수가 검사한다.
abstract interface class ClubRemote {
  Future<List<ClubSummary>> listClubs({String? query});
  Future<ClubDetail?> fetchClub(String clubId);
  Future<MyClubStatus> fetchMyStatus();

  /// 시연용 개설비를 낸 것으로 하고 클럽을 만든다. 새 클럽 id.
  Future<String> createClub({
    required String name,
    String? bio,
    String? region,
  });
  Future<void> updateClub(
    String clubId, {
    required String name,
    String? bio,
    String? region,
  });
  Future<void> setClubPhoto(String clubId, Uint8List jpeg);
  Future<void> disbandClub(String clubId);
  Future<void> transferLeader(String clubId, String userId);

  Future<void> requestJoin(String clubId);
  Future<void> cancelJoinRequest();
  Future<List<ClubJoinRequest>> fetchJoinRequests(String clubId);
  Future<void> decideJoinRequest(int requestId, {required bool approve});
  Future<void> leaveClub();

  Future<List<ClubMember>> fetchMembers(String clubId);
  Future<List<ClubNotice>> fetchNotices(String clubId);
  Future<void> postNotice(String clubId, String body);
  Future<void> deleteNotice(int noticeId);

  Future<List<ClubEvent>> fetchEvents(String clubId);
  Future<void> createEvent(
    String clubId, {
    required String title,
    required DateTime startsAt,
    String? place,
    String? memo,
  });
  Future<void> deleteEvent(int eventId);

  /// [answer]가 null이면 내 답을 지운다.
  Future<void> vote(int eventId, EventAnswer? answer);
  Future<List<EventVote>> fetchEventVotes(int eventId);

  Future<List<ClubRankingEntry>> fetchRanking(Season season);
}

/// 서버가 거절한 이유(한국어 문구)가 있으면 그대로, 아니면 연결 안내.
String clubErrorMessage(Object error) {
  if (error is PostgrestException && RegExp(r'[가-힣]').hasMatch(error.message)) {
    return error.message;
  }
  return '처리하지 못했어요. 인터넷 연결을 확인해 주세요';
}

class SupabaseClubRemote implements ClubRemote {
  SupabaseClubRemote(this._client);

  final SupabaseClient _client;

  Future<List<Map<String, dynamic>>> _rows(
    String fn, [
    Map<String, dynamic>? params,
  ]) async {
    final rows = await _client.rpc<List<dynamic>>(fn, params: params);
    return rows.cast<Map<String, dynamic>>();
  }

  static DateTime _time(Object? v) => DateTime.parse(v as String).toLocal();

  @override
  Future<List<ClubSummary>> listClubs({String? query}) async => [
    for (final r in await _rows('list_clubs', {'p_query': query}))
      ClubSummary(
        id: r['id'] as String,
        name: r['name'] as String,
        bio: r['bio'] as String?,
        region: r['region'] as String?,
        photoUrl: r['photo_url'] as String?,
        memberCount: r['member_count'] as int,
        maxMembers: r['max_members'] as int,
        seasonCompletions: r['season_completions'] as int,
      ),
  ];

  @override
  Future<ClubDetail?> fetchClub(String clubId) async {
    final rows = await _rows('get_club', {'p_club_id': clubId});
    if (rows.isEmpty) return null;
    final r = rows.first;
    return ClubDetail(
      id: r['id'] as String,
      name: r['name'] as String,
      bio: r['bio'] as String?,
      region: r['region'] as String?,
      photoUrl: r['photo_url'] as String?,
      memberCount: r['member_count'] as int,
      maxMembers: r['max_members'] as int,
      seasonCompletions: r['season_completions'] as int,
      leaderNickname: r['leader_nickname'] as String,
      leaderTag: r['leader_tag'] as String,
      status: ClubStatus.parse(r['my_status'] as String?),
      pendingRequests: (r['pending_requests'] as int?) ?? 0,
    );
  }

  @override
  Future<MyClubStatus> fetchMyStatus() async {
    final rows = await _rows('get_my_club_status');
    if (rows.isEmpty) return const MyClubStatus();
    final r = rows.first;
    return MyClubStatus(
      clubId: r['club_id'] as String?,
      pendingClubId: r['pending_club_id'] as String?,
      pendingClubName: r['pending_club_name'] as String?,
    );
  }

  @override
  Future<String> createClub({
    required String name,
    String? bio,
    String? region,
  }) async => await _client.rpc<String>(
    'create_club',
    params: {'p_name': name, 'p_bio': bio, 'p_region': region},
  );

  @override
  Future<void> updateClub(
    String clubId, {
    required String name,
    String? bio,
    String? region,
  }) => _client.rpc<void>(
    'update_club',
    params: {
      'p_club_id': clubId,
      'p_name': name,
      'p_bio': bio,
      'p_region': region,
    },
  );

  @override
  Future<void> setClubPhoto(String clubId, Uint8List jpeg) async {
    final userId = _client.auth.currentUser!.id;
    final path = '$userId/$clubId/${const Uuid().v4()}.jpg';
    final bucket = _client.storage.from(clubPhotoBucket);
    await bucket.uploadBinary(
      path,
      jpeg,
      fileOptions: const FileOptions(contentType: 'image/jpeg'),
    );
    final String? old;
    try {
      old = await _client.rpc<String?>(
        'set_club_photo',
        params: {
          'p_club_id': clubId,
          'p_path': path,
          'p_url': bucket.getPublicUrl(path),
        },
      );
    } catch (_) {
      await bucket.remove([path]);
      rethrow;
    }
    await _removePhoto(old);
  }

  Future<void> _removePhoto(String? path) async {
    if (path == null) return;
    try {
      // 다른 사람(이전 클럽장)이 올린 사진은 권한이 없어 지워지지 않는다. 문제는 없다.
      await _client.storage.from(clubPhotoBucket).remove([path]);
    } catch (e) {
      debugPrint('[club] 이전 사진을 지우지 못했어요: $e');
    }
  }

  @override
  Future<void> disbandClub(String clubId) async {
    final photo = await _client.rpc<String?>(
      'disband_club',
      params: {'p_club_id': clubId},
    );
    await _removePhoto(photo);
  }

  @override
  Future<void> transferLeader(String clubId, String userId) =>
      _client.rpc<void>(
        'transfer_club_leader',
        params: {'p_club_id': clubId, 'p_user_id': userId},
      );

  @override
  Future<void> requestJoin(String clubId) =>
      _client.rpc<void>('request_club_join', params: {'p_club_id': clubId});

  @override
  Future<void> cancelJoinRequest() =>
      _client.rpc<void>('cancel_club_join_request');

  @override
  Future<List<ClubJoinRequest>> fetchJoinRequests(String clubId) async => [
    for (final r in await _rows('get_club_join_requests', {
      'p_club_id': clubId,
    }))
      ClubJoinRequest(
        id: r['request_id'] as int,
        nickname: r['nickname'] as String,
        nicknameTag: r['nickname_tag'] as String,
        avatarUrl: r['avatar_url'] as String?,
        region: r['region'] as String?,
        requestedAt: _time(r['requested_at']),
      ),
  ];

  @override
  Future<void> decideJoinRequest(int requestId, {required bool approve}) =>
      _client.rpc<void>(
        'decide_club_join_request',
        params: {'p_request_id': requestId, 'p_approve': approve},
      );

  @override
  Future<void> leaveClub() => _client.rpc<void>('leave_club');

  @override
  Future<List<ClubMember>> fetchMembers(String clubId) async => [
    for (final r in await _rows('get_club_members', {'p_club_id': clubId}))
      ClubMember(
        userId: r['user_id'] as String,
        nickname: r['nickname'] as String,
        nicknameTag: r['nickname_tag'] as String,
        avatarUrl: r['avatar_url'] as String?,
        isLeader: r['is_leader'] as bool,
        isMe: r['is_me'] as bool,
        seasonCompletions: r['season_completions'] as int,
      ),
  ];

  @override
  Future<List<ClubNotice>> fetchNotices(String clubId) async => [
    for (final r in await _rows('get_club_notices', {'p_club_id': clubId}))
      ClubNotice(
        id: r['id'] as int,
        body: r['body'] as String,
        authorNickname: r['author_nickname'] as String,
        authorTag: r['author_tag'] as String,
        createdAt: _time(r['created_at']),
      ),
  ];

  @override
  Future<void> postNotice(String clubId, String body) => _client.rpc<void>(
    'post_club_notice',
    params: {'p_club_id': clubId, 'p_body': body},
  );

  @override
  Future<void> deleteNotice(int noticeId) => _client.rpc<void>(
    'delete_club_notice',
    params: {'p_notice_id': noticeId},
  );

  @override
  Future<List<ClubEvent>> fetchEvents(String clubId) async => [
    for (final r in await _rows('get_club_events', {'p_club_id': clubId}))
      ClubEvent(
        id: r['id'] as int,
        title: r['title'] as String,
        startsAt: _time(r['starts_at']),
        place: r['place'] as String?,
        memo: r['memo'] as String?,
        going: r['going'] as int,
        notGoing: r['not_going'] as int,
        myAnswer: EventAnswer.parse(r['my_answer'] as String?),
      ),
  ];

  @override
  Future<void> createEvent(
    String clubId, {
    required String title,
    required DateTime startsAt,
    String? place,
    String? memo,
  }) => _client.rpc<void>(
    'create_club_event',
    params: {
      'p_club_id': clubId,
      'p_title': title,
      'p_starts_at': startsAt.toUtc().toIso8601String(),
      'p_place': place,
      'p_memo': memo,
    },
  );

  @override
  Future<void> deleteEvent(int eventId) =>
      _client.rpc<void>('delete_club_event', params: {'p_event_id': eventId});

  @override
  Future<void> vote(int eventId, EventAnswer? answer) => _client.rpc<void>(
    'vote_club_event',
    params: {'p_event_id': eventId, 'p_answer': answer?.serverName},
  );

  @override
  Future<List<EventVote>> fetchEventVotes(int eventId) async => [
    for (final r in await _rows('get_club_event_votes', {
      'p_event_id': eventId,
    }))
      EventVote(
        nickname: r['nickname'] as String,
        nicknameTag: r['nickname_tag'] as String,
        avatarUrl: r['avatar_url'] as String?,
        answer: EventAnswer.parse(r['answer'] as String?)!,
      ),
  ];

  @override
  Future<List<ClubRankingEntry>> fetchRanking(Season season) async => [
    for (final r in await _rows('get_club_ranking', {'p_season': season.id}))
      ClubRankingEntry(
        rank: r['rank_no'] as int,
        clubId: r['club_id'] as String,
        name: r['name'] as String,
        photoUrl: r['photo_url'] as String?,
        region: r['region'] as String?,
        memberCount: r['member_count'] as int,
        completions: r['completions'] as int,
        activeMembers: r['active_members'] as int,
        isMine: r['is_mine'] as bool,
      ),
  ];
}

final clubRemoteProvider = Provider<ClubRemote>((ref) {
  return SupabaseClubRemote(ref.watch(supabaseClientProvider));
});

// 화면에서 쓰는 값. 실패하면 자동으로 다시 시도하지 않고 오류를 보여 준다.
final myClubStatusProvider = FutureProvider.autoDispose<MyClubStatus>(
  (ref) => ref.watch(clubRemoteProvider).fetchMyStatus(),
  retry: (_, _) => null,
);

final clubListProvider = FutureProvider.autoDispose
    .family<List<ClubSummary>, String>(
      (ref, query) => ref
          .watch(clubRemoteProvider)
          .listClubs(query: query.isEmpty ? null : query),
      retry: (_, _) => null,
    );

final clubDetailProvider = FutureProvider.autoDispose
    .family<ClubDetail?, String>(
      (ref, id) => ref.watch(clubRemoteProvider).fetchClub(id),
      retry: (_, _) => null,
    );

final clubMembersProvider = FutureProvider.autoDispose
    .family<List<ClubMember>, String>(
      (ref, id) => ref.watch(clubRemoteProvider).fetchMembers(id),
      retry: (_, _) => null,
    );

final clubNoticesProvider = FutureProvider.autoDispose
    .family<List<ClubNotice>, String>(
      (ref, id) => ref.watch(clubRemoteProvider).fetchNotices(id),
      retry: (_, _) => null,
    );

final clubEventsProvider = FutureProvider.autoDispose
    .family<List<ClubEvent>, String>(
      (ref, id) => ref.watch(clubRemoteProvider).fetchEvents(id),
      retry: (_, _) => null,
    );

final clubJoinRequestsProvider = FutureProvider.autoDispose
    .family<List<ClubJoinRequest>, String>(
      (ref, id) => ref.watch(clubRemoteProvider).fetchJoinRequests(id),
      retry: (_, _) => null,
    );

final eventVotesProvider = FutureProvider.autoDispose
    .family<List<EventVote>, int>(
      (ref, id) => ref.watch(clubRemoteProvider).fetchEventVotes(id),
      retry: (_, _) => null,
    );

/// 시즌 id(예: 2026-H2) → 클럽 랭킹
final clubRankingProvider = FutureProvider.autoDispose
    .family<List<ClubRankingEntry>, String>(
      (ref, seasonId) =>
          ref.watch(clubRemoteProvider).fetchRanking(Season.parse(seasonId)),
      retry: (_, _) => null,
    );
