import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_setup.dart';
import '../domain/chat.dart';

/// 채팅을 서버와 주고받는 창구. 누가 읽고 보낼 수 있는지는 서버 함수가 검사한다.
abstract interface class ChatRemote {
  /// 내 동호회 채팅방 (처음 열면 서버가 만든다)
  Future<String> clubRoomId(String clubId);

  /// 그 사람과의 1:1 채팅방 (없으면 null)
  Future<String?> findDirectRoom(String nickname, String tag);

  /// 메시지 요청: 1:1 채팅방을 만들고 첫 메시지를 보낸다. 이미 방이 있으면 그 방 id.
  Future<String> startDirectChat(String nickname, String tag, String body);

  Future<List<DirectChatSummary>> fetchDirectChats();
  Future<ChatBadges> fetchBadges();
  Future<ChatRoomInfo> fetchRoom(String roomId);

  /// 최근 메시지부터 [limit]개 (오래된 것부터 정렬해서 돌려준다). [beforeId]가 있으면 그보다 앞의 것.
  Future<List<ChatMessage>> fetchMessages(
    String roomId, {
    int? beforeId,
    int limit = 50,
  });

  Future<void> send(String roomId, String body);
  Future<void> markRead(String roomId);
  Future<void> respondRequest(String roomId, {required bool accept});
  Future<void> block(String roomId);
  Future<void> deleteMessage(int messageId);
  Future<void> hideMessage(int messageId);
  Future<void> report(int messageId, String reason);

  /// 이 방에 새 메시지·상태 변화가 있으면 신호를 보낸다 (내용은 [fetchMessages]로 다시 받는다).
  Stream<void> watch(String roomId);

  /// 내가 읽을 수 있는 모든 방(동호회·1:1)에 새 메시지·요청·상태 변화가 있으면 신호를 보낸다.
  /// 안 읽은 수·메시지 목록을 다시 받는 데 쓴다. 어떤 방이 오는지는 서버 RLS가 정한다.
  Stream<void> watchMine();
}

class SupabaseChatRemote implements ChatRemote {
  SupabaseChatRemote(this._client);

  final SupabaseClient _client;

  Future<List<Map<String, dynamic>>> _rows(
    String fn, [
    Map<String, dynamic>? params,
  ]) async {
    final rows = await _client.rpc<List<dynamic>>(fn, params: params);
    return rows.cast<Map<String, dynamic>>();
  }

  static DateTime? _time(Object? v) =>
      v == null ? null : DateTime.parse(v as String).toLocal();

  @override
  Future<String> clubRoomId(String clubId) async => await _client.rpc<String>(
    'get_club_chat_room',
    params: {'p_club_id': clubId},
  );

  @override
  Future<String?> findDirectRoom(String nickname, String tag) async =>
      await _client.rpc<String?>(
        'find_direct_room',
        params: {'p_nickname': nickname, 'p_tag': tag},
      );

  @override
  Future<String> startDirectChat(
    String nickname,
    String tag,
    String body,
  ) async => await _client.rpc<String>(
    'start_direct_chat',
    params: {'p_nickname': nickname, 'p_tag': tag, 'p_body': body},
  );

  @override
  Future<List<DirectChatSummary>> fetchDirectChats() async => [
    for (final r in await _rows('get_my_direct_chats'))
      DirectChatSummary(
        roomId: r['room_id'] as String,
        status: DirectStatus.parse(r['status'] as String?),
        iAmRequester: r['i_am_requester'] as bool,
        otherNickname: r['other_nickname'] as String,
        otherTag: r['other_tag'] as String,
        otherAvatarUrl: r['other_avatar_url'] as String?,
        lastBody: r['last_body'] as String?,
        lastAt: _time(r['last_at']),
        unread: (r['unread'] as int?) ?? 0,
      ),
  ];

  @override
  Future<ChatBadges> fetchBadges() async {
    final rows = await _rows('get_chat_badges');
    if (rows.isEmpty) return const ChatBadges();
    final r = rows.first;
    return ChatBadges(
      directUnread: (r['direct_unread'] as int?) ?? 0,
      pendingRequests: (r['pending_requests'] as int?) ?? 0,
      clubUnread: (r['club_unread'] as int?) ?? 0,
    );
  }

  @override
  Future<ChatRoomInfo> fetchRoom(String roomId) async {
    final r = (await _rows('get_chat_room', {'p_room_id': roomId})).first;
    return ChatRoomInfo(
      roomId: roomId,
      kind: r['kind'] == 'club' ? ChatKind.club : ChatKind.direct,
      clubId: r['club_id'] as String?,
      title: (r['title'] as String?) ?? '',
      otherNickname: r['other_nickname'] as String?,
      otherTag: r['other_tag'] as String?,
      otherAvatarUrl: r['other_avatar_url'] as String?,
      status: DirectStatus.parse(r['status'] as String?),
      iAmRequester: (r['i_am_requester'] as bool?) ?? false,
      iAmLeader: (r['i_am_leader'] as bool?) ?? false,
      canSend: r['can_send'] as bool,
      myLastReadAt: _time(r['my_last_read_at']),
    );
  }

