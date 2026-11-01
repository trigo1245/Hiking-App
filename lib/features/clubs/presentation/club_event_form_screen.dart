import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/design.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/bottom_action_bar.dart';
import '../../../core/widgets/pressable.dart';
import '../data/club_remote.dart';
import '../domain/club.dart';
import 'club_detail_screen.dart';
import 'club_format.dart';

/// 일정 만들기 (클럽장): 제목, 날짜·시간, 장소(선택), 메모(선택). 회원은 참석·불참으로 답한다.
class ClubEventFormScreen extends ConsumerStatefulWidget {
  const ClubEventFormScreen({super.key, required this.clubId});

  final String clubId;

  /// 만들었으면 true
  static Future<bool?> open(BuildContext context, String clubId) =>
      Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => ClubEventFormScreen(clubId: clubId)),
      );

  @override
  ConsumerState<ClubEventFormScreen> createState() =>
      _ClubEventFormScreenState();
}

class _ClubEventFormScreenState extends ConsumerState<ClubEventFormScreen> {
  final _title = TextEditingController();
  final _place = TextEditingController();
  final _memo = TextEditingController();
  DateTime? _startsAt;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _title.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _title.dispose();
    _place.dispose();
    _memo.dispose();
    super.dispose();
  }

  Future<void> _pickTime() async {
    final now = DateTime.now();
    final base = _startsAt ?? DateTime(now.year, now.month, now.day + 1, 8);
    final day = await showDatePicker(
      context: context,
      initialDate: base,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (day == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(base),
    );
    if (time == null) return;
    setState(
      () => _startsAt = DateTime(
        day.year,
        day.month,
        day.day,
        time.hour,
        time.minute,
      ),
    );
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    final ok = await runClubAction(
      context,
      () => ref
          .read(clubRemoteProvider)
          .createEvent(
            widget.clubId,
            title: _title.text.trim(),
            startsAt: _startsAt!,
            place: _place.text.trim(),
            memo: _memo.text.trim(),
          ),
      done: '일정을 만들었어요',
    );
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop(true);
    } else {
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canSave =
        !_busy && _title.text.trim().isNotEmpty && _startsAt != null;
    return Scaffold(
      appBar: AppBar(title: const Text('일정 만들기')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenHorizontal,
          AppSpacing.sm,
          AppSpacing.screenHorizontal,
          AppSpacing.xxl,
        ),
        children: [
          const Text('제목', style: AppTypography.subtitle),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _title,
            maxLength: clubEventTitleMaxLength,
            style: AppTypography.body,
            decoration: const InputDecoration(hintText: '예: 11월 정기 산행'),
          ),
          const SizedBox(height: AppSpacing.lg),
          const Text('날짜·시간', style: AppTypography.subtitle),
          const SizedBox(height: AppSpacing.sm),
          Pressable(
            onPressed: _pickTime,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: AppColors.backgroundGrouped,
                borderRadius: BorderRadius.circular(AppRadius.input),
              ),
              child: Text(
                _startsAt == null
                    ? '날짜와 시간을 골라 주세요'
                    : formatEventTime(_startsAt!),
                style: AppTypography.body.copyWith(
                  color: _startsAt == null
                      ? AppColors.textTertiary
                      : AppColors.textPrimary,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          const Text('모이는 곳 (선택)', style: AppTypography.subtitle),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _place,
            maxLength: clubEventPlaceMaxLength,
            style: AppTypography.body,
            decoration: const InputDecoration(hintText: '예: 범어사 매표소 앞'),
          ),
          const SizedBox(height: AppSpacing.lg),
          const Text('메모 (선택)', style: AppTypography.subtitle),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _memo,
            maxLength: clubEventMemoMaxLength,
            minLines: 2,
            maxLines: 5,
            style: AppTypography.body,
            decoration: const InputDecoration(hintText: '준비물, 코스 등'),
          ),
        ],
      ),
      bottomNavigationBar: BottomActionBar(
        child: AppButton(
          label: _busy ? '만드는 중…' : '일정 만들기',
          onPressed: canSave ? _save : null,
        ),
      ),
    );
  }
}
