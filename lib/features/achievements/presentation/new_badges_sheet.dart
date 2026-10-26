import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/design.dart';
import '../../../core/widgets/app_button.dart';
import '../domain/achievements.dart';
import 'achievements_providers.dart';
import 'achievements_screen.dart';
import 'badge_medal.dart';

/// 기록 저장 뒤 "새 배지를 얻었어요" 카드.
/// [initial]은 바로 알 수 있는 배지(거리·높이 등), [later]는 업로드 뒤 서버에서 확인한 배지(완등·정복).
Future<void> showNewBadges(
  BuildContext context, {
  required List<EarnedBadge> initial,
  Future<List<EarnedBadge>>? later,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.background,
    isScrollControlled: true,
    builder: (context) => _NewBadgesSheet(initial: initial, later: later),
  );
}

class _NewBadgesSheet extends ConsumerWidget {
  const _NewBadgesSheet({required this.initial, required this.later});

  final List<EarnedBadge> initial;
  final Future<List<EarnedBadge>>? later;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final names = ref.watch(courseNamesProvider);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenHorizontal,
          AppSpacing.xxl,
          AppSpacing.screenHorizontal,
          AppSpacing.xl,
        ),
        child: FutureBuilder<List<EarnedBadge>>(
          future: later,
          builder: (context, snapshot) {
            final more = snapshot.data ?? const <EarnedBadge>[];
            final checking =
                later != null &&
                snapshot.connectionState != ConnectionState.done;
            final badges = [...initial, ...more];
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('새 배지를 얻었어요', style: AppTypography.title),
                const SizedBox(height: AppSpacing.xl),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.sizeOf(context).height * 0.5,
                  ),
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      for (final b in badges) _Row(badge: b, names: names),
                    ],
                  ),
                ),
                if (checking)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.sm),
                    child: Text(
                      '완등·정복 배지를 확인하고 있어요…',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ),
                const SizedBox(height: AppSpacing.xl),
                AppButton(
                  label: '확인',
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.badge, required this.names});

  final EarnedBadge badge;
  final Map<String, String> names;

  @override
  Widget build(BuildContext context) {
    final def = badge.def;
    final season = badge.season;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Row(
        children: [
          def == null
              ? const BadgeMedal.season(size: 52)
              : BadgeMedal(def: def, tier: def.tierOf(badge.level), size: 52),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  earnedBadgeTitle(badge),
                  style: AppTypography.body.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  def == null
                      ? seasonBadgeSubtitle(season!, names[season.courseId])
                      : def.goals[badge.level - 1],
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
