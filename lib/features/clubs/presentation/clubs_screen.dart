import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/design/design.dart';
import '../../../core/utils/clock.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/pressable.dart';
import '../../../core/widgets/segmented_tabs.dart';
import '../../../core/widgets/skeleton_box.dart';
import '../../courses/domain/competition.dart';
import '../data/club_remote.dart';
import '../domain/club.dart';
import 'club_avatar.dart';
import 'club_detail_screen.dart';

enum _Tab { mine, ranking }

/// 동호회 탭: [내 클럽 | 클럽 랭킹].
/// 소속 클럽이 있으면 내 클럽(공지·일정·회원), 없으면 클럽 찾기와 만들기.
class ClubsScreen extends ConsumerStatefulWidget {
  const ClubsScreen({super.key});

  @override
  ConsumerState<ClubsScreen> createState() => _ClubsScreenState();
}

class _ClubsScreenState extends ConsumerState<ClubsScreen> {
  _Tab _tab = _Tab.mine;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('동호회')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenHorizontal,
              0,
              AppSpacing.screenHorizontal,
              AppSpacing.md,
            ),
            child: SegmentedTabs<_Tab>(
              options: const {_Tab.mine: '내 클럽', _Tab.ranking: '클럽 랭킹'},
              selected: _tab,
              onChanged: (t) => setState(() => _tab = t),
            ),
          ),
          Expanded(
            child: switch (_tab) {
              _Tab.mine => const _MyClub(),
              _Tab.ranking => const _ClubRanking(),
            },
          ),
        ],
      ),
    );
  }
}

class _MyClub extends ConsumerWidget {
  const _MyClub();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(myClubStatusProvider);
    return switch (status) {
      AsyncValue(:final value?) when value.clubId != null => ClubBody(
        clubId: value.clubId!,
      ),
      AsyncValue(:final value?) => _FindClub(status: value),
      AsyncValue(:final error?) => _Retry(
        message: clubErrorMessage(error),
        onRetry: () => ref.invalidate(myClubStatusProvider),
      ),
      _ => const Padding(
        padding: EdgeInsets.all(AppSpacing.screenHorizontal),
        child: SkeletonBox(width: double.infinity, height: 160),
      ),
    };
  }
}

/// 소속 클럽이 없을 때: 기다리는 신청, 클럽 찾기, 만들기
class _FindClub extends ConsumerStatefulWidget {
  const _FindClub({required this.status});

  final MyClubStatus status;

  @override
  ConsumerState<_FindClub> createState() => _FindClubState();
}

class _FindClubState extends ConsumerState<_FindClub> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final clubs = ref.watch(clubListProvider(_query));
    final pending = widget.status.pendingClubId;
    return Column(
      children: [
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async => ref
              ..invalidate(myClubStatusProvider)
              ..invalidate(clubListProvider),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.screenHorizontal,
              ),
              children: [
                if (pending != null) ...[
                  Pressable(
                    onPressed: () => context.push(AppRoutes.club(pending)),
                    child: Container(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(AppRadius.input),
                      ),
                      child: Text(
                        '${widget.status.pendingClubName ?? '동호회'}에 가입 신청했어요. '
                        '클럽장이 승인하면 이곳에 내 클럽이 보여요',
                        style: AppTypography.body.copyWith(
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ] else ...[
                  Text('아직 소속된 동호회가 없어요', style: AppTypography.subtitle),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    '함께 오르면 완등이 클럽 실적으로 쌓여요. 한 번에 한 동호회에만 가입할 수 있어요',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ],
                TextField(
                  style: AppTypography.body,
                  textInputAction: TextInputAction.search,
                  decoration: const InputDecoration(
                    hintText: '동호회 이름·지역으로 찾기',
                    prefixIcon: Icon(Icons.search_rounded),
                  ),
                  onSubmitted: (v) => setState(() => _query = v.trim()),
                ),
                const SizedBox(height: AppSpacing.lg),
                ...switch (clubs) {
                  AsyncValue(:final value?) when value.isEmpty => [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.xl,
                      ),
                      child: Text(
                        _query.isEmpty
                            ? '아직 동호회가 없어요. 첫 동호회를 만들어 보세요'
                            : '찾는 동호회가 없어요',
                        textAlign: TextAlign.center,
                        style: AppTypography.body.copyWith(
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ),
                  ],
                  AsyncValue(:final value?) => [
                    for (final c in value) _ClubTile(club: c),
                  ],
                  AsyncValue(:final error?) => [
                    _Retry(
                      message: clubErrorMessage(error),
                      onRetry: () => ref.invalidate(clubListProvider),
                    ),
                  ],
                  _ => [const SkeletonBox(width: double.infinity, height: 160)],
                },
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenHorizontal,
            AppSpacing.sm,
            AppSpacing.screenHorizontal,
            AppSpacing.lg,
          ),
          child: AppButton(
            label: '동호회 만들기',
            variant: pending == null
                ? AppButtonVariant.primary
                : AppButtonVariant.secondary,
            onPressed: () => context.push(AppRoutes.clubCreate),
          ),
        ),
      ],
    );
  }
}

