import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/design.dart';
import '../../../core/widgets/confirm_sheet.dart';
import '../../../core/widgets/nickname_text.dart';
import '../../../core/widgets/pressable.dart';
import '../../../core/widgets/skeleton_box.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../auth/presentation/public_profile_sheet.dart';
import '../../clubs/data/club_remote.dart';
import '../data/chat_remote.dart';
import '../domain/chat.dart';

/// 아직 대화방이 없는 사람에게 처음 보낼 때 (공개 프로필의 "메시지 보내기")
class ChatTarget {
  const ChatTarget({required this.nickname, required this.tag, this.avatarUrl});

  final String nickname;
  final String tag;
  final String? avatarUrl;
}

String _time(DateTime t) {
  final l = t.toLocal();
  final period = l.hour < 12 ? '오전' : '오후';
  final hour = l.hour % 12 == 0 ? 12 : l.hour % 12;
  return '$period $hour:${l.minute.toString().padLeft(2, '0')}';
}

String _day(DateTime t) {
  final l = t.toLocal();
  const days = ['월', '화', '수', '목', '금', '토', '일'];
  return '${l.month}월 ${l.day}일 ${days[l.weekday - 1]}요일';
}

/// 채팅방 (동호회 채팅·1:1 채팅 공통).
/// 새 메시지는 Realtime 신호를 받으면 다시 받아 온다. 열려 있는 동안 읽음으로 표시한다.
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key, this.roomId, this.target})
    : assert(roomId != null || target != null);

  final String? roomId;
  final ChatTarget? target;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _input = TextEditingController();
  String? _roomId;
  var _messages = <ChatMessage>[];
  bool _loading = true;
  bool _hasMore = false;
  bool _sending = false;
  bool _failed = false;
  DateTime? _readMark;
  bool _readMarkSet = false;
  StreamSubscription<void>? _watch;

  ChatRemote get _remote => ref.read(chatRemoteProvider);

  @override
  void initState() {
    super.initState();
    _roomId = widget.roomId;
    _input.addListener(() => setState(() {}));
    _start();
  }

  @override
  void dispose() {
    _watch?.cancel();
    _input.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    try {
      if (_roomId == null) {
        final t = widget.target!;
        _roomId = await _remote.findDirectRoom(t.nickname, t.tag);
      }
      if (_roomId != null) {
        await _reload(first: true);
        _listen();
      }
    } catch (e) {
      debugPrint('[chat] $e');
      _failed = true;
    }
    if (mounted) setState(() => _loading = false);
  }

  void _listen() {
    _watch?.cancel();
    _watch = _remote.watch(_roomId!).listen((_) => _reload());
  }

  /// 최근 메시지를 다시 받아 이미 가진 앞쪽 메시지와 합친다.
  Future<void> _reload({bool first = false}) async {
    final id = _roomId;
    if (id == null) return;
    final latest = await _remote.fetchMessages(id);
    if (!mounted) return;
    final oldest = latest.isEmpty ? null : latest.first.id;
    setState(() {
      _messages = [
        for (final m in _messages)
          if (oldest != null && m.id < oldest) m,
        ...latest,
      ];
      if (first) _hasMore = latest.length >= 50;
    });
    ref.invalidate(chatRoomProvider(id));
    unawaited(
      _remote.markRead(id).then((_) {
        if (mounted) {
          ref
            ..invalidate(chatBadgesProvider)
            ..invalidate(directChatsProvider);
        }
      }, onError: (Object _) {}),
    );
  }

  Future<void> _loadOlder() async {
    final id = _roomId;
    if (id == null || _messages.isEmpty) return;
    final older = await _remote.fetchMessages(id, beforeId: _messages.first.id);
    if (!mounted) return;
    setState(() {
      _messages = [...older, ..._messages];
      _hasMore = older.length >= 50;
    });
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      if (_roomId == null) {
        final t = widget.target!;
        _roomId = await _remote.startDirectChat(t.nickname, t.tag, text);
        _listen();
      } else {
        await _remote.send(_roomId!, text);
      }
      _input.clear();
      await _reload(first: _messages.isEmpty);
    } catch (e) {
      debugPrint('[chat] $e');
      _snack(clubErrorMessage(e));
    }
    if (mounted) setState(() => _sending = false);
  }

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _run(Future<void> Function() action, String done) async {
    try {
      await action();
      _snack(done);
      await _reload();
    } catch (e) {
      debugPrint('[chat] $e');
      _snack(clubErrorMessage(e));
    }
  }

  Future<void> _respond(bool accept) => _run(
    () => _remote.respondRequest(_roomId!, accept: accept),
    accept ? '요청을 수락했어요. 이제 대화할 수 있어요' : '요청을 거절했어요',
  );

  Future<void> _block() async {
    final ok = await showConfirmSheet(
      context,
      title: '이 대화를 차단할까요?',
      message: '차단하면 서로 더 메시지를 보낼 수 없어요. 지난 대화는 남아요.',
      confirmLabel: '차단하기',
      cancelLabel: '취소',
    );
    if (ok != true) return;
    await _run(() => _remote.block(_roomId!), '대화를 차단했어요');
  }

  Future<void> _actions(ChatMessage m, ChatRoomInfo? room) async {
    if (m.state != MessageState.normal) return;
    final canHide =
        !m.isMine && room?.kind == ChatKind.club && (room?.iAmLeader ?? false);
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.background,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (m.isMine)
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded),
                title: const Text('지우기'),
                onTap: () => Navigator.of(context).pop('delete'),
              ),
            if (canHide)
              ListTile(
                leading: const Icon(Icons.visibility_off_outlined),
                title: const Text('가리기 (클럽장)'),
                onTap: () => Navigator.of(context).pop('hide'),
              ),
            if (!m.isMine)
              ListTile(
                leading: const Icon(Icons.flag_outlined),
                title: const Text('신고하기'),
                onTap: () => Navigator.of(context).pop('report'),
              ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    switch (choice) {
      case 'delete':
        await _run(() => _remote.deleteMessage(m.id), '메시지를 지웠어요');
      case 'hide':
        await _run(() => _remote.hideMessage(m.id), '메시지를 가렸어요');
      case 'report':
        final reason = await _pickReason();
        if (reason != null) {
          await _run(() => _remote.report(m.id, reason), '신고했어요. 확인 후 조치할게요');
        }
    }
  }

  Future<String?> _pickReason() => showModalBottomSheet<String>(
    context: context,
    backgroundColor: AppColors.background,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final r in const ['스팸·광고', '욕설·비방', '불쾌한 내용', '기타'])
            ListTile(title: Text(r), onTap: () => Navigator.of(context).pop(r)),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final id = _roomId;
    final room = id == null ? null : ref.watch(chatRoomProvider(id)).value;
    if (room != null && !_readMarkSet) {
      _readMarkSet = true;
      _readMark = room.myLastReadAt;
    }
    final target = widget.target;
    final nickname = room?.otherNickname ?? target?.nickname;
    final tag = room?.otherTag ?? target?.tag;
    final isDirect = room?.isDirect ?? target != null;
    final canSend = id == null ? target != null : (room?.canSend ?? false);

    return Scaffold(
      appBar: AppBar(
        title: isDirect && nickname != null
            ? Pressable(
                onPressed: () => showPublicProfile(
                  context,
                  nickname: nickname,
                  tag: tag ?? '',
                  avatarUrl: room?.otherAvatarUrl ?? target?.avatarUrl,
                ),
                child: NicknameText(
                  nickname: nickname,
                  tag: tag,
                  style: AppTypography.subtitle,
                ),
              )
            : Text(room?.title ?? '채팅'),
        actions: [
          if (isDirect && id != null && room != null && !room.status.closed)
            PopupMenuButton<String>(
              tooltip: '대화 관리',
              onSelected: (_) => _block(),
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'block', child: Text('차단하기')),
              ],
            ),
        ],
      ),
      body: Column(
        children: [
          _Banner(
            room: room,
            isNew: id == null && !_loading,
            nickname: nickname,
            onRespond: _respond,
          ),
          Expanded(child: _messagesView(room)),
          _InputBar(
            controller: _input,
            enabled: canSend && !_sending,
            sending: _sending,
            hint: canSend
                ? (id == null ? '첫 메시지를 보내 보세요' : '메시지를 입력해 주세요')
                : room?.isIncomingRequest ?? false
                ? '수락하면 대화를 시작할 수 있어요'
                : room?.isOutgoingRequest ?? false
                ? '상대가 수락하면 이어서 보낼 수 있어요'
                : '이 대화에는 보낼 수 없어요',
            onSend: _send,
          ),
        ],
      ),
    );
  }

  Widget _messagesView(ChatRoomInfo? room) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(AppSpacing.screenHorizontal),
        child: SkeletonBox(width: double.infinity, height: 160),
      );
    }
    if (_failed) {
      return Center(
        child: TextButton(
          onPressed: () {
            setState(() {
              _failed = false;
              _loading = true;
            });
            _start();
          },
          child: const Text('대화를 불러오지 못했어요. 다시 시도'),
        ),
      );
    }
    final items = buildChatItems(_messages, lastReadAt: _readMark);
    // 아래(최근)부터 그리도록 뒤집는다. 키보드가 올라와도 마지막 메시지가 보인다.
    final reversed = items.reversed.toList();
    return ListView.builder(
      reverse: true,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screenHorizontal,
        vertical: AppSpacing.md,
      ),
      itemCount: reversed.length + (_hasMore ? 1 : 0),
      itemBuilder: (context, i) {
        if (i == reversed.length) {
          return Center(
            child: TextButton(
              onPressed: _loadOlder,
              child: const Text('이전 메시지 더 보기'),
            ),
          );
        }
        return switch (reversed[i]) {
          ChatDateDivider(:final date) => _Divider(text: _day(date)),
          ChatUnreadDivider() => const _Divider(
            text: '여기까지 읽었어요',
            highlight: true,
          ),
          ChatBubble(:final message, :final showSender, :final showTime) =>
            _Bubble(
              message: message,
              showSender: showSender,
              showTime: showTime,
              onLongPress: () => _actions(message, room),
            ),
        };
      },
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({
    required this.room,
    required this.isNew,
    required this.nickname,
    required this.onRespond,
  });

  final ChatRoomInfo? room;
  final bool isNew;
  final String? nickname;
  final ValueChanged<bool> onRespond;

  @override
  Widget build(BuildContext context) {
    final r = room;
    final name = nickname ?? '상대';
    final String? text;
    var incoming = false;
    if (isNew) {
      text = '첫 메시지를 보내면 $name님에게 메시지 요청이 가요. 상대가 수락하면 대화를 이어 갈 수 있어요';
    } else if (r == null || !r.isDirect) {
      text = null;
    } else if (r.isIncomingRequest) {
      incoming = true;
      text = '$name님이 메시지를 보냈어요. 수락하면 대화할 수 있어요. 거절하면 이 사람은 더 보낼 수 없어요';
    } else if (r.isOutgoingRequest) {
      text = '메시지 요청을 보냈어요. 상대가 수락하면 대화를 이어 갈 수 있어요';
    } else if (r.status == DirectStatus.declined) {
      text = r.iAmRequester ? '상대가 메시지를 받지 않아요' : '거절한 대화예요';
    } else if (r.status == DirectStatus.blocked) {
      text = '차단된 대화예요. 더 보낼 수 없어요';
    } else {
      text = null;
    }
    if (text == null) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.screenHorizontal,
        AppSpacing.sm,
        AppSpacing.screenHorizontal,
        0,
      ),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.backgroundGrouped,
        borderRadius: BorderRadius.circular(AppRadius.input),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            text,
            style: AppTypography.caption.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          if (incoming) ...[
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => onRespond(false),
                    child: const Text('거절'),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: FilledButton(
                    onPressed: () => onRespond(true),
                    child: const Text('수락'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider({required this.text, this.highlight = false});

  final String text;
  final bool highlight;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
    child: Row(
      children: [
        const Expanded(child: Divider(color: AppColors.divider)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          child: Text(
            text,
            style: AppTypography.caption.copyWith(
              color: highlight ? AppColors.primary : AppColors.textTertiary,
            ),
          ),
        ),
        const Expanded(child: Divider(color: AppColors.divider)),
      ],
    ),
  );
}

class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.message,
    required this.showSender,
    required this.showTime,
    required this.onLongPress,
  });

  final ChatMessage message;
  final bool showSender;
  final bool showTime;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final mine = message.isMine;
    final faded = message.state != MessageState.normal;
    final bubble = GestureDetector(
      onLongPress: onLongPress,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.68,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: faded
              ? AppColors.background
              : mine
              ? AppColors.primary
              : AppColors.backgroundGrouped,
          border: faded ? Border.all(color: AppColors.divider) : null,
          borderRadius: BorderRadius.circular(AppRadius.button),
        ),
        child: Text(
          message.displayText,
          style: AppTypography.body.copyWith(
            color: faded
                ? AppColors.textTertiary
                : mine
                ? AppColors.onPrimary
                : AppColors.textPrimary,
          ),
        ),
      ),
    );
    final time = showTime
        ? Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
            child: Text(
              _time(message.createdAt),
              style: AppTypography.caption.copyWith(
                fontSize: 11,
                color: AppColors.textTertiary,
              ),
            ),
          )
        : const SizedBox.shrink();

    if (mine) {
      return Padding(
        padding: const EdgeInsets.only(top: AppSpacing.xs),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [time, bubble],
        ),
      );
    }
    return Padding(
      padding: EdgeInsets.only(top: showSender ? AppSpacing.md : AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 36,
            child: showSender
                ? UserAvatar(
                    nickname: message.senderNickname,
                    imageUrl: message.senderAvatarUrl,
                    size: 32,
                  )
                : null,
          ),
          const SizedBox(width: AppSpacing.xs),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (showSender)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: NicknameText(
                      nickname: message.senderNickname,
                      tag: message.senderTag,
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(child: bubble),
                    time,
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InputBar extends StatelessWidget {
  const _InputBar({
    required this.controller,
    required this.enabled,
    required this.sending,
    required this.hint,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool enabled;
  final bool sending;
  final String hint;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final canSend = enabled && controller.text.trim().isNotEmpty;
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.sm,
          AppSpacing.sm,
        ),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.divider)),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                enabled: enabled || sending,
                minLines: 1,
                maxLines: 4,
                maxLength: chatMessageMaxLength,
                style: AppTypography.body,
                decoration: InputDecoration(hintText: hint, counterText: ''),
              ),
            ),
            IconButton(
              onPressed: canSend ? onSend : null,
              tooltip: '보내기',
              icon: sending
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      Icons.send_rounded,
                      color: canSend
                          ? AppColors.primary
                          : AppColors.textTertiary,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
