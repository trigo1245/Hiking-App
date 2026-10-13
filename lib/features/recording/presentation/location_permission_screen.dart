import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/design/design.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/bottom_action_bar.dart';
import '../data/location_service.dart';
import 'start_recording.dart';

/// 위치 권한이 없어서 기록을 시작하지 못했을 때, 이유와 다음 행동을 안내한다.
class LocationPermissionScreen extends ConsumerWidget {
  const LocationPermissionScreen({super.key, required this.access});

  final LocationAccess access;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = ref.read(locationServiceProvider);

    final (title, message) = switch (access) {
      LocationAccess.serviceDisabled => (
        '위치 기능이 꺼져 있어요',
        '등산 경로를 기록하려면 휴대폰의 위치 기능을 켜 주세요.',
      ),
      LocationAccess.approximateOnly => (
        '정확한 위치가 필요해요',
        '대략적인 위치로는 등산 경로와 거리를 정확히 기록할 수 없어요.\n'
            '설정에서 "정확한 위치 사용"을 켜 주세요.',
      ),
      LocationAccess.deniedForever => (
        '위치 권한이 필요해요',
        '등산 경로와 거리를 기록하려면 위치 권한이 필요해요.\n'
            '설정 > 권한 > 위치에서 "앱 사용 중에만 허용"을 선택해 주세요.',
      ),
      LocationAccess.denied || LocationAccess.granted => (
        '위치 권한이 필요해요',
        '등산 경로와 거리를 기록하려면 위치 권한이 필요해요.\n'
            '다시 시도하면 권한을 한 번 더 요청할게요.',
      ),
    };

    // 설정 앱에서 바꿔야 하는 경우에만 설정 버튼을 보여 준다.
    final Future<void> Function()? openSettings = switch (access) {
      LocationAccess.serviceDisabled => location.openLocationSettings,
      LocationAccess.approximateOnly ||
      LocationAccess.deniedForever => location.openAppSettings,
      LocationAccess.denied || LocationAccess.granted => null,
    };

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => context.go(AppRoutes.home),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.screenHorizontal,
          vertical: AppSpacing.lg,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: AppTypography.title),
            const SizedBox(height: AppSpacing.md),
            Text(
              message,
              style: AppTypography.body.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomActionBar(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (openSettings != null) ...[
              AppButton(label: '설정으로 이동', onPressed: openSettings),
              const SizedBox(height: AppSpacing.sm),
            ],
            AppButton(
              label: '다시 시도',
              variant: openSettings == null
                  ? AppButtonVariant.primary
                  : AppButtonVariant.secondary,
              onPressed: () => startRecording(context, ref),
            ),
          ],
        ),
      ),
    );
  }
}
