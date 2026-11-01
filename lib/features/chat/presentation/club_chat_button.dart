import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/design/design.dart';
import '../../../core/utils/error_message.dart';
import '../data/chat_remote.dart';
import 'chat_bubble_icon.dart';

/// 동호회 채팅방 버튼 (상단 제목 줄 오른쪽, 회원에게만 둔다). 안 읽은 메시지 수를 빨간 표시로 보여 준다.
/// 채팅방 id는 누를 때 받는다 (처음 열면 서버가 방을 만든다).
class ClubChatButton extends ConsumerStatefulWidget {
  const ClubChatButton({super.key, required this.clubId});

  final String clubId;

  @override
  ConsumerState<ClubChatButton> createState() => _ClubChatButtonState();
}

class _ClubChatButtonState extends ConsumerState<ClubChatButton> {
  bool _opening = false;

  Future<void> _open() async {
    if (_opening) return;
    setState(() => _opening = true);
    try {
      final roomId = await ref.read(
        clubChatRoomIdProvider(widget.clubId).future,
      );
      if (!mounted) return;
      await context.push(AppRoutes.chat(roomId));
    } catch (e) {
      debugPrint('[chat] $e');
      ref.invalidate(clubChatRoomIdProvider(widget.clubId));
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(content: Text(errorMessage(e, failed: '채팅방을 열지 못했어요'))),
          );
      }
    } finally {
      if (mounted) setState(() => _opening = false);
      ref.invalidate(chatBadgesProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final unread = ref.watch(chatBadgesProvider).value?.clubUnread ?? 0;
    return IconButton(
      tooltip: unread > 0 ? '동호회 채팅 · 새 메시지 $unread' : '동호회 채팅',
      onPressed: _open,
      icon: Badge(
        isLabelVisible: unread > 0,
        backgroundColor: AppColors.danger,
        label: Text(unread > 99 ? '99+' : '$unread'),
        child: const ChatBubbleIcon(),
      ),
    );
  }
}
