import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/design/design.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/nickname_text.dart';
import '../../../core/widgets/skeleton_box.dart';
import '../../../core/widgets/user_avatar.dart';
import '../data/profile_remote.dart';
import '../../../core/widgets/pressable.dart';
import '../../chat/presentation/chat_screen.dart';

/// 랭킹·리뷰에서 닉네임#태그를 누르면 그 사람의 공개 프로필(사진·닉네임·주 활동 지역·소개)을 보여 준다.
/// 개인정보(이름·연락처·주소)는 서버가 돌려주지 않는다.
Future<void> showPublicProfile(
  BuildContext context, {
  required String nickname,
  required String tag,
  String? avatarUrl,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.background,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) =>
        _PublicProfileSheet(nickname: nickname, tag: tag, avatarUrl: avatarUrl),
  );
}

class _PublicProfileSheet extends ConsumerWidget {
  const _PublicProfileSheet({
    required this.nickname,
    required this.tag,
    required this.avatarUrl,
  });

  final String nickname;
  final String tag;
  final String? avatarUrl;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(publicProfileProvider((nickname, tag)));
    final p = profile.value;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenHorizontal,
          0,
          AppSpacing.screenHorizontal,
          AppSpacing.xxl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            UserAvatar(
              nickname: nickname,
              imageUrl: p?.avatarUrl ?? avatarUrl,
              size: 80,
            ),
            const SizedBox(height: AppSpacing.md),
            NicknameText(
              nickname: p?.nickname ?? nickname,
              tag: p?.nicknameTag ?? tag,
              style: AppTypography.title,
            ),
            if (p?.region case final region? when region.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xs),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.place_outlined,
                    size: 16,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Flexible(
                    child: Text(
                      region,
                      style: AppTypography.body.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            if (p?.clubId case final clubId?) ...[
              const SizedBox(height: AppSpacing.sm),
              Pressable(
                onPressed: () {
                  Navigator.of(context).pop();
                  context.push(AppRoutes.club(clubId));
                },
                child: Text(
                  '${p!.clubName} 동호회',
                  style: AppTypography.body.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.xl),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: AppColors.backgroundGrouped,
                borderRadius: BorderRadius.circular(AppRadius.input),
              ),
              child: switch (profile) {
                AsyncData(:final value) => Text(
                  value == null
                      ? '프로필을 찾지 못했어요'
                      : (value.bio ?? '').isEmpty
                      ? '아직 소개가 없어요'
                      : value.bio!,
                  style: AppTypography.body.copyWith(
                    color: (value?.bio ?? '').isEmpty
                        ? AppColors.textTertiary
                        : AppColors.textPrimary,
                  ),
                ),
                AsyncError() => Text(
                  '인터넷에 연결되면 프로필을 볼 수 있어요',
                  style: AppTypography.body.copyWith(
                    color: AppColors.textTertiary,
                  ),
                ),
                _ => const SkeletonBox(width: double.infinity, height: 48),
              },
            ),
            if (p != null && !p.isMe) ...[
              const SizedBox(height: AppSpacing.xl),
              AppButton(
                label: '메시지 보내기',
                variant: AppButtonVariant.secondary,
                onPressed: () {
                  Navigator.of(context).pop();
                  context.push(
                    AppRoutes.chatNew,
                    extra: ChatTarget(
                      nickname: p.nickname,
                      tag: p.nicknameTag,
                      avatarUrl: p.avatarUrl,
                    ),
                  );
                },
              ),
            ],
            if (p?.isMe ?? false) ...[
              const SizedBox(height: AppSpacing.xl),
              AppButton(
                label: '내 프로필 편집',
                variant: AppButtonVariant.secondary,
                onPressed: () {
                  Navigator.of(context).pop();
                  context.push(AppRoutes.profileEdit);
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}
