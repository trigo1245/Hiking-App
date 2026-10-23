import 'package:flutter/material.dart';

import '../../../core/design/design.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/pressable.dart';
import '../domain/activity_deletion.dart';

/// 기록 지우기 확인 창. 주의사항을 보여 주고, "위 내용을 확인했어요"를 눌러야 삭제 버튼이 켜진다.
/// 지우기로 하면 true, 취소하거나 바깥을 눌러 닫으면 false/null.
Future<bool?> showDeleteActivitySheet(
  BuildContext context, {
  required String title,
  required List<DeletionNotice> notices,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.background,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.card)),
    ),
    builder: (context) => _DeleteActivitySheet(title: title, notices: notices),
  );
}

class _DeleteActivitySheet extends StatefulWidget {
  const _DeleteActivitySheet({required this.title, required this.notices});

  final String title;
  final List<DeletionNotice> notices;

  @override
  State<_DeleteActivitySheet> createState() => _DeleteActivitySheetState();
}

class _DeleteActivitySheetState extends State<_DeleteActivitySheet> {
  bool _acknowledged = false;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ConstrainedBox(
        // 주의사항이 많아도 화면을 넘지 않게 하고, 안쪽만 스크롤한다.
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.85,
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('이 기록을 지울까요?', style: AppTypography.subtitle),
              const SizedBox(height: AppSpacing.xs),
              Text(
                widget.title,
                style: AppTypography.body.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      for (final (i, n) in widget.notices.indexed)
                        _NoticeRow(notice: n, important: i == 0),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Pressable(
                onPressed: () => setState(() => _acknowledged = !_acknowledged),
                child: Row(
                  children: [
                    Icon(
                      _acknowledged
                          ? Icons.check_box_rounded
                          : Icons.check_box_outline_blank_rounded,
                      color: _acknowledged
                          ? AppColors.primary
                          : AppColors.textTertiary,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    const Text('위 내용을 확인했어요', style: AppTypography.body),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              AppButton(
                label: '삭제하기',
                variant: AppButtonVariant.danger,
                onPressed: _acknowledged
                    ? () => Navigator.of(context).pop(true)
                    : null,
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
      ),
    );
  }
}

class _NoticeRow extends StatelessWidget {
  const _NoticeRow({required this.notice, required this.important});

  final DeletionNotice notice;
  final bool important;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 상태 색은 아이콘과 함께 쓴다 (색만으로 구분하지 않기).
          Icon(
            important
                ? Icons.warning_amber_rounded
                : Icons.info_outline_rounded,
            size: 20,
            color: important ? AppColors.danger : AppColors.textSecondary,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  notice.title,
                  style: AppTypography.body.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(notice.detail, style: AppTypography.caption),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
