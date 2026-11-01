import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';

import '../../../core/design/design.dart';
import '../../../core/utils/clock.dart';
import '../../../core/widgets/nickname_text.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/pressable.dart';
import '../../../core/widgets/skeleton_box.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../achievements/presentation/achievements_screen.dart';
import '../../activities/data/demo_activity_generator.dart';
import '../../activities/presentation/activities_providers.dart';
import '../../mileage/data/mileage_remote.dart';
import '../../mileage/domain/mileage.dart';
import '../../subscription/data/subscription_remote.dart';
import '../data/profile_remote.dart';
import '../domain/app_user.dart';
import '../domain/auth_failure.dart';
import 'auth_feedback.dart';
import 'auth_providers.dart';
import '../../chat/data/chat_remote.dart';

/// 맨 아래에 보여 주는 앱 버전 (pubspec.yaml의 version과 맞춘다)
const appVersionLabel = '0.1.0';

/// 내 정보 탭: 프로필(누르면 편집), 메시지, 업적, 프리미엄, 마일리지, 주문 내역, 개인정보 관리, 로그아웃.
class MyInfoScreen extends ConsumerStatefulWidget {
  const MyInfoScreen({super.key});

  @override
  ConsumerState<MyInfoScreen> createState() => _MyInfoScreenState();
}

class _MyInfoScreenState extends ConsumerState<MyInfoScreen> {
  bool _busy = false;
  int _versionTaps = 0;
  bool _devUnlocked = false;

  void _onVersionTap() {
    if (_devUnlocked || kDebugMode) return;
    _versionTaps++;
    if (_versionTaps < 5) return;
    setState(() => _devUnlocked = true);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('개발용 메뉴를 열었어요')));
  }

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
          // 누르면 프로필 편집 (다른 사람에게 보이는 정보)
          Pressable(
            onPressed: () => context.push(AppRoutes.profileEdit),
            child: Row(
              children: [
                UserAvatar(
                  nickname: profile.value?.nickname ?? '등산객',
                  imageUrl: profile.value?.avatarUrl,
                  size: 64,
                ),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (profile.isLoading)
                        const SkeletonBox(width: 120, height: 32)
                      else
                        // 불러오기에 실패해도 화면은 쓸 수 있게 기본 닉네임을 보여 준다.
                        NicknameText(
                          nickname: profile.value?.nickname ?? '등산객',
                          tag: profile.value?.nicknameTag,
                          style: AppTypography.title,
                        ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        _accountDescription(user),
                        style: AppTypography.body.copyWith(
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
          const SizedBox(height: AppSpacing.xxl),
          const _MessagesCard(),
          const SizedBox(height: AppSpacing.md),
          const AchievementsCard(),
          const SizedBox(height: AppSpacing.md),
          const _PremiumCard(),
          const SizedBox(height: AppSpacing.md),
          const _MileageCard(),
          const SizedBox(height: AppSpacing.md),
          const _OrdersCard(),
          const SizedBox(height: AppSpacing.md),
          const _PrivateInfoCard(),
          const SizedBox(height: AppSpacing.xxl),
          // 시연·테스트용 기능: 개발 빌드에서는 늘 보이고, 시연용 릴리스 빌드에서는
          // 맨 아래 버전 글자를 5번 누르면 보인다.
          if (kDebugMode || _devUnlocked) ...[
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
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _onVersionTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: Text(
                '버전 $appVersionLabel',
                style: AppTypography.caption.copyWith(
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

/// 1:1 메시지 카드: 안 읽은 메시지·받은 요청 수. 누르면 메시지 목록.
class _MessagesCard extends ConsumerWidget {
  const _MessagesCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final badges = ref.watch(chatBadgesProvider).value;
    final count = (badges?.directUnread ?? 0) + (badges?.pendingRequests ?? 0);
    return Pressable(
      onPressed: () async {
        await context.push(AppRoutes.chats);
        ref.invalidate(chatBadgesProvider);
      },
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
                  const Text('메시지', style: AppTypography.subtitle),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    [
                      if ((badges?.pendingRequests ?? 0) > 0)
                        '메시지 요청 ${badges!.pendingRequests}',
                      if ((badges?.directUnread ?? 0) > 0)
                        '안 읽은 메시지 ${badges!.directUnread}',
                    ].join(' · ').ifEmpty('1:1 대화'),
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (count > 0)
              Container(
                margin: const EdgeInsets.only(right: AppSpacing.xs),
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                decoration: BoxDecoration(
                  color: AppColors.danger,
                  borderRadius: BorderRadius.circular(AppRadius.button),
                ),
                child: Text(
                  '$count',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.onPrimary,
                  ),
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

extension on String {
  String ifEmpty(String fallback) => isEmpty ? fallback : this;
}

/// 마일리지 카드: 잔액. 누르면 마일리지 화면(교환권·내역).
class _MileageCard extends ConsumerWidget {
  const _MileageCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(mileageSummaryProvider).value;
    return Pressable(
      onPressed: () async {
        await context.push(AppRoutes.mileage);
        ref.invalidate(mileageSummaryProvider);
      },
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
                  const Text('마일리지', style: AppTypography.subtitle),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    '프리미엄 교환권으로 바꿀 수 있어요',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (summary != null)
              Text(
                formatMileage(summary.balance),
                style: AppTypography.subtitle.copyWith(
                  color: AppColors.primary,
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

/// 주문 내역 카드 (쇼핑). 누르면 주문 내역 화면.
class _OrdersCard extends StatelessWidget {
  const _OrdersCard();

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onPressed: () => context.push(AppRoutes.orders),
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
                  const Text('주문 내역', style: AppTypography.subtitle),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    '배송 상태를 보고, 받은 상품의 리뷰를 써요',
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

/// 개인정보 관리 카드 (본인만 보는 이름·휴대폰 번호·주소). 누르면 개인정보 관리 화면.
class _PrivateInfoCard extends ConsumerWidget {
  const _PrivateInfoCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final info = ref.watch(myPrivateInfoProvider).value;
    return Pressable(
      onPressed: () async {
        await context.push<bool>(AppRoutes.privateInfo);
        ref.invalidate(myPrivateInfoProvider);
      },
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
                  const Text('개인정보 관리', style: AppTypography.subtitle),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    '${info?.summary ?? '이름·휴대폰 번호·주소'} · 나만 볼 수 있어요',
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
        const Text('개발용 (시연 준비용)', style: AppTypography.caption),
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
