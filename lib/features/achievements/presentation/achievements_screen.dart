import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/design/design.dart';
import '../../../core/utils/clock.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/pressable.dart';
import '../../../core/widgets/skeleton_box.dart';
import '../../courses/domain/competition.dart';
import '../domain/achievements.dart';
import 'achievements_providers.dart';
import 'badge_medal.dart';

/// 업적 화면: 묶음별 배지 격자 + 시즌 정복 기록
class AchievementsScreen extends ConsumerWidget {
  const AchievementsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final achievements = ref.watch(myAchievementsProvider);
    final names = ref.watch(courseNamesProvider);
    final now = ref.watch(clockProvider)();

    return Scaffold(
      appBar: AppBar(title: const Text('업적')),
      body: switch (achievements) {
        AsyncValue(:final value?) => ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenHorizontal,
            AppSpacing.sm,
            AppSpacing.screenHorizontal,
            AppSpacing.xxxl,
          ),
          children: [
            _Summary(achievements: value),
            if (value.partial) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                '인터넷에 연결되면 완등·정복·리뷰 배지를 확인할 수 있어요',
                style: AppTypography.caption.copyWith(
                  color: AppColors.textTertiary,
                ),
              ),
            ],
            for (final group in BadgeGroup.values) ...[
              const SizedBox(height: AppSpacing.xxl),
              Text(group.label, style: AppTypography.subtitle),
              const SizedBox(height: AppSpacing.md),
              _Grid(
                children: [
                  for (final b in value.badges)
                    if (b.def.group == group) _BadgeTile(status: b, now: now),
                ],
              ),
            ],
            const SizedBox(height: AppSpacing.xxl),
            const Text('시즌 정복 기록', style: AppTypography.subtitle),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '시즌이 끝날 때 코스 1위면 여기에 남아요',
              style: AppTypography.caption.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            if (value.seasons.isEmpty)
              Container(
                padding: const EdgeInsets.all(AppSpacing.xl),
                decoration: BoxDecoration(
                  color: AppColors.backgroundGrouped,
                  borderRadius: BorderRadius.circular(AppRadius.card),
                ),
                child: Text(
                  '아직 시즌 정복 기록이 없어요. 이번 시즌 코스 1위에 도전해 보세요',
                  style: AppTypography.body.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              )
            else
              for (final s in value.seasons)
                _SeasonRow(badge: s, courseName: names[s.courseId]),
          ],
        ),
        AsyncValue(:final error?) => _ErrorView(
          onRetry: () => ref.invalidate(myAchievementsProvider),
          error: error,
        ),
        _ => const _Loading(),
      },
    );
  }
}

/// "31개 중 12개를 얻었어요" + 진행 막대
class _Summary extends StatelessWidget {
  const _Summary({required this.achievements});

  final Achievements achievements;

  @override
  Widget build(BuildContext context) {
    final total = Badges.totalLevels;
    final earned = achievements.earnedLevels;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.backgroundGrouped,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '$earned',
                  style: AppTypography.title.copyWith(color: AppColors.primary),
                ),
                TextSpan(text: ' / $total', style: AppTypography.subtitle),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '배지 $total개 중 $earned개를 얻었어요'
            '${achievements.seasons.isEmpty ? '' : ' · 시즌 정복 ${achievements.seasons.length}번'}',
            style: AppTypography.caption.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _Bar(value: total == 0 ? 0 : earned / total),
        ],
      ),
    );
  }
}

class _Grid extends StatelessWidget {
  const _Grid({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const columns = 3;
        final width =
            (constraints.maxWidth - AppSpacing.md * (columns - 1)) / columns;
        return Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.lg,
          children: [
            for (final c in children) SizedBox(width: width, child: c),
          ],
        );
      },
    );
  }
}

class _BadgeTile extends StatelessWidget {
  const _BadgeTile({required this.status, required this.now});

  final BadgeStatus status;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final latest = status.earned ? status.achievedAt.last : null;
    final isNew =
        latest != null && now.difference(latest) < Achievements.newFor;
    return Pressable(
      onPressed: () => showBadgeDetail(context, status),
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              BadgeMedal(def: status.def, tier: status.tier, size: 64),
              if (isNew)
                Positioned(
                  right: -6,
                  top: -4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.danger,
                      borderRadius: BorderRadius.circular(AppRadius.button),
                    ),
                    child: Text(
                      'NEW',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.onPrimary,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            status.def.name,
            textAlign: TextAlign.center,
            maxLines: 2,
            style: AppTypography.caption.copyWith(
              color: status.earned
                  ? AppColors.textPrimary
                  : AppColors.textTertiary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          if (!status.available)
            Text(
              '확인할 수 없음',
              style: AppTypography.caption.copyWith(
                color: AppColors.textTertiary,
              ),
            )
          else if (status.maxed)
            Text(
              '모두 얻었어요',
              style: AppTypography.caption.copyWith(
                color: AppColors.textSecondary,
              ),
            )
          else ...[
            _Bar(value: status.progress, height: 4),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '${badgeValue(status.def, status.value)}'
              ' / ${badgeValue(status.def, status.nextGoal!)}${status.def.unit.label}',
              style: AppTypography.caption.copyWith(
                color: AppColors.textTertiary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SeasonRow extends StatelessWidget {
  const _SeasonRow({required this.badge, required this.courseName});

  final SeasonBadge badge;
  final String? courseName;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        children: [
          const BadgeMedal.season(size: 52),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  seasonBadgeTitle(badge),
                  style: AppTypography.body.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  seasonBadgeSubtitle(badge, courseName),
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.value, this.height = 8});

  final double value;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: LinearProgressIndicator(
        value: value,
        minHeight: height,
        color: AppColors.primary,
        backgroundColor: AppColors.divider,
      ),
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
      children: const [
        SkeletonBox(width: double.infinity, height: 110),
        SizedBox(height: AppSpacing.xxl),
        SkeletonBox(width: double.infinity, height: 240),
      ],
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.onRetry, required this.error});

  final VoidCallback onRetry;
  final Object error;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('업적을 불러오지 못했어요', style: AppTypography.subtitle),
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            label: '다시 시도',
            variant: AppButtonVariant.secondary,
            onPressed: onRetry,
          ),
        ],
      ),
    );
  }
}