  @override
  Future<List<ChatMessage>> fetchMessages(
    String roomId, {
    int? beforeId,
    int limit = 50,
  }) async {
    final rows = await _rows('get_chat_messages', {
      'p_room_id': roomId,
      'p_before_id': beforeId,
      'p_limit': limit,
    });
    return [
      for (final r in rows.reversed)
        ChatMessage(
          id: r['id'] as int,
          senderNickname: r['sender_nickname'] as String,
          senderTag: r['sender_tag'] as String,
          senderAvatarUrl: r['sender_avatar_url'] as String?,
          isMine: r['is_mine'] as bool,
          body: r['body'] as String?,
          state: MessageState.parse(r['state'] as String?),
          createdAt: _time(r['created_at'])!,
        ),
    ];
  }

  @override
  Future<void> send(String roomId, String body) => _client.rpc<void>(
    'send_chat_message',
    params: {'p_room_id': roomId, 'p_body': body},
  );

  @override
  Future<void> markRead(String roomId) =>
      _client.rpc<void>('mark_chat_read', params: {'p_room_id': roomId});

  @override
  Future<void> respondRequest(String roomId, {required bool accept}) =>
      _client.rpc<void>(
        'respond_chat_request',
        params: {'p_room_id': roomId, 'p_accept': accept},
      );

  @override
  Future<void> block(String roomId) =>
      _client.rpc<void>('block_direct_chat', params: {'p_room_id': roomId});

  @override
  Future<void> deleteMessage(int messageId) => _client.rpc<void>(
    'delete_chat_message',
    params: {'p_message_id': messageId},
  );

  @override
  Future<void> hideMessage(int messageId) => _client.rpc<void>(
    'hide_chat_message',
    params: {'p_message_id': messageId},
  );

  @override
  Future<void> report(int messageId, String reason) => _client.rpc<void>(
    'report_chat_message',
    params: {'p_message_id': messageId, 'p_reason': reason},
  );

  @override
  Stream<void> watch(String roomId) {
    late final RealtimeChannel channel;
    final controller = StreamController<void>(
      onCancel: () => _client.removeChannel(channel),
    );
    void ping(PostgresChangePayload _) => controller.add(null);
    channel = _client
        .channel('chat-$roomId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'chat_messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'room_id',
            value: roomId,
          ),
          callback: ping,
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'chat_rooms',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: roomId,
          ),
          callback: ping,
        )
        .subscribe();
    return controller.stream;
  }

  @override
  Stream<void> watchMine() {
    late final RealtimeChannel channel;
    final controller = StreamController<void>(
      onCancel: () => _client.removeChannel(channel),
    );
    void ping(PostgresChangePayload _) => controller.add(null);
    channel = _client
        .channel('chat-mine')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'chat_messages',
          callback: ping,
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'chat_rooms',
          callback: ping,
        )
        .subscribe();
    return controller.stream;
  }
}

final chatRemoteProvider = Provider<ChatRemote>((ref) {
  return SupabaseChatRemote(ref.watch(supabaseClientProvider));
});

// 화면에서 쓰는 값. 실패하면 자동으로 다시 시도하지 않고 오류를 보여 준다.
final chatBadgesProvider = FutureProvider.autoDispose<ChatBadges>(
  (ref) => ref.watch(chatRemoteProvider).fetchBadges(),
  retry: (_, _) => null,
);

final directChatsProvider = FutureProvider.autoDispose<List<DirectChatSummary>>(
  (ref) => ref.watch(chatRemoteProvider).fetchDirectChats(),
  retry: (_, _) => null,
);

final chatRoomProvider = FutureProvider.autoDispose
    .family<ChatRoomInfo, String>(
      (ref, roomId) => ref.watch(chatRemoteProvider).fetchRoom(roomId),
      retry: (_, _) => null,
    );

final clubChatRoomIdProvider = FutureProvider.autoDispose
    .family<String, String>(
      (ref, clubId) => ref.watch(chatRemoteProvider).clubRoomId(clubId),
      retry: (_, _) => null,
    );

/// 동호회 상세의 채팅 미리보기 (최근 3개)
final chatPreviewProvider = FutureProvider.autoDispose
    .family<List<ChatMessage>, String>(
      (ref, roomId) =>
          ref.watch(chatRemoteProvider).fetchMessages(roomId, limit: 3),
      retry: (_, _) => null,
    );
