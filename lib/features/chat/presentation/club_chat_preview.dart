import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/design/design.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/skeleton_box.dart';
import '../data/chat_remote.dart';

/// 동호회 상세의 "채팅" 칸: 최근 메시지 3개와 채팅방 열기 (회원만 보인다)
class ClubChatPreview extends ConsumerWidget {
  const ClubChatPreview({super.key, required this.clubId});

  final String clubId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roomId = ref.watch(clubChatRoomIdProvider(clubId));
    final unread = ref.watch(chatBadgesProvider).value?.clubUnread ?? 0;
    return switch (roomId) {
      AsyncValue(:final value?) => _Preview(roomId: value, unread: unread),
      AsyncValue(:final error?) => Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
        child: Center(
          child: TextButton(
            onPressed: () => ref.invalidate(clubChatRoomIdProvider(clubId)),
            child: Text(
              error.toString().contains('42501')
                  ? '회원만 채팅할 수 있어요'
                  : '채팅을 불러오지 못했어요. 다시 시도',
            ),
          ),
        ),
      ),
      _ => const SkeletonBox(width: double.infinity, height: 120),
    };
  }
}

class _Preview extends ConsumerWidget {
  const _Preview({required this.roomId, required this.unread});

  final String roomId;
  final int unread;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final latest = ref.watch(chatPreviewProvider(roomId)).value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: AppColors.backgroundGrouped,
            borderRadius: BorderRadius.circular(AppRadius.input),
          ),
          child: latest == null
              ? const SkeletonBox(width: double.infinity, height: 60)
              : latest.isEmpty
              ? Text(
                  '아직 대화가 없어요. 첫 인사를 남겨 보세요',
                  style: AppTypography.body.copyWith(
                    color: AppColors.textTertiary,
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final m in latest)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Text(
                          '${m.isMine ? '나' : m.senderNickname}: ${m.displayText}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.body,
                        ),
                      ),
                  ],
                ),
        ),
        const SizedBox(height: AppSpacing.md),
        AppButton(
          label: unread > 0 ? '채팅방 열기 · 새 메시지 $unread' : '채팅방 열기',
          onPressed: () async {
            await context.push(AppRoutes.chat(roomId));
            ref
              ..invalidate(chatPreviewProvider(roomId))
              ..invalidate(chatBadgesProvider);
          },
        ),
      ],
    );
  }
}
