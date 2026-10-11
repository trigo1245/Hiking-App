import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/design.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/pressable.dart';
import '../../../core/widgets/skeleton_box.dart';
import '../data/auth_repository.dart';
import '../domain/app_user.dart';
import '../domain/auth_failure.dart';
import 'auth_feedback.dart';
import 'auth_providers.dart';

/// 내 정보 탭: 닉네임, 계정 연결, 로그아웃.
class MyInfoScreen extends ConsumerStatefulWidget {
  const MyInfoScreen({super.key});

  @override
  ConsumerState<MyInfoScreen> createState() => _MyInfoScreenState();
}

class _MyInfoScreenState extends ConsumerState<MyInfoScreen> {
  bool _busy = false;

  /// [linking]: 계정 연결 중이면 그 소셜 계정. "이미 가입된 계정" 안내에 쓴다.
  Future<void> _run(
    Future<void> Function(AuthRepository) action, {
    SocialProvider? linking,
  }) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action(ref.read(authRepositoryProvider));
    } on AuthFailure catch (failure) {
      if (!mounted) return;
      if (linking != null) {
        _handleFailure(failure, linking);
      } else {
        showAuthFailure(context, failure);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _link(SocialProvider provider) => _run(
    (repo) => switch (provider) {
      SocialProvider.kakao => repo.linkKakao(),
      SocialProvider.google => repo.linkGoogle(),
    },
    linking: provider,
  );

  void _handleFailure(AuthFailure failure, SocialProvider provider) {
    if (failure.type == AuthFailureType.identityAlreadyExists) {
      _offerSwitchAccount(provider);
    } else {
      showAuthFailure(context, failure);
    }
  }

  /// 연결하려는 소셜 계정에 이미 다른 사용자가 있을 때: 그 계정으로 로그인할지 묻는다.
  Future<void> _offerSwitchAccount(SocialProvider provider) async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.card),
        ),
      ),
      builder: (context) => _SwitchAccountSheet(provider: provider),
    );
    if (confirmed != true) return;
    await _run(
      (repo) => switch (provider) {
        SocialProvider.kakao => repo.signInWithKakao(),
        SocialProvider.google => repo.signInWithGoogle(),
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // 카카오 연결은 브라우저를 거쳐 결과가 나중에 오므로 스트림으로 받는다.
    ref.listen(authFailuresProvider, (_, next) {
      final failure = next.value;
      if (failure != null) _handleFailure(failure, SocialProvider.kakao);
    });

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
            Text(
              profile.value?.nickname ?? '등산객',
              style: AppTypography.title,
            ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            _accountDescription(user),
            style: AppTypography.body.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.xxl),
          if (user != null && user.isAnonymous)
            _LinkAccountCard(onLink: _busy ? null : _link)
          else if (user != null) ...[
            for (final provider in SocialProvider.values)
              if (!user.isLinkedTo(provider)) ...[
                AppButton(
                  label: '${provider.label} 계정도 연결하기',
                  variant: AppButtonVariant.secondary,
                  onPressed: _busy ? null : () => _link(provider),
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
            const SizedBox(height: AppSpacing.lg),
            Pressable(
              onPressed: _busy ? null : () => _run((repo) => repo.signOut()),
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
        ],
      ),
    );
  }

  static String _accountDescription(AppUser? user) {
    if (user == null || user.isAnonymous) return '로그인 없이 사용하고 있어요';
    final names = [
      for (final p in SocialProvider.values)
        if (user.isLinkedTo(p)) p.label,
    ];
    return '${names.join(', ')} 계정으로 로그인했어요';
  }
}

/// 익명 사용자에게 계정 연결을 권하는 카드.
class _LinkAccountCard extends StatelessWidget {
  const _LinkAccountCard({required this.onLink});

  final void Function(SocialProvider)? onLink;

  @override
  Widget build(BuildContext context) {
    final onLink = this.onLink;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.backgroundGrouped,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('계정을 연결해 주세요', style: AppTypography.subtitle),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '지금은 앱을 지우면 기록을 다시 볼 수 없어요. '
            '계정을 연결하면 지금까지의 기록이 그대로 옮겨져요.',
            style: AppTypography.body.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            label: '카카오 계정 연결하기',
            variant: AppButtonVariant.kakao,
            onPressed: onLink == null
                ? null
                : () => onLink(SocialProvider.kakao),
          ),
          const SizedBox(height: AppSpacing.sm),
          AppButton(
            label: '구글 계정 연결하기',
            variant: AppButtonVariant.primary,
            onPressed: onLink == null
                ? null
                : () => onLink(SocialProvider.google),
          ),
        ],
      ),
    );
  }
}

class _SwitchAccountSheet extends StatelessWidget {
  const _SwitchAccountSheet({required this.provider});

  final SocialProvider provider;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('이미 가입된 계정이 있어요', style: AppTypography.subtitle),
            const SizedBox(height: AppSpacing.sm),
            Text(
              '이 ${provider.label} 계정으로 예전에 가입했어요. '
              '그 계정으로 로그인할까요?\n'
              '지금 로그인 없이 남긴 기록은 옮겨지지 않아요.',
              style: AppTypography.body.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),
            AppButton(
              label: '그 계정으로 로그인하기',
              onPressed: () => Navigator.of(context).pop(true),
            ),
            const SizedBox(height: AppSpacing.sm),
            AppButton(
              label: '취소',
              variant: AppButtonVariant.secondary,
              onPressed: () => Navigator.of(context).pop(false),
            ),
          ],
        ),
      ),
    );
  }
}
