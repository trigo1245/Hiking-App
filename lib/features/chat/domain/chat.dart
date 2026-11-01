/// 채팅 모델과 화면 배치 계산 (순수 Dart). CLAUDE.md 6-2장 "채팅"
library;

/// 메시지 최대 길이
const chatMessageMaxLength = 500;

/// 같은 사람이 이 시간 안에 이어 보낸 메시지는 이름·시각을 한 번만 보여 준다.
const chatGroupGap = Duration(minutes: 5);

enum ChatKind { club, direct }

/// 1:1 채팅 상태
enum DirectStatus {
  /// 메시지 요청 (받은 사람이 수락하기 전)
  pending,
  accepted,

  /// 받은 사람이 거절했다
  declined,

  /// 대화 중 한쪽이 차단했다
  blocked;

  static DirectStatus parse(String? v) => switch (v) {
    'pending' => pending,
    'declined' => declined,
    'blocked' => blocked,
    _ => accepted,
  };

  bool get closed => this == declined || this == blocked;
}

enum MessageState {
  normal,

  /// 보낸 사람이 지웠다
  deleted,

  /// 클럽장이 가렸다
  hidden;

  static MessageState parse(String? v) => switch (v) {
    'deleted' => deleted,
    'hidden' => hidden,
    _ => normal,
  };
}

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.senderNickname,
    required this.senderTag,
    required this.isMine,
    required this.createdAt,
    this.senderAvatarUrl,
    this.body,
    this.state = MessageState.normal,
  });

  final int id;
  final String senderNickname;
  final String senderTag;
  final String? senderAvatarUrl;
  final bool isMine;

  /// 지웠거나 가린 메시지는 null
  final String? body;
  final MessageState state;
  final DateTime createdAt;

  /// 말풍선에 보여 줄 글
  String get displayText => switch (state) {
    MessageState.deleted => '삭제된 메시지예요',
    MessageState.hidden => '클럽장이 가린 메시지예요',
    MessageState.normal => body ?? '',
  };
}

/// 채팅방 정보와 나의 관계
class ChatRoomInfo {
  const ChatRoomInfo({
    required this.roomId,
    required this.kind,
    required this.title,
    required this.status,
    required this.iAmRequester,
    required this.iAmLeader,
    required this.canSend,
    this.clubId,
    this.otherNickname,
    this.otherTag,
    this.otherAvatarUrl,
    this.myLastReadAt,
  });

  final String roomId;
  final ChatKind kind;
  final String? clubId;

  /// 동호회 이름 또는 상대 닉네임
  final String title;
  final String? otherNickname;
  final String? otherTag;
  final String? otherAvatarUrl;
  final DirectStatus status;
  final bool iAmRequester;

  /// 동호회 채팅에서 내가 클럽장이면 다른 회원의 메시지를 가릴 수 있다.
  final bool iAmLeader;
  final bool canSend;
  final DateTime? myLastReadAt;

  bool get isDirect => kind == ChatKind.direct;

  /// 내가 받은 메시지 요청 (수락·거절을 기다린다)
  bool get isIncomingRequest =>
      isDirect && status == DirectStatus.pending && !iAmRequester;

  /// 내가 보낸 메시지 요청 (상대의 답을 기다린다)
  bool get isOutgoingRequest =>
      isDirect && status == DirectStatus.pending && iAmRequester;
}

/// 1:1 대화 목록 한 줄
class DirectChatSummary {
  const DirectChatSummary({
    required this.roomId,
    required this.status,
    required this.iAmRequester,
    required this.otherNickname,
    required this.otherTag,
    required this.unread,
    this.otherAvatarUrl,
    this.lastBody,
    this.lastAt,
  });

  final String roomId;
  final DirectStatus status;
  final bool iAmRequester;
  final String otherNickname;
  final String otherTag;
  final String? otherAvatarUrl;
  final String? lastBody;
  final DateTime? lastAt;
  final int unread;

  bool get isIncomingRequest => status == DirectStatus.pending && !iAmRequester;
}

/// 배지: 1:1 안 읽은 수, 받은 요청 수, 내 동호회 채팅 안 읽은 수
class ChatBadges {
  const ChatBadges({
    this.directUnread = 0,
    this.pendingRequests = 0,
    this.clubUnread = 0,
  });

  final int directUnread;
  final int pendingRequests;
  final int clubUnread;
}

/// 채팅 화면에 차례로 그리는 것
sealed class ChatItem {
  const ChatItem();
}

/// 날짜가 바뀌는 곳. 예: 11월 1일 토요일
class ChatDateDivider extends ChatItem {
  const ChatDateDivider(this.date);
  final DateTime date;
}

/// "여기까지 읽었어요" 표시 (이 아래가 새 메시지)
class ChatUnreadDivider extends ChatItem {
  const ChatUnreadDivider();
}

class ChatBubble extends ChatItem {
  const ChatBubble(
    this.message, {
    required this.showSender,
    required this.showTime,
  });

  final ChatMessage message;

  /// 다른 사람 메시지 묶음의 첫 메시지면 사진·이름을 보여 준다.
  final bool showSender;

  /// 묶음의 마지막 메시지면 시각을 보여 준다.
  final bool showTime;
}

/// [messages](오래된 것부터)를 날짜 구분선, "여기까지 읽었어요", 말풍선 묶음으로 바꾼다.
/// [lastReadAt] 뒤에 다른 사람이 보낸 첫 메시지 앞에 읽음 표시를 넣는다.
List<ChatItem> buildChatItems(
  List<ChatMessage> messages, {
  DateTime? lastReadAt,
}) {
  bool sameDay(DateTime a, DateTime b) {
    final x = a.toLocal(), y = b.toLocal();
    return x.year == y.year && x.month == y.month && x.day == y.day;
  }

  bool sameGroup(ChatMessage a, ChatMessage b) =>
      a.isMine == b.isMine &&
      a.senderNickname == b.senderNickname &&
      a.senderTag == b.senderTag &&
      sameDay(a.createdAt, b.createdAt) &&
      b.createdAt.difference(a.createdAt) <= chatGroupGap;

  final items = <ChatItem>[];
  var unreadMarked = false;
  for (var i = 0; i < messages.length; i++) {
    final m = messages[i];
    final prev = i > 0 ? messages[i - 1] : null;
    final next = i + 1 < messages.length ? messages[i + 1] : null;

    if (prev == null || !sameDay(prev.createdAt, m.createdAt)) {
      items.add(ChatDateDivider(m.createdAt));
    }
    if (!unreadMarked &&
        lastReadAt != null &&
        !m.isMine &&
        m.createdAt.isAfter(lastReadAt)) {
      items.add(const ChatUnreadDivider());
      unreadMarked = true;
    }
    final startsGroup =
        prev == null || !sameGroup(prev, m) || items.last is! ChatBubble;
    items.add(
      ChatBubble(
        m,
        showSender: !m.isMine && startsGroup,
        showTime: next == null || !sameGroup(m, next),
      ),
    );
  }
  return items;
}
