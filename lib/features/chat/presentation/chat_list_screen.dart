import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/design/design.dart';
import '../../../core/utils/error_message.dart';
import '../../../core/widgets/empty_view.dart';
import '../../../core/widgets/nickname_text.dart';
import '../../../core/widgets/pressable.dart';
import '../../../core/widgets/skeleton_box.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../clubs/presentation/club_format.dart';
import '../data/chat_remote.dart';
import '../domain/chat.dart';

/// 1:1 메시지 목록 (내 정보에서 진입): 받은 메시지 요청 + 대화
class ChatListScreen extends ConsumerWidget {
  const ChatListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chats = ref.watch(directChatsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('메시지')),
      body: switch (chats) {
        AsyncValue(:final value?) when value.isEmpty => const EmptyView(
          message: '아직 대화가 없어요.\n랭킹이나 리뷰에서 닉네임을 누르면 메시지를 보낼 수 있어요',
        ),
        AsyncValue(:final value?) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(directChatsProvider),
          child: ListView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.screenHorizontal,
            ),
            children: [
              if (value.any((c) => c.isIncomingRequest)) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  '메시지 요청 ${value.where((c) => c.isIncomingRequest).length}',
                  style: AppTypography.subtitle,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '수락하면 대화할 수 있어요. 거절하면 이 사람은 더 보낼 수 없어요',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                for (final c in value.where((c) => c.isIncomingRequest))
                  _ChatRow(chat: c),
                const SizedBox(height: AppSpacing.lg),
                const Text('대화', style: AppTypography.subtitle),
              ],
              for (final c in value.where((c) => !c.isIncomingRequest))
                _ChatRow(chat: c),
            ],
          ),
        ),
        AsyncValue(:final error?) => Center(
          child: TextButton(
            onPressed: () => ref.invalidate(directChatsProvider),
            child: Text(
              '${errorMessage(error, failed: '메시지를 불러오지 못했어요')}\n눌러서 다시 시도',
              textAlign: TextAlign.center,
            ),
          ),
        ),
        _ => const Padding(
          padding: EdgeInsets.all(AppSpacing.screenHorizontal),
          child: SkeletonBox(width: double.infinity, height: 160),
        ),
      },
    );
  }
}

class _ChatRow extends ConsumerWidget {
  const _ChatRow({required this.chat});

  final DirectChatSummary chat;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = switch (chat.status) {
      DirectStatus.pending when chat.iAmRequester => '요청 보냄 · ',
      DirectStatus.declined => '거절됨 · ',
      DirectStatus.blocked => '차단됨 · ',
      _ => '',
    };
    return Pressable(
      onPressed: () async {
        await context.push(AppRoutes.chat(chat.roomId));
        ref
          ..invalidate(directChatsProvider)
          ..invalidate(chatBadgesProvider);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Row(
          children: [
            UserAvatar(
              nickname: chat.otherNickname,
              imageUrl: chat.otherAvatarUrl,
              size: 48,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  NicknameText(
                    nickname: chat.otherNickname,
                    tag: chat.otherTag,
                    style: AppTypography.body.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '$status${chat.lastBody ?? ''}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (chat.lastAt case final at?)
                  Text(
                    formatShortDate(at),
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textTertiary,
                    ),
                  ),
                if (chat.unread > 0)
                  Container(
                    margin: const EdgeInsets.only(top: AppSpacing.xs),
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    decoration: BoxDecoration(
                      color: AppColors.danger,
                      borderRadius: BorderRadius.circular(AppRadius.button),
                    ),
                    child: Text(
                      '${chat.unread}',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.onPrimary,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
