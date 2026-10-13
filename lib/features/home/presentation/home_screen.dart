import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/bottom_action_bar.dart';
import '../../../core/widgets/confirm_sheet.dart';
import '../../../core/widgets/empty_view.dart';
import '../../recording/presentation/recording_controller.dart';
import '../../recording/presentation/start_recording.dart';

/// 홈 탭. 이후 이번 달 요약, 최근 기록이 들어간다.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkUnfinished());
  }

  /// 앱이 기록 중에 꺼졌다면 이어서 기록할지, 끝낼지 묻는다.
  Future<void> _checkUnfinished() async {
    final controller = ref.read(recordingControllerProvider.notifier);
    final unfinished = await controller.findUnfinished();
    if (unfinished == null || !mounted) return;

    final resume = await showConfirmSheet(
      context,
      title: '끝나지 않은 기록이 있어요',
      message:
          '${formatDateTime(unfinished.session.startedAt)}에 시작한 기록이 멈춰 있어요.\n'
          '이어서 기록할까요?',
      confirmLabel: '이어서 기록하기',
      cancelLabel: '여기까지 저장하기',
    );
    // 바깥을 눌러 닫으면 다음에 앱을 켤 때 다시 묻는다.
    if (resume == null || !mounted) return;

    controller.restore(unfinished);
    if (resume) {
      await controller.resume();
      if (mounted) context.go(AppRoutes.recording);
    } else {
      final id = await controller.finish();
      if (id != null && mounted) context.go(AppRoutes.recordingDone(id));
    }
  }

  Future<void> _start() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await startRecording(context, ref);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('홈')),
      body: const EmptyView(message: '홈 화면을 준비하고 있어요'),
      bottomNavigationBar: BottomActionBar(
        child: AppButton(label: '등산 기록 시작', onPressed: _busy ? null : _start),
      ),
    );
  }
}