class _ClubTile extends StatelessWidget {
  const _ClubTile({required this.club});

  final ClubSummary club;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onPressed: () => context.push(AppRoutes.club(club.id)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Row(
          children: [
            ClubAvatar(name: club.name, photoUrl: club.photoUrl),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    club.name,
                    style: AppTypography.body.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    [
                      if ((club.region ?? '').isNotEmpty) club.region!,
                      '회원 ${club.memberCount}/${club.maxMembers}',
                      '이번 시즌 완등 ${club.seasonCompletions}회',
                    ].join(' · '),
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (club.isFull)
              Text(
                '가득 참',
                style: AppTypography.caption.copyWith(
                  color: AppColors.textTertiary,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 클럽 랭킹 (누구나 전체): 시즌 클럽 완등 횟수
class _ClubRanking extends ConsumerStatefulWidget {
  const _ClubRanking();

  @override
  ConsumerState<_ClubRanking> createState() => _ClubRankingState();
}

class _ClubRankingState extends ConsumerState<_ClubRanking> {
  bool _allTime = false;

  @override
  Widget build(BuildContext context) {
    final now = ref.watch(clockProvider)();
    final current = Season.of(now);
    final rankingId = _allTime ? clubHallOfFameId : current.id;
    final ranking = ref.watch(clubRankingProvider(rankingId));
    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(clubRankingProvider(rankingId)),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.screenHorizontal,
        ),
        children: [
          SegmentedTabs<bool>(
            options: const {false: '이번 시즌', true: '명예의 전당'},
            selected: _allTime,
            onChanged: (v) => setState(() => _allTime = v),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            _allTime
                ? '역대 전체 · 회원이 소속 기간에 완주한 횟수의 합'
                : '${current.label} · 회원이 소속 기간에 완주한 횟수의 합',
            style: AppTypography.caption.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          ...switch (ranking) {
            AsyncValue(:final value?) when value.isEmpty => [
              Text(
                '아직 동호회가 없어요',
                textAlign: TextAlign.center,
                style: AppTypography.body.copyWith(
                  color: AppColors.textTertiary,
                ),
              ),
            ],
            AsyncValue(:final value?) => [
              for (final r in value)
                Pressable(
                  onPressed: () => context.push(AppRoutes.club(r.clubId)),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: AppSpacing.xs),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm,
                    ),
                    decoration: BoxDecoration(
                      color: r.isMine
                          ? AppColors.backgroundGrouped
                          : AppColors.background,
                      borderRadius: BorderRadius.circular(AppRadius.input),
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: AppSpacing.xxxl,
                          child: Text(
                            '${r.rank}',
                            style: AppTypography.subtitle.copyWith(
                              color: r.rank <= 3
                                  ? AppColors.primary
                                  : AppColors.textTertiary,
                            ),
                          ),
                        ),
                        ClubAvatar(
                          name: r.name,
                          photoUrl: r.photoUrl,
                          size: 40,
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                r.isMine ? '${r.name} (내 클럽)' : r.name,
                                style: AppTypography.body.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                '회원 ${r.memberCount}명 · 활동 ${r.activeMembers}명',
                                style: AppTypography.caption.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '${r.completions}회',
                          style: AppTypography.body.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
            AsyncValue(:final error?) => [
              _Retry(
                message: clubErrorMessage(error),
                onRetry: () => ref.invalidate(clubRankingProvider(rankingId)),
              ),
            ],
            _ => [const SkeletonBox(width: double.infinity, height: 200)],
          },
          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }
}

class _Retry extends StatelessWidget {
  const _Retry({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(AppSpacing.xl),
    child: Column(
      children: [
        Text(
          message,
          textAlign: TextAlign.center,
          style: AppTypography.body.copyWith(color: AppColors.textSecondary),
        ),
        TextButton(onPressed: onRetry, child: const Text('다시 시도')),
      ],
    ),
  );
}
