import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../data/location_service.dart';
import 'recording_controller.dart';

/// "등산 기록 시작" 버튼과 권한 안내 화면의 "다시 시도"가 함께 쓰는 시작 흐름.
/// 권한이 있으면 기록 화면으로, 없으면 이유를 설명하는 화면으로 보낸다.
Future<void> startRecording(BuildContext context, WidgetRef ref) async {
  final access = await ref.read(recordingControllerProvider.notifier).start();
  if (!context.mounted) return;
  if (access == LocationAccess.granted) {
    context.go(AppRoutes.recording);
  } else {
    context.go(AppRoutes.locationPermission(access));
  }
}
