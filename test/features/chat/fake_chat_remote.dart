import 'dart:async';

import 'package:hiking_app/features/chat/data/chat_remote.dart';
import 'package:hiking_app/features/chat/domain/chat.dart';

/// 서버 대신 채팅을 기억하는 가짜. 나는 등산객AB12#0369.
class FakeChatRemote implements ChatRemote {
  final rooms = <String, ChatRoomInfo>{};
  final messages = <String, List<ChatMessage>>{};
  final reports = <int>[];
  final _watchers = <String, StreamController<void>>{};
  var _nextId = 0;
  var _nextRoom = 0;

  ChatMessage _msg(
    String nickname,
    String tag,
    String body, {
    bool mine = false,
  }) => ChatMessage(
    id: ++_nextId,
    senderNickname: nickname,
    senderTag: tag,
    isMine: mine,
    body: body,
    createdAt: DateTime(2026, 11, 1, 9).add(Duration(minutes: _nextId)),
  );

  /// 시험용 방을 넣는다.
  String addRoom(
    ChatRoomInfo Function(String id) build, {
    List<(String, String, String, bool)> lines = const [],
  }) {
    final id = 'r${++_nextRoom}';
    rooms[id] = build(id);
    messages[id] = [
      for (final (n, t, b, mine) in lines) _msg(n, t, b, mine: mine),
    ];
    return id;
  }

  /// 다른 사람이 보낸 것처럼 메시지를 넣고 Realtime 신호를 보낸다.
  void receive(String roomId, String nickname, String tag, String body) {
    messages[roomId]!.add(_msg(nickname, tag, body));
    _watchers[roomId]?.add(null);
    _mine.add(null);
  }

  ChatRoomInfo _with(ChatRoomInfo r, {DirectStatus? status}) => ChatRoomInfo(
    roomId: r.roomId,
    kind: r.kind,
    clubId: r.clubId,
    title: r.title,
    otherNickname: r.otherNickname,
    otherTag: r.otherTag,
    status: status ?? r.status,
    iAmRequester: r.iAmRequester,
    iAmLeader: r.iAmLeader,
    canSend:
        r.kind == ChatKind.club ||
        (status ?? r.status) == DirectStatus.accepted,
    myLastReadAt: r.myLastReadAt,
  );

  @override
  Future<String> clubRoomId(String clubId) async =>
      rooms.values.firstWhere((r) => r.clubId == clubId).roomId;

  @override
  Future<String?> findDirectRoom(String nickname, String tag) async => rooms
      .values
      .where((r) => r.otherNickname == nickname && r.otherTag == tag)
      .firstOrNull
      ?.roomId;

  @override
  Future<String> startDirectChat(
    String nickname,
    String tag,
    String body,
  ) async {
    final existing = await findDirectRoom(nickname, tag);
    if (existing != null) return existing;
    return addRoom(
      (id) => ChatRoomInfo(
        roomId: id,
        kind: ChatKind.direct,
        title: nickname,
        otherNickname: nickname,
        otherTag: tag,
        status: DirectStatus.pending,
        iAmRequester: true,
        iAmLeader: false,
        canSend: false,
      ),
      lines: [('등산객AB12', '0369', body, true)],
    );
  }

  @override
  Future<List<DirectChatSummary>> fetchDirectChats() async => [
    for (final r in rooms.values)
      if (r.isDirect)
        DirectChatSummary(
          roomId: r.roomId,
          status: r.status,
          iAmRequester: r.iAmRequester,
          otherNickname: r.otherNickname!,
          otherTag: r.otherTag!,
          lastBody: messages[r.roomId]!.lastOrNull?.displayText,
          lastAt: messages[r.roomId]!.lastOrNull?.createdAt,
          unread: 0,
        ),
  ];

  @override
  Future<ChatBadges> fetchBadges() async => ChatBadges(
    pendingRequests: rooms.values.where((r) => r.isIncomingRequest).length,
  );

  @override
  Future<ChatRoomInfo> fetchRoom(String roomId) async => rooms[roomId]!;

  @override
  Future<List<ChatMessage>> fetchMessages(
    String roomId, {
    int? beforeId,
    int limit = 50,
  }) async {
    final all = [
      for (final m in messages[roomId]!)
        if (beforeId == null || m.id < beforeId) m,
    ];
    return all.length <= limit ? all : all.sublist(all.length - limit);
  }

  @override
  Future<void> send(String roomId, String body) async {
    if (!rooms[roomId]!.canSend) throw StateError('보낼 수 없어요');
    messages[roomId]!.add(_msg('등산객AB12', '0369', body, mine: true));
  }

  @override
  Future<void> markRead(String roomId) async {}

  @override
  Future<void> respondRequest(String roomId, {required bool accept}) async =>
      rooms[roomId] = _with(
        rooms[roomId]!,
        status: accept ? DirectStatus.accepted : DirectStatus.declined,
      );

  @override
  Future<void> block(String roomId) async =>
      rooms[roomId] = _with(rooms[roomId]!, status: DirectStatus.blocked);

  @override
  Future<void> deleteMessage(int messageId) async {
    for (final list in messages.values) {
      for (var i = 0; i < list.length; i++) {
        final m = list[i];
        if (m.id != messageId) continue;
        list[i] = ChatMessage(
          id: m.id,
          senderNickname: m.senderNickname,
          senderTag: m.senderTag,
          isMine: m.isMine,
          createdAt: m.createdAt,
          state: MessageState.deleted,
        );
      }
    }
  }

  @override
  Future<void> hideMessage(int messageId) async {}

  @override
  Future<void> report(int messageId, String reason) async =>
      reports.add(messageId);

  @override
  Stream<void> watch(String roomId) =>
      (_watchers[roomId] ??= StreamController<void>.broadcast()).stream;

  final _mine = StreamController<void>.broadcast();

  @override
  Stream<void> watchMine() => _mine.stream;

  /// 다른 사람이 새 메시지 요청을 보낸 것처럼 방을 넣고 신호를 보낸다.
  String receiveRequest(String nickname, String tag, String body) {
    final id = addRoom(
      (id) => ChatRoomInfo(
        roomId: id,
        kind: ChatKind.direct,
        title: nickname,
        otherNickname: nickname,
        otherTag: tag,
        status: DirectStatus.pending,
        iAmRequester: false,
        iAmLeader: false,
        canSend: false,
      ),
      lines: [(nickname, tag, body, false)],
    );
    _mine.add(null);
    return id;
  }
}
