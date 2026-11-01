import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/design.dart';
import '../../../core/widgets/empty_view.dart';
import '../../../core/widgets/nickname_text.dart';
import '../../../core/widgets/pressable.dart';
import '../../../core/widgets/skeleton_box.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../auth/presentation/public_profile_sheet.dart';
import '../data/club_remote.dart';
import 'club_detail_screen.dart';
import 'club_format.dart';

/// 가입 신청 (클럽장): 신청한 사람의 공개 프로필을 보고 승인·거절한다.
class ClubRequestsScreen extends ConsumerWidget {
  const ClubRequestsScreen({super.key, required this.clubId});

  final String clubId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requests = ref.watch(clubJoinRequestsProvider(clubId));
    final remote = ref.read(clubRemoteProvider);

    Future<void> decide(int id, bool approve) async {
      await runClubAction(
        context,
        () => remote.decideJoinRequest(id, approve: approve),
        done: approve ? '회원으로 받았어요' : '신청을 거절했어요',
      );
      refreshClub(ref, clubId);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('가입 신청')),
      body: switch (requests) {
        AsyncValue(:final value?) when value.isEmpty => const EmptyView(
          message: '기다리는 가입 신청이 없어요',
        ),
        AsyncValue(:final value?) => RefreshIndicator(
          onRefresh: () async =>
              ref.invalidate(clubJoinRequestsProvider(clubId)),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
            children: [
              for (final r in value)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                  child: Row(
                    children: [
                      Expanded(
                        child: Pressable(
                          onPressed: () => showPublicProfile(
                            context,
                            nickname: r.nickname,
                            tag: r.nicknameTag,
                            avatarUrl: r.avatarUrl,
                          ),
                          child: Row(
                            children: [
                              UserAvatar(
                                nickname: r.nickname,
                                imageUrl: r.avatarUrl,
                              ),
                              const SizedBox(width: AppSpacing.md),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    NicknameText(
                                      nickname: r.nickname,
                                      tag: r.nicknameTag,
                                      style: AppTypography.body.copyWith(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Text(
                                      [
                                        if ((r.region ?? '').isNotEmpty)
                                          r.region!,
                                        '${formatShortDate(r.requestedAt)} 신청',
                                      ].join(' · '),
                                      style: AppTypography.caption.copyWith(
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () => decide(r.id, false),
                        child: Text(
                          '거절',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      ),
                      FilledButton(
                        onPressed: () => decide(r.id, true),
                        child: const Text('승인'),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        AsyncValue(:final error?) => EmptyView(
          message: clubErrorMessage(error),
        ),
        _ => const Padding(
          padding: EdgeInsets.all(AppSpacing.screenHorizontal),
          child: SkeletonBox(width: double.infinity, height: 120),
        ),
      },
    );
  }
}
