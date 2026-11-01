import 'package:flutter/material.dart';

import '../design/design.dart';
import '../widgets/pressable.dart';

export 'photo_item.dart';

enum PhotoMenuChoice { gallery, camera, reset }

/// "앨범에서 고르기 / 사진 찍기" (+ [resetLabel]이 있으면 되돌리기) 고르는 아래 창
Future<PhotoMenuChoice?> showPhotoSourceSheet(
  BuildContext context, {
  String? resetLabel,
}) {
  Widget item(BuildContext context, IconData icon, String label, Object v) =>
      ListTile(
        leading: Icon(icon, color: AppColors.textSecondary),
        title: Text(label, style: AppTypography.body),
        onTap: () => Navigator.of(context).pop(v),
      );
  return showModalBottomSheet<PhotoMenuChoice>(
    context: context,
    backgroundColor: AppColors.background,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          item(
            context,
            Icons.photo_library_outlined,
            '앨범에서 고르기',
            PhotoMenuChoice.gallery,
          ),
          item(
            context,
            Icons.photo_camera_outlined,
            '사진 찍기',
            PhotoMenuChoice.camera,
          ),
          if (resetLabel != null)
            item(
              context,
              Icons.undo_rounded,
              resetLabel,
              PhotoMenuChoice.reset,
            ),
          const SizedBox(height: AppSpacing.sm),
        ],
      ),
    ),
  );
}

/// 사진 썸네일 줄. [onAdd]가 있으면 끝에 "+" 칸을 둔다.
class PhotoStrip extends StatelessWidget {
  const PhotoStrip({
    super.key,
    required this.images,
    this.onTap,
    this.onAdd,
    this.onRemove,
    this.size = 88,
    this.busy = false,
  });

  final List<ImageProvider> images;
  final ValueChanged<int>? onTap;
  final VoidCallback? onAdd;

  /// 있으면 썸네일 귀퉁이에 지우기(×) 버튼을 둔다. (리뷰 쓰기 화면)
  final ValueChanged<int>? onRemove;
  final double size;

  /// 올리는 중이면 "+" 칸에 진행 표시
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        for (var i = 0; i < images.length; i++)
          Stack(
            clipBehavior: Clip.none,
            children: [
              Pressable(
                onPressed: onTap == null ? null : () => onTap!(i),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.input),
                  child: Image(
                    image: images[i],
                    width: size,
                    height: size,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => _Placeholder(size: size),
                    frameBuilder: (context, child, frame, sync) =>
                        frame == null && !sync
                        ? _Placeholder(size: size)
                        : child,
                  ),
                ),
              ),
              if (onRemove != null)
                Positioned(
                  right: -6,
                  top: -6,
                  child: Pressable(
                    onPressed: () => onRemove!(i),
                    child: Container(
                      decoration: const BoxDecoration(
                        color: AppColors.textPrimary,
                        shape: BoxShape.circle,
                      ),
                      padding: const EdgeInsets.all(2),
                      child: const Icon(
                        Icons.close_rounded,
                        size: 16,
                        color: AppColors.background,
                        semanticLabel: '사진 빼기',
                      ),
                    ),
                  ),
                ),
            ],
          ),
        if (onAdd != null || busy)
          Pressable(
            onPressed: busy ? null : onAdd,
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: AppColors.backgroundGrouped,
                borderRadius: BorderRadius.circular(AppRadius.input),
              ),
              child: Center(
                child: busy
                    ? const SizedBox.square(
                        dimension: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(
                        Icons.add_a_photo_outlined,
                        color: AppColors.textTertiary,
                        semanticLabel: '사진 추가',
                      ),
              ),
            ),
          ),
      ],
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) =>
      Container(width: size, height: size, color: AppColors.backgroundGrouped);
}

/// 사진 크게 보기: 옆으로 넘기고, 두 손가락으로 확대한다.
/// [onDelete]가 있으면 위쪽에 지우기 버튼을 둔다. 지웠으면 true를 돌려주고 화면을 닫는다.
Future<void> openPhotoViewer(
  BuildContext context, {
  required List<ImageProvider> images,
  int initial = 0,
  Future<bool> Function(int index)? onDelete,
}) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) =>
          _PhotoViewer(images: images, initial: initial, onDelete: onDelete),
    ),
  );
}

class _PhotoViewer extends StatefulWidget {
  const _PhotoViewer({
    required this.images,
    required this.initial,
    required this.onDelete,
  });

  final List<ImageProvider> images;
  final int initial;
  final Future<bool> Function(int index)? onDelete;

  @override
  State<_PhotoViewer> createState() => _PhotoViewerState();
}

class _PhotoViewerState extends State<_PhotoViewer> {
  late final _pages = PageController(initialPage: widget.initial);
  late int _index = widget.initial;
  bool _busy = false;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('이 사진을 지울까요?'),
        content: const Text('지운 사진은 다시 살릴 수 없어요.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('지우기', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    final deleted = await widget.onDelete!(_index);
    if (!mounted) return;
    if (deleted) {
      Navigator.of(context).pop();
    } else {
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.textPrimary,
      appBar: AppBar(
        backgroundColor: AppColors.textPrimary,
        foregroundColor: AppColors.background,
        title: Text(
          '${_index + 1} / ${widget.images.length}',
          style: AppTypography.body.copyWith(color: AppColors.background),
        ),
        actions: [
          if (widget.onDelete != null)
            IconButton(
              onPressed: _busy ? null : _delete,
              icon: const Icon(Icons.delete_outline_rounded),
              tooltip: '사진 지우기',
            ),
        ],
      ),
      body: PageView.builder(
        controller: _pages,
        itemCount: widget.images.length,
        onPageChanged: (i) => setState(() => _index = i),
        itemBuilder: (context, i) => InteractiveViewer(
          maxScale: 4,
          child: Center(
            child: Image(
              image: widget.images[i],
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => Text(
                '사진을 불러오지 못했어요',
                style: AppTypography.body.copyWith(color: AppColors.background),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
