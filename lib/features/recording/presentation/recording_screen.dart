import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/design/design.dart';
import '../../../core/utils/clock.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/bottom_action_bar.dart';
import '../../../core/widgets/confirm_sheet.dart';
import '../../../core/widgets/metric_text.dart';
import 'recording_controller.dart';

/// 기록 중 화면: 기록 시간(가장 크게), 거리, 현재 고도, 누적 상승고도.
class RecordingScreen extends ConsumerStatefulWidget {
  const RecordingScreen({super.key});

  @override
  ConsumerState<RecordingScreen> createState() => _RecordingScreenState();
}

class _RecordingScreenState extends ConsumerState<RecordingScreen> {
  /// 기록 시간을 1초마다 다시 그린다.
  late final Timer _ticker;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker.cancel();
    super.dispose();
  }

  Future<void> _run(Future<void> Function(RecordingController) action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action(ref.read(recordingControllerProvider.notifier));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmFinish() async {
    final confirmed = await showConfirmSheet(
      context,
      title: '기록을 끝낼까요?',
      message: '지금까지의 기록을 저장할게요.',
      confirmLabel: '끝내기',
      cancelLabel: '계속 기록하기',
    );
    if (confirmed != true || !mounted) return;
    await _run((controller) async {
      final id = await controller.finish();
      if (id != null && mounted) context.go(AppRoutes.recordingDone(id));
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(recordingControllerProvider);
    final session = state.session;
    // 기록이 끝나 다른 화면으로 넘어가는 중
    if (session == null) return const Scaffold();

    final now = ref.read(clockProvider)();
    final stats = state.stats;

    return PopScope(
      // 실수로 뒤로 가서 기록이 끊기지 않게 막는다.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(content: Text('기록을 끝내려면 종료를 눌러 주세요')));
      },
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.screenHorizontal,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: AppSpacing.xxl),
                _StatusLine(state: state),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  formatClock(session.activeDuration(now)),
                  style: AppTypography.display,
                ),
                const SizedBox(height: AppSpacing.xxl),
                Row(
                  children: [
                    Expanded(
                      child: MetricText(
                        label: '거리',
                        value: formatKm(stats.distanceM),
                        unit: 'km',
                      ),
                    ),
                    Expanded(
                      child: MetricText(
                        label: '현재 고도',
                        value: formatMeters(state.currentAltitude),
                        unit: 'm',
                      ),
                    ),
                    Expanded(
                      child: MetricText(
                        label: '오른 높이',
                        value: formatMeters(stats.elevationGainM),
                        unit: 'm',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xxl),
                const Expanded(child: _MapPlaceholder()),
              ],
            ),
          ),
        ),
        bottomNavigationBar: BottomActionBar(
          child: Row(
            children: [
              Expanded(
                child: AppButton(
                  label: state.isPaused ? '다시 시작' : '일시정지',
                  variant: AppButtonVariant.secondary,
                  onPressed: _busy
                      ? null
                      : () => _run(
                          (c) => state.isPaused ? c.resume() : c.pause(),
                        ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: AppButton(
                  label: '종료',
                  onPressed: _busy ? null : _confirmFinish,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusLine extends StatelessWidget {
  const _StatusLine({required this.state});

  final RecordingState state;

  @override
  Widget build(BuildContext context) {
    final (color, text) = switch (state) {
      RecordingState(isPaused: true) => (AppColors.textTertiary, '일시정지했어요'),
      RecordingState(signalLost: true) => (
        AppColors.danger,
        '위치 신호를 받지 못하고 있어요',
      ),
      RecordingState(hasFix: false) => (AppColors.textTertiary, '위치를 찾고 있어요'),
      _ => (AppColors.success, '기록 중이에요'),
    };
    return Row(
      children: [
        Container(
          width: AppSpacing.sm,
          height: AppSpacing.sm,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(text, style: AppTypography.body.copyWith(color: color)),
      ],
    );
  }
}

/// 지도는 이후 단계에서 넣는다. 지금은 자리만 잡아 둔다.
class _MapPlaceholder extends StatelessWidget {
  const _MapPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.backgroundGrouped,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: const Text('지도는 준비 중이에요', style: AppTypography.caption),
    );
  }
}
