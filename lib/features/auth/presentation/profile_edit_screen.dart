import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/design.dart';
import '../../../core/utils/error_message.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/bottom_action_bar.dart';
import '../../../core/widgets/skeleton_box.dart';
import '../data/profile_remote.dart';
import '../domain/profile_rules.dart';
import 'auth_providers.dart';
import 'avatar_edit_button.dart';

/// 프로필 편집: 프로필 사진, 닉네임, 소개, 주 활동 지역.
/// 다른 사용자가 랭킹·리뷰에서 나를 누르면 보이는 정보다. (개인정보는 따로 관리한다)
class ProfileEditScreen extends ConsumerStatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  ConsumerState<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends ConsumerState<ProfileEditScreen> {
  final _nickname = TextEditingController();
  final _bio = TextEditingController();
  final _region = TextEditingController();
  bool _loaded = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    for (final c in [_nickname, _bio, _region]) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    _nickname.dispose();
    _bio.dispose();
    _region.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final before = ref.read(myProfileProvider).value;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final tag = await ref
          .read(profileRemoteProvider)
          .updateMyProfile(
            nickname: _nickname.text.trim(),
            bio: _bio.text.trim(),
            region: _region.text.trim(),
          );
      ref.invalidate(myProfileProvider);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              before?.nicknameTag != null && before!.nicknameTag != tag
                  ? '같은 닉네임이 있어 태그가 #$tag로 바뀌었어요'
                  : '프로필을 저장했어요',
            ),
          ),
        );
      if (mounted) context.pop();
    } catch (e) {
      debugPrint('[profile] $e');
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(errorMessage(e, failed: '저장하지 못했어요'))),
        );
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(myProfileProvider);
    final p = profile.value;
    if (p != null && !_loaded) {
      _loaded = true;
      _nickname.text = p.nickname;
      _bio.text = p.bio ?? '';
      _region.text = p.region ?? '';
    }
    final error = _nickname.text.isEmpty ? null : nicknameError(_nickname.text);
    final changed =
        p != null &&
        (_nickname.text.trim() != p.nickname ||
            _bio.text.trim() != (p.bio ?? '') ||
            _region.text.trim() != (p.region ?? ''));
    final canSave = !_busy && changed && nicknameError(_nickname.text) == null;

    return Scaffold(
      appBar: AppBar(title: const Text('프로필 편집')),
      body: p == null
          ? const Padding(
              padding: EdgeInsets.all(AppSpacing.screenHorizontal),
              child: SkeletonBox(width: double.infinity, height: 240),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenHorizontal,
                AppSpacing.lg,
                AppSpacing.screenHorizontal,
                AppSpacing.xxl,
              ),
              children: [
                const Center(child: AvatarEditButton()),
                const SizedBox(height: AppSpacing.md),
                Text(
                  '다른 사람이 랭킹·리뷰에서 나를 누르면 이 정보가 보여요',
                  textAlign: TextAlign.center,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxl),
                const Text('닉네임', style: AppTypography.subtitle),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: _nickname,
                  maxLength: 10,
                  style: AppTypography.body,
                  decoration: InputDecoration(
                    suffixText: p.nicknameTag == null
                        ? null
                        : '#${p.nicknameTag}',
                    errorText: error,
                    helperText: '2~10자 한글·영문·숫자. 같은 닉네임이 이미 있으면 태그가 바뀌어요',
                    helperMaxLines: 2,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                const Text('소개 (선택)', style: AppTypography.subtitle),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: _bio,
                  maxLength: bioMaxLength,
                  minLines: 3,
                  maxLines: 6,
                  style: AppTypography.body,
                  decoration: const InputDecoration(
                    hintText: '어떤 산행을 좋아하는지 소개해 주세요',
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                const Text('주 활동 지역 (선택)', style: AppTypography.subtitle),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: _region,
                  maxLength: regionMaxLength,
                  style: AppTypography.body,
                  decoration: const InputDecoration(
                    hintText: '예: 부산 금정구, 주말엔 경남 일대',
                  ),
                ),
              ],
            ),
      bottomNavigationBar: BottomActionBar(
        child: AppButton(
          label: _busy ? '저장하는 중…' : '저장하기',
          onPressed: canSave ? _save : null,
        ),
      ),
    );
  }
}