/// 배지를 누르면: 단계별 조건과 얻은 날짜, 지금 값
Future<void> showBadgeDetail(BuildContext context, BadgeStatus status) {
  final def = status.def;
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.background,
    showDragHandle: true,
    builder: (context) => SafeArea(
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
            BadgeMedal(def: def, tier: status.tier, size: 96),
            const SizedBox(height: AppSpacing.lg),
            Text(def.name, style: AppTypography.title),
            const SizedBox(height: AppSpacing.xs),
            Text(
              !status.available
                  ? '인터넷에 연결되면 확인할 수 있어요'
                  : status.earned
                  ? '${status.tier!.label} 배지 · ${badgeDate(status.achievedAt.last)}'
                  : '아직 얻지 못했어요',
              style: AppTypography.caption.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            for (var i = 0; i < def.levels; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: Row(
                  children: [
                    Icon(
                      i < status.level
                          ? Icons.check_circle_rounded
                          : Icons.radio_button_unchecked_rounded,
                      size: 20,
                      color: i < status.level
                          ? tierColor(def.tierOf(i + 1))
                          : AppColors.badgeLocked,
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Text(def.goals[i], style: AppTypography.body),
                    ),
                    if (i < status.level)
                      Text(
                        badgeDate(status.achievedAt[i]),
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textTertiary,
                        ),
                      ),
                  ],
                ),
              ),
            if (status.available && def.levels > 1)
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '지금 기록: ${badgeValue(def, status.value)}${def.unit.label}'
                  '${def == Badges.streak || def == Badges.hold ? ' (가장 길었던 기간)' : ''}',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

/// 진행 값 표시: km는 소수 한 자리, 나머지는 정수 (천 단위 쉼표)
String badgeValue(BadgeDef def, double value) {
  if (def.unit == BadgeUnit.km) return value.toStringAsFixed(1);
  final n = value.floor().toString();
  return n.replaceAllMapped(RegExp(r'\B(?=(\d{3})+$)'), (_) => ',');
}

String badgeDate(DateTime t) {
  final l = t.toLocal();
  return '${l.year}년 ${l.month}월 ${l.day}일';
}

/// 배지 단계 이름. 예: "걸어온 길 · 은"
String earnedBadgeTitle(EarnedBadge e) {
  final def = e.def;
  if (def == null) return seasonBadgeTitle(e.season!);
  return def.levels == 1
      ? def.name
      : '${def.name} · ${def.tierOf(e.level).label}';
}

String seasonBadgeTitle(SeasonBadge s) => '${s.season.label} 정복자';

String seasonBadgeSubtitle(SeasonBadge s, String? courseName) =>
    '${courseName ?? '코스'} · '
    '${s.kind == RankingKind.most ? '최다완등' : '최단시간'} 1위';

/// 내 정보의 업적 카드: 얻은 수와 최근 배지 3개. 누르면 업적 화면.
class AchievementsCard extends ConsumerWidget {
  const AchievementsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(myAchievementsProvider).value;
    final recent = value?.earned.take(3).toList() ?? const <EarnedBadge>[];
    return Pressable(
      onPressed: () => context.push(AppRoutes.achievements),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.xl),
        decoration: BoxDecoration(
          color: AppColors.backgroundGrouped,
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('업적', style: AppTypography.subtitle),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    value == null
                        ? '배지를 모아 보세요'
                        : '${value.earnedLevels} / ${Badges.totalLevels}개 얻었어요',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            for (final e in recent)
              Padding(
                padding: const EdgeInsets.only(left: AppSpacing.xs),
                child: e.def == null
                    ? const BadgeMedal.season(size: 36)
                    : BadgeMedal(
                        def: e.def!,
                        tier: e.def!.tierOf(e.level),
                        size: 36,
                      ),
              ),
            const SizedBox(width: AppSpacing.xs),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textTertiary,
            ),
          ],
        ),
      ),
    );
  }
}
