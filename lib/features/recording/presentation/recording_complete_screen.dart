import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/design/design.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/bottom_action_bar.dart';
import '../../../core/widgets/metric_text.dart';
import '../../../core/widgets/skeleton_box.dart';
import '../../achievements/domain/achievements.dart';
import '../../achievements/presentation/achievements_providers.dart';
import '../../achievements/presentation/new_badges_sheet.dart';
import '../../activities/domain/activity_summary.dart';
import '../../activities/domain/hike_check.dart';
import '../../activities/presentation/activities_providers.dart';
import '../../courses/data/course_repository.dart';
import '../data/recording_repository.dart';

final activitySummaryProvider = FutureProvider.family<ActivitySummary, String>(
  (ref, id) => ref.read(recordingRepositoryProvider).loadSummary(id),
);

/// 기록 완료 화면: 요약 수치와 제목 입력.
/// 기록은 종료할 때 이미 기본 제목으로 저장돼 있어서, 여기서는 제목만 바꾼다.
class RecordingCompleteScreen extends ConsumerStatefulWidget {
  const RecordingCompleteScreen({super.key, required this.activityId});

  final String activityId;

  @override
  ConsumerState<RecordingCompleteScreen> createState() =>
      _RecordingCompleteScreenState();
}

class _RecordingCompleteScreenState
    extends ConsumerState<RecordingCompleteScreen> {
  final _title = TextEditingController();
  bool _titleLoaded = false;
  bool _saving = false;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  /// 산행이 아닌 것 같으면 저장 전에 경고한다. 계속 저장할지(true), 그만둘지(false).
  /// "저장하지 않기"를 고르면 이 기록을 지우고 홈으로 간다.
  Future<bool> _confirmHike(ActivitySummary summary) async {
    final bool hike;
    try {
      final points = await ref
          .read(recordingRepositoryProvider)
          .loadPoints(summary.id);
      final courses = await ref.read(courseRepositoryProvider).watchAll().first;
      hike = HikeCheck.isHike(
        distanceM: summary.distanceM,
        elevationGainM: summary.elevationGainM,
        track: points,
        courses: courses,
      );
    } catch (e) {
      debugPrint('[hike] $e');
      return true; // 확인하지 못하면 막지 않는다.
    }
    if (hike || !mounted) return true;

    final choice = await showModalBottomSheet<_NotHikeChoice>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      showDragHandle: true,
      builder: (_) => const _NotHikeSheet(),
    );
    if (choice != _NotHikeChoice.discard || !mounted) {
      return choice == _NotHikeChoice.save;
    }

    // 저장하지 않기: 이미 서버에 올라갔으면 서버에서 먼저 지운다 (기기 간 동기화로 되살아나지 않게).
    final actions = ref.read(uploadActionsProvider);
    final messenger = ScaffoldMessenger.of(context);
    try {
      if (summary.uploadStatus == UploadStatus.done) {
        await actions.deleteFromServer(summary.id);
      }
      await actions.deleteFromDevice(summary.id);
    } catch (e) {
      debugPrint('[hike] 지우기: $e');
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('지우지 못했어요. 인터넷에 연결된 뒤 다시 시도해 주세요')),
        );
      return false;
    }
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('기록을 저장하지 않았어요')));
    if (mounted) context.go(AppRoutes.home);
    return false;
  }

  Future<void> _save(ActivitySummary summary) async {
    if (_saving) return;
    setState(() => _saving = true);
    if (!await _confirmHike(summary)) {
      if (mounted) setState(() => _saving = false);
      return;
    }
    final title = _title.text.trim();
    await ref
        .read(recordingRepositoryProvider)
        .updateTitle(summary.id, title.isEmpty ? summary.title : title);
    // 새 배지 확인: 이 기록이 없을 때와 있을 때의 업적을 비교한다.
    final checker = ref.read(achievementCheckerProvider);
    final server = await checker.fetchServer(
      timeout: const Duration(seconds: 4),
    );
    final (before, after) = await checker.deviceBeforeAfter(summary.id, server);
    // 저장하면 바로 서버 업로드를 시도한다.
    // 실패하면 "업로드 대기"로 남고, 앱을 다시 열 때 자동으로 재시도한다.
    final uploaded = ref
        .read(uploadActionsProvider)
        .upload(summary.id)
        .catchError((_) => false);
    final gainedNow = Achievements.gained(before, after);

    // 완등·정복 배지는 업로드와 코스 완주 판정이 끝나야 알 수 있다.
    Future<List<EarnedBadge>> gainedLater() async {
      if (!await uploaded) return const [];
      final shown = {for (final e in gainedNow) e.key};
      return [
        for (final e in Achievements.gained(before, await checker.refreshed()))
          if (!shown.contains(e.key)) e,
      ];
    }

    if (!mounted) return;
    if (gainedNow.isNotEmpty) {
      await showNewBadges(context, initial: gainedNow, later: gainedLater());
    } else {
      // 바로 알 수 있는 새 배지가 없으면 업로드를 잠깐 기다려 완등·정복 배지만 확인한다.
      final later = await gainedLater()
          .timeout(const Duration(seconds: 4))
          .catchError((_) => const <EarnedBadge>[]);
      if (later.isNotEmpty && mounted) {
        await showNewBadges(context, initial: later);
      }
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('기록을 저장했어요')));
    context.go(AppRoutes.home);
  }

  @override
  Widget build(BuildContext context) {
    final summary = ref.watch(activitySummaryProvider(widget.activityId));
    final data = summary.value;
    if (data != null && !_titleLoaded) {
      _title.text = data.title;
      _titleLoaded = true;
    }

    return PopScope(
      // 뒤로 가기도 "저장하기"와 같게 처리한다.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && data != null) _save(data);
      },
      child: Scaffold(
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenHorizontal,
              AppSpacing.xxxl,
              AppSpacing.screenHorizontal,
              AppSpacing.xl,
            ),
            children: [
              const Text('수고했어요!', style: AppTypography.title),
              const SizedBox(height: AppSpacing.xs),
              Text(
                data == null ? '' : formatDateTime(data.startedAt),
                style: AppTypography.body.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),
              if (data == null)
                const SkeletonBox(width: double.infinity, height: 200)
              else
                _SummaryCard(summary: data),
              const SizedBox(height: AppSpacing.xxl),
              const Text('제목', style: AppTypography.caption),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: _title,
                style: AppTypography.body,
                textInputAction: TextInputAction.done,
                maxLength: 40,
                decoration: const InputDecoration(counterText: ''),
              ),
            ],
          ),
        ),
        bottomNavigationBar: BottomActionBar(
          child: AppButton(
            label: _saving ? '저장하는 중…' : '저장하기',
            onPressed: data == null || _saving ? null : () => _save(data),
          ),
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.summary});

  final ActivitySummary summary;

  @override
  Widget build(BuildContext context) {
    Widget cell(String label, String value, String unit) => Expanded(
      child: MetricText(label: label, value: value, unit: unit),
    );

    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.backgroundGrouped,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Column(
        children: [
          Row(
            children: [
              cell('거리', formatKm(summary.distanceM), 'km'),
              cell('오른 높이', formatMeters(summary.elevationGainM), 'm'),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          Row(
            children: [
              cell('전체 시간', formatClock(summary.elapsed), ''),
              cell('움직인 시간', formatClock(summary.moving), ''),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          Row(
            children: [
              cell('최고 고도', formatMeters(summary.maxAltitudeM), 'm'),
              const Spacer(),
            ],
          ),
        ],
      ),
    );
  }
}

enum _NotHikeChoice { save, discard }

/// 산행이 아닌 것 같을 때 저장 전 경고. 시트를 닫으면 아무것도 하지 않고 완료 화면에 남는다.
class _NotHikeSheet extends StatelessWidget {
  const _NotHikeSheet();

  @override
  Widget build(BuildContext context) => SafeArea(
    child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenHorizontal,
        0,
        AppSpacing.screenHorizontal,
        AppSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            size: 40,
            color: AppColors.danger,
          ),
          const SizedBox(height: AppSpacing.md),
          const Text(
            '산행이 아닌 것 같아요!',
            textAlign: TextAlign.center,
            style: AppTypography.title,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '저장하면 통계가 나빠질 수 있고, 악용이라고 판단되면 제재를 당할 수 있어요.',
            textAlign: TextAlign.center,
            style: AppTypography.body.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '등록된 등산 코스 근처를 지나지 않았고, 오른 높이도 적어요.',
            textAlign: TextAlign.center,
            style: AppTypography.caption.copyWith(
              color: AppColors.textTertiary,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          AppButton(
            label: '저장하지 않기',
            onPressed: () => Navigator.of(context).pop(_NotHikeChoice.discard),
          ),
          const SizedBox(height: AppSpacing.sm),
          AppButton(
            label: '그래도 저장하기',
            variant: AppButtonVariant.secondary,
            onPressed: () => Navigator.of(context).pop(_NotHikeChoice.save),
          ),
        ],
      ),
    ),
  );
}
