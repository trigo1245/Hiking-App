import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/design.dart';
import '../../../core/photos/photo_picker.dart';
import '../../../core/photos/photo_spec.dart';
import '../../../core/photos/photo_widgets.dart';
import '../../../core/utils/error_message.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/bottom_action_bar.dart';
import '../../../core/widgets/pressable.dart';
import '../../../core/widgets/skeleton_box.dart';
import '../data/shop_remote.dart';
import '../domain/shop.dart';
import 'shop_widgets.dart';

/// 상품 리뷰 쓰기·고치기: 별점, 후기(선택), 사진 3장(선택, 모두에게 공개).
/// 배송이 끝난 주문이 있어야 쓸 수 있다(서버도 다시 검사한다).
class ProductReviewScreen extends ConsumerStatefulWidget {
  const ProductReviewScreen({super.key, required this.productId});

  final String productId;

  @override
  ConsumerState<ProductReviewScreen> createState() =>
      _ProductReviewScreenState();
}

class _ProductReviewScreenState extends ConsumerState<ProductReviewScreen> {
  int? _rating;
  final _comment = TextEditingController();
  bool _loaded = false;
  bool _busy = false;

  /// 이미 올린 사진 중 남겨 둘 것, 뺄 것, 새로 고른 사진(저장할 때 올린다)
  final _kept = <PhotoItem>[];
  final _removed = <PhotoItem>[];
  final _added = <Uint8List>[];

  int get _photoCount => _kept.length + _added.length;

  List<ImageProvider> get _photoImages => [
    for (final p in _kept) NetworkImage(p.url),
    for (final b in _added) MemoryImage(b),
  ];

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _pickPhotos() async {
    const spec = PhotoSpec.review;
    final choice = await showPhotoSourceSheet(context);
    if (choice == null || !mounted) return;
    try {
      final photos = await ref
          .read(photoPickerProvider)
          .pick(
            choice == PhotoMenuChoice.camera
                ? PhotoSource.camera
                : PhotoSource.gallery,
            spec,
            limit: spec.remaining(_photoCount),
          );
      if (mounted) setState(() => _added.addAll(photos));
    } catch (e) {
      debugPrint('[photo] $e');
      _snack('사진을 가져오지 못했어요');
    }
  }

  void _removePhoto(int i) => setState(() {
    if (i < _kept.length) {
      _removed.add(_kept.removeAt(i));
    } else {
      _added.removeAt(i - _kept.length);
    }
  });

  void _refresh() => ref
    ..invalidate(productsProvider)
    ..invalidate(productReviewsProvider)
    ..invalidate(myProductReviewProvider(widget.productId))
    ..invalidate(myOrdersProvider);

  Future<void> _save() async {
    if (_busy || _rating == null) return;
    setState(() => _busy = true);
    try {
      final remote = ref.read(shopRemoteProvider);
      await remote.saveMyReview(
        widget.productId,
        _rating!,
        _comment.text.trim(),
      );
      // 사진은 리뷰가 저장된 뒤에 붙인다. (사진은 리뷰에 딸려 있다)
      try {
        for (final p in [..._removed]) {
          await remote.deleteReviewPhoto(p);
          _removed.remove(p);
        }
        for (final b in [..._added]) {
          await remote.addReviewPhoto(widget.productId, b);
          _added.remove(b);
        }
      } catch (e) {
        debugPrint('[shop] 사진: $e');
        _refresh();
        _snack('리뷰는 저장했지만 사진을 다 올리지 못했어요. 다시 저장해 주세요');
        return;
      }
      _refresh();
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(content: Text('리뷰를 저장했어요')));
        context.pop();
      }
    } catch (e) {
      debugPrint('[shop] $e');
      _snack(errorMessage(e, failed: '저장하지 못했어요'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    setState(() => _busy = true);
    try {
      await ref.read(shopRemoteProvider).deleteMyReview(widget.productId);
      _refresh();
      if (mounted) context.pop();
    } catch (e) {
      debugPrint('[shop] $e');
      _snack(errorMessage(e, failed: '지우지 못했어요'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final mine = ref.watch(myProductReviewProvider(widget.productId));
    final product = ref.watch(productProvider(widget.productId)).value;
    final value = mine.value;
    if (value != null && !_loaded) {
      _loaded = true;
      _rating = value.rating;
      _comment.text = value.comment ?? '';
      _kept.addAll(value.photos);
    }

    return Scaffold(
      appBar: AppBar(title: Text(value?.exists ?? false ? '리뷰 고치기' : '리뷰 쓰기')),
      body: switch (mine) {
        AsyncValue(:final value?) when !value.canReview => const Center(
          child: Padding(
            padding: EdgeInsets.all(AppSpacing.screenHorizontal),
            child: Text(
              '배송이 끝난 상품만 리뷰를 쓸 수 있어요',
              textAlign: TextAlign.center,
              style: AppTypography.body,
            ),
          ),
        ),
        AsyncValue(:final value?) => ListView(
          padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
          children: [
            if (product != null)
              Row(
                children: [
                  ProductArt(
                    category: product.category,
                    art: product.art,
                    size: 48,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(product.name, style: AppTypography.body),
                  ),
                ],
              ),
            const SizedBox(height: AppSpacing.xxl),
            const Text(
              '상품은 만족스러우셨나요?',
              textAlign: TextAlign.center,
              style: AppTypography.subtitle,
            ),
            const SizedBox(height: AppSpacing.md),
            StarPicker(
              value: _rating,
              onChanged: (v) => setState(() => _rating = v),
            ),
            const SizedBox(height: AppSpacing.xxl),
            const Text('후기 (선택)', style: AppTypography.subtitle),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _comment,
              maxLength: productReviewMaxLength,
              maxLines: 4,
              style: AppTypography.body,
              decoration: const InputDecoration(
                hintText: '사이즈·착용감·실제 산행에서 써 본 느낌을 남겨 주세요',
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                const Text('사진 (선택)', style: AppTypography.subtitle),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  '$_photoCount / ${PhotoSpec.review.maxCount}',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '리뷰 사진은 모든 사람이 볼 수 있어요',
              style: AppTypography.caption.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            PhotoStrip(
              images: _photoImages,
              onAdd: PhotoSpec.review.remaining(_photoCount) > 0 && !_busy
                  ? _pickPhotos
                  : null,
              onRemove: _busy ? null : _removePhoto,
              onTap: (i) =>
                  openPhotoViewer(context, images: _photoImages, initial: i),
            ),
            if (value.exists) ...[
              const SizedBox(height: AppSpacing.lg),
              Pressable(
                onPressed: _busy ? null : _delete,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                  child: Text(
                    '내 리뷰 지우기',
                    style: AppTypography.body.copyWith(color: AppColors.danger),
                  ),
                ),
              ),
            ],
          ],
        ),
        AsyncValue(:final error?) => Center(
          child: TextButton(
            onPressed: () =>
                ref.invalidate(myProductReviewProvider(widget.productId)),
            child: Text(errorMessage(error, failed: '불러오지 못했어요')),
          ),
        ),
        _ => const Padding(
          padding: EdgeInsets.all(AppSpacing.screenHorizontal),
          child: SkeletonBox(width: double.infinity, height: 200),
        ),
      },
      bottomNavigationBar: (value?.canReview ?? false)
          ? BottomActionBar(
              child: AppButton(
                label: _rating == null ? '별점을 골라 주세요' : '저장하기',
                onPressed: _busy || _rating == null ? null : _save,
              ),
            )
          : null,
    );
  }
}
