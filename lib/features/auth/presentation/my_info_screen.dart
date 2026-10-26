import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';

import '../../../core/design/design.dart';
import '../../../core/utils/clock.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/pressable.dart';
import '../../../core/widgets/skeleton_box.dart';
import '../../achievements/presentation/achievements_screen.dart';
import '../../activities/data/demo_activity_generator.dart';
import '../../activities/presentation/activities_providers.dart';
import '../../subscription/data/subscription_remote.dart';
import '../domain/app_user.dart';
import '../domain/auth_failure.dart';
import 'auth_feedback.dart';
import 'auth_providers.dart';

/// 내 정보 탭: 닉네임, 로그인한 계정, 프리미엄, 로그아웃.
class MyInfoScreen extends ConsumerStatefulWidget {
  const MyInfoScreen({super.key});

  @override
  ConsumerState<MyInfoScreen> createState() => _MyInfoScreenState();
}

class _MyInfoScreenState extends ConsumerState<MyInfoScreen> {
  bool _busy = false;

  Future<void> _signOut() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      // 로그아웃되면 라우터가 알아서 로그인 화면으로 보낸다.
      await ref.read(authRepositoryProvider).signOut();
    } on AuthFailure catch (failure) {
      if (mounted) showAuthFailure(context, failure);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider).value;
    final profile = ref.watch(myProfileProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('내 정보')),
      body: ListView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.screenHorizontal,
          vertical: AppSpacing.lg,
        ),
        children: [
          if (profile.isLoading)
            const Align(
              alignment: Alignment.centerLeft,
              child: SkeletonBox(width: 120, height: 32),
            )
          else
            // 불러오기에 실패해도 화면은 쓸 수 있게 기본 닉네임을 보여 준다.
            Text(profile.value?.nickname ?? '등산객', style: AppTypography.title),
          const SizedBox(height: AppSpacing.xs),
          Text(
            _accountDescription(user),
            style: AppTypography.body.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.xxl),
          const AchievementsCard(),
          const SizedBox(height: AppSpacing.md),
          const _PremiumCard(),
          const SizedBox(height: AppSpacing.xxl),
          // 시연·테스트용 기능은 개발 빌드에서만 보인다.
          if (kDebugMode) ...[
            const _DemoDataButton(),
            const SizedBox(height: AppSpacing.lg),
          ],
          Pressable(
            onPressed: _busy ? null : _signOut,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: Text(
                '로그아웃',
                style: AppTypography.body.copyWith(
                  color: AppColors.textTertiary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _accountDescription(AppUser? user) {
    final provider = user?.provider;
    if (provider == null) return '로그인했어요';
    return '${provider.label} 계정으로 로그인했어요';
  }
}

/// 프리미엄 상태 카드. 누르면 구독 화면으로 간다.
class _PremiumCard extends ConsumerWidget {
  const _PremiumCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subscription = ref.watch(mySubscriptionProvider).value;
    final active = subscription?.isActive ?? false;
    final expires = subscription?.expiresAt.toLocal();
    return Pressable(
      onPressed: () => context.push(AppRoutes.premium),
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
                  Text(
                    active ? '프리미엄 이용 중' : '프리미엄',
                    style: AppTypography.subtitle.copyWith(
                      color: active ? AppColors.primary : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    active && expires != null
                        ? '${expires.month}월 ${expires.day}일까지 · 관리하기'
                        : '랭킹 전체 순위와 상세 분석을 받아 보세요',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
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

/// 개발용: 이 기기의 시연용 기록을 지우고, 여러 상황(완주·중도 하산·속도 이상·개인 산책)을
/// 확인할 수 있는 시연용 기록 8개를 새로 만든다. 서버 쪽 시연용 데이터는 supabase/seed/demo_data.sql.
class _DemoDataButton extends ConsumerStatefulWidget {
  const _DemoDataButton();

  @override
  ConsumerState<_DemoDataButton> createState() => _DemoDataButtonState();
}

class _DemoDataButtonState extends ConsumerState<_DemoDataButton> {
  bool _busy = false;

  Future<void> _create() async {
    final userId = ref.read(authRepositoryProvider).currentUser?.id;
    if (_busy || userId == null) return;
    setState(() => _busy = true);
    String message;
    try {
      final courses = await ref.read(demoCoursesProvider.future);
      final ids = await ref
          .read(demoActivityGeneratorProvider)
          .createDemoHikes(
            courses: courses,
            userId: userId,
            now: ref.read(clockProvider)(),
          );
      // 일반 기록처럼 서버에 올리고 코스 완주도 판정한다.
      await ref.read(uploadActionsProvider).uploadPending();
      message = ids.isEmpty
          ? '금정산·승학산 코스를 아직 받지 못했어요. 홈 지도에 코스가 보이면 다시 눌러 주세요'
          : '시연용 기록을 ${ids.length}개 새로 만들었어요. 기록 탭에서 볼 수 있어요';
    } catch (e) {
      debugPrint('[demo] $e');
      message = '시연용 기록을 만들지 못했어요';
    }
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('개발용 (개발 빌드에서만 보여요)', style: AppTypography.caption),
        const SizedBox(height: AppSpacing.sm),
        AppButton(
          label: _busy ? '만드는 중…' : '시연용 기록 다시 만들기 (8개)',
          variant: AppButtonVariant.secondary,
          onPressed: _busy ? null : _create,
        ),
      ],
    );
  }
}
