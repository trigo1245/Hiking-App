import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/design/design.dart';
import '../../../core/photos/photo_picker.dart';
import '../../../core/photos/photo_spec.dart';
import '../../../core/photos/photo_widgets.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/bottom_action_bar.dart';
import '../../../core/widgets/pressable.dart';
import '../../../core/widgets/skeleton_box.dart';
import '../data/club_remote.dart';
import '../domain/club.dart';
import 'club_avatar.dart';
import 'club_detail_screen.dart';

/// 동호회 만들기([clubId]가 null) / 정보 수정(클럽장).
/// 만들 때는 시연용 개설비를 한 번 결제한 것으로 하고 만든다(실제 결제 없음).
class ClubFormScreen extends ConsumerStatefulWidget {
  const ClubFormScreen({super.key, this.clubId});

  final String? clubId;

  @override
  ConsumerState<ClubFormScreen> createState() => _ClubFormScreenState();
}

class _ClubFormScreenState extends ConsumerState<ClubFormScreen> {
  final _name = TextEditingController();
  final _bio = TextEditingController();
  final _region = TextEditingController();
  Uint8List? _photo;
  bool _loaded = false;
  bool _busy = false;

  bool get _creating => widget.clubId == null;

  @override
  void initState() {
    super.initState();
    _name.addListener(() => setState(() {}));
    _loaded = _creating;
  }

  @override
  void dispose() {
    _name.dispose();
    _bio.dispose();
    _region.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final choice = await showPhotoSourceSheet(context);
    if (choice == null || !mounted) return;
    final photos = await ref
        .read(photoPickerProvider)
        .pick(
          choice == PhotoMenuChoice.camera
              ? PhotoSource.camera
              : PhotoSource.gallery,
          PhotoSpec.avatar,
        );
    if (photos.isNotEmpty && mounted) setState(() => _photo = photos.first);
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    final remote = ref.read(clubRemoteProvider);
    String? id = widget.clubId;
    final ok = await runClubAction(context, () async {
      if (_creating) {
        id = await remote.createClub(
          name: _name.text.trim(),
          bio: _bio.text.trim(),
          region: _region.text.trim(),
        );
      } else {
        await remote.updateClub(
          id!,
          name: _name.text.trim(),
          bio: _bio.text.trim(),
          region: _region.text.trim(),
        );
      }
    }, done: _creating ? '동호회를 만들었어요' : '동호회 정보를 저장했어요');
    if (!ok) {
      if (mounted) setState(() => _busy = false);
      return;
    }
    // 사진은 클럽이 생긴 뒤에 올린다. 실패해도 클럽은 그대로 두고 알린다.
    if (_photo != null && mounted) {
      await runClubAction(context, () => remote.setClubPhoto(id!, _photo!));
    }
    refreshClub(ref, id!);
    if (!mounted) return;
    if (_creating) {
      context.go(AppRoutes.clubs);
    } else {
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final clubId = widget.clubId;
    final existing = clubId == null
        ? null
        : ref.watch(clubDetailProvider(clubId)).value;
    if (existing != null && !_loaded) {
      _loaded = true;
      _name.text = existing.name;
      _bio.text = existing.bio ?? '';
      _region.text = existing.region ?? '';
    }
    final nameError = _name.text.isEmpty ? null : clubNameError(_name.text);
    final canSave = !_busy && _loaded && clubNameError(_name.text) == null;

    return Scaffold(
      appBar: AppBar(title: Text(_creating ? '동호회 만들기' : '동호회 정보 수정')),
      body: !_loaded
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
                Center(
                  child: Pressable(
                    onPressed: _busy ? null : _pickPhoto,
                    child: Stack(
                      children: [
                        _photo != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(88 * 0.28),
                                child: Image.memory(
                                  _photo!,
                                  width: 88,
                                  height: 88,
                                  fit: BoxFit.cover,
                                ),
                              )
                            : ClubAvatar(
                                name: _name.text.trim(),
                                photoUrl: existing?.photoUrl,
                                size: 88,
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
                            child: const Icon(
                              Icons.photo_camera_rounded,
                              size: 16,
                              color: AppColors.textSecondary,
                              semanticLabel: '대표 사진 고르기',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  '대표 사진 (선택) · 동호회 목록과 정복자 표시에 쓰여요',
                  textAlign: TextAlign.center,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxl),
                const Text('동호회 이름', style: AppTypography.subtitle),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: _name,
                  maxLength: 20,
                  style: AppTypography.body,
                  decoration: InputDecoration(
                    hintText: '예: 금정산 새벽산행',
                    errorText: nameError,
                    helperText: '2~20자. 다른 동호회와 같은 이름은 쓸 수 없어요',
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                const Text('소개 (선택)', style: AppTypography.subtitle),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: _bio,
                  maxLength: clubBioMaxLength,
                  minLines: 3,
                  maxLines: 6,
                  style: AppTypography.body,
                  decoration: const InputDecoration(
                    hintText: '어떤 동호회인지, 얼마나 자주 모이는지 알려 주세요',
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                const Text('주 활동 지역 (선택)', style: AppTypography.subtitle),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: _region,
                  maxLength: clubRegionMaxLength,
                  style: AppTypography.body,
                  decoration: const InputDecoration(
                    hintText: '예: 부산 금정구, 주말엔 경남 일대',
                  ),
                ),
                if (_creating) ...[
                  const SizedBox(height: AppSpacing.xl),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    decoration: BoxDecoration(
                      color: AppColors.backgroundGrouped,
                      borderRadius: BorderRadius.circular(AppRadius.input),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text('개설비', style: AppTypography.body),
                            const Spacer(),
                            Text(
                              clubOpeningPriceLabel,
                              style: AppTypography.subtitle,
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          '만들 때 한 번만 내요. 회원 가입은 무료이고 최대 $clubMaxMembers명까지 받을 수 있어요.\n'
                          '시연용 결제라 실제로 돈이 나가지 않아요.',
                          style: AppTypography.caption.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
      bottomNavigationBar: BottomActionBar(
        child: AppButton(
          label: _busy
              ? (_creating ? '만드는 중…' : '저장하는 중…')
              : _creating
              ? '$clubOpeningPriceLabel 결제하고 만들기'
              : '저장하기',
          onPressed: canSave ? _save : null,
        ),
      ),
    );
  }
}
