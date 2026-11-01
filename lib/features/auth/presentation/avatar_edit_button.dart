import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/design.dart';
import '../../../core/photos/photo_picker.dart';
import '../../../core/photos/photo_spec.dart';
import '../../../core/photos/photo_widgets.dart';
import '../../../core/widgets/pressable.dart';
import '../../../core/widgets/user_avatar.dart';
import '../data/avatar_remote.dart';
import 'auth_providers.dart';

/// 프로필 사진. 누르면 앨범·카메라로 바꾸거나 카카오·구글 사진으로 되돌린다.
/// 바꾼 사진은 랭킹·리뷰·지도의 정복자 표시에도 그대로 쓰인다.
class AvatarEditButton extends ConsumerStatefulWidget {
  const AvatarEditButton({super.key, this.size = 88});

  final double size;

  @override
  ConsumerState<AvatarEditButton> createState() => _AvatarEditButtonState();
}

class _AvatarEditButtonState extends ConsumerState<AvatarEditButton> {
  bool _busy = false;

  Future<void> _change() async {
    final profile = ref.read(myProfileProvider).value;
    final choice = await showPhotoSourceSheet(
      context,
      resetLabel: (profile?.hasCustomAvatar ?? false)
          ? '카카오·구글 사진으로 되돌리기'
          : null,
    );
    if (choice == null || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    String? message;
    try {
      final remote = ref.read(avatarRemoteProvider);
      if (choice == PhotoMenuChoice.reset) {
        await remote.reset();
        message = '프로필 사진을 되돌렸어요';
      } else {
        final photos = await ref
            .read(photoPickerProvider)
            .pick(
              choice == PhotoMenuChoice.camera
                  ? PhotoSource.camera
                  : PhotoSource.gallery,
              PhotoSpec.avatar,
            );
        if (photos.isNotEmpty) {
          await remote.upload(photos.first);
          message = '프로필 사진을 바꿨어요';
        }
      }
      ref.invalidate(myProfileProvider);
    } catch (e) {
      debugPrint('[avatar] $e');
      message = '사진을 바꾸지 못했어요. 인터넷 연결을 확인해 주세요';
    }
    if (mounted) setState(() => _busy = false);
    if (message != null) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(myProfileProvider).value;
    return Pressable(
      onPressed: _busy ? null : _change,
      child: Stack(
        children: [
          UserAvatar(
            nickname: profile?.nickname ?? '등산객',
            imageUrl: profile?.avatarUrl,
            size: widget.size,
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppColors.background,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.divider),
              ),
              child: _busy
                  ? const SizedBox.square(
                      dimension: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(
                      Icons.photo_camera_rounded,
                      size: 14,
                      color: AppColors.textSecondary,
                      semanticLabel: '프로필 사진 바꾸기',
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
