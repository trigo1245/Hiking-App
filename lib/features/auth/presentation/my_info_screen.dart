import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/design.dart';
import '../../../core/widgets/pressable.dart';
import '../../../core/widgets/skeleton_box.dart';
import '../domain/app_user.dart';
import '../domain/auth_failure.dart';
import 'auth_feedback.dart';
import 'auth_providers.dart';

/// 내 정보 탭: 닉네임, 로그인한 계정, 로그아웃.
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
