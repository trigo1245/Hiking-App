import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/design.dart';
import '../../../core/widgets/app_button.dart';
import '../data/auth_repository.dart';
import '../domain/auth_failure.dart';
import 'auth_feedback.dart';
import 'auth_providers.dart';

/// 로그인하지 않았을 때 보이는 화면.
/// 로그인에 성공하면 라우터가 알아서 홈으로 보낸다.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  bool _busy = false;

  Future<void> _run(Future<void> Function(AuthRepository) action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action(ref.read(authRepositoryProvider));
    } on AuthFailure catch (failure) {
      if (mounted) showAuthFailure(context, failure);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authFailuresProvider, (_, next) {
      final failure = next.value;
      if (failure != null) showAuthFailure(context, failure);
    });

    // 처리 중에는 모든 버튼을 막는다.
    VoidCallback? action(Future<void> Function(AuthRepository) run) =>
        _busy ? null : () => _run(run);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenHorizontal,
            AppSpacing.xxxl * 2,
            AppSpacing.screenHorizontal,
            AppSpacing.xl,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('산에 오른 기록을\n차곡차곡 남겨요', style: AppTypography.title),
              const SizedBox(height: AppSpacing.md),
              Text(
                '로그인하면 휴대폰을 바꿔도 기록을 이어서 볼 수 있어요',
                style: AppTypography.body.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const Spacer(),
              AppButton(
                label: '카카오로 시작하기',
                variant: AppButtonVariant.kakao,
                onPressed: action((repo) => repo.signInWithKakao()),
              ),
              const SizedBox(height: AppSpacing.sm),
              AppButton(
                label: '구글로 시작하기',
                variant: AppButtonVariant.secondary,
                onPressed: action((repo) => repo.signInWithGoogle()),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
