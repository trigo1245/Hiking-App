import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/design/design.dart';
import '../../../core/photos/photo_picker.dart';
import '../../../core/photos/photo_spec.dart';
import '../../../core/photos/photo_widgets.dart';
import '../../../core/widgets/pressable.dart';
import '../../../core/widgets/skeleton_box.dart';
import '../../subscription/data/subscription_remote.dart';
import '../data/activity_photo_remote.dart';
import '../domain/activity_summary.dart';

/// 기록 상세의 사진 칸. 본인만 보고, 사진 올리기는 프리미엄 구독자만 한다.
/// 기록이 서버에 올라가 있어야 사진을 붙일 수 있다(사진은 서버에만 있다).
class ActivityPhotosSection extends ConsumerStatefulWidget {
  const ActivityPhotosSection({super.key, required this.summary});

  final ActivitySummary summary;

  @override
  ConsumerState<ActivityPhotosSection> createState() =>
      _ActivityPhotosSectionState();
}

class _ActivityPhotosSectionState extends ConsumerState<ActivityPhotosSection> {
  bool _busy = false;

  String get _id => widget.summary.id;

  void _say(String text) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));

  Future<void> _add(int existing) async {
    const spec = PhotoSpec.activity;
    final choice = await showPhotoSourceSheet(context);
    if (choice == null || !mounted) return;
    setState(() => _busy = true);
    var added = 0;
    try {
      final photos = await ref
          .read(photoPickerProvider)
          .pick(
            choice == PhotoMenuChoice.camera
                ? PhotoSource.camera
                : PhotoSource.gallery,
            spec,
            limit: spec.remaining(existing),
          );
      final remote = ref.read(activityPhotoRemoteProvider);
      for (final jpeg in photos) {
        await remote.add(_id, jpeg);
        added++;
      }
      if (added > 0) _say('사진 $added장을 올렸어요');
    } catch (e) {
      debugPrint('[photo] $e');
      _say(
        added > 0
            ? '사진 $added장만 올렸어요. 인터넷 연결을 확인해 주세요'
            : '사진을 올리지 못했어요. 인터넷 연결을 확인해 주세요',
      );
    }
    ref.invalidate(activityPhotosProvider(_id));
    if (mounted) setState(() => _busy = false);
  }

  Future<bool> _delete(PhotoItem photo) async {
    try {
      await ref.read(activityPhotoRemoteProvider).delete(photo);
      ref.invalidate(activityPhotosProvider(_id));
      _say('사진을 지웠어요');
      return true;
    } catch (e) {
      debugPrint('[photo] $e');
      _say('사진을 지우지 못했어요. 인터넷 연결을 확인해 주세요');
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    const spec = PhotoSpec.activity;
    final premium = ref.watch(isPremiumProvider);
    final uploaded = widget.summary.uploadStatus == UploadStatus.done;
    final photos = uploaded
        ? ref.watch(activityPhotosProvider(_id))
        : const AsyncData(<PhotoItem>[]);
    final list = photos.value ?? const <PhotoItem>[];
    final canAdd = premium && uploaded && spec.remaining(list.length) > 0;

    final String? note;
    if (!premium) {
      note = '산행 사진 올리기는 프리미엄에서 할 수 있어요';
    } else if (!uploaded) {
      note = '기록이 서버에 올라간 뒤 사진을 붙일 수 있어요';
    } else if (photos.hasError) {
      note = '인터넷에 연결되면 사진을 볼 수 있어요';
    } else {
      note = null;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('사진', style: AppTypography.subtitle),
            const SizedBox(width: AppSpacing.sm),
            if (list.isNotEmpty)
              Text(
                '${list.length} / ${spec.maxCount}',
                style: AppTypography.caption.copyWith(
                  color: AppColors.textTertiary,
                ),
              ),
            const Spacer(),
            Text(
              '나만 볼 수 있어요',
              style: AppTypography.caption.copyWith(
                color: AppColors.textTertiary,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        if (photos.isLoading && list.isEmpty)
          const SkeletonBox(width: 88, height: 88)
        else if (list.isNotEmpty || canAdd || _busy)
          PhotoStrip(
            images: [for (final p in list) NetworkImage(p.url)],
            busy: _busy,
            onAdd: canAdd ? () => _add(list.length) : null,
            onTap: (i) => openPhotoViewer(
              context,
              images: [for (final p in list) NetworkImage(p.url)],
              initial: i,
              onDelete: (index) => _delete(list[index]),
            ),
          ),
        if (note != null) ...[
          if (list.isNotEmpty) const SizedBox(height: AppSpacing.sm),
          Pressable(
            onPressed: premium ? null : () => context.push(AppRoutes.premium),
            child: Text(
              note,
              style: AppTypography.caption.copyWith(
                color: premium ? AppColors.textSecondary : AppColors.primary,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
