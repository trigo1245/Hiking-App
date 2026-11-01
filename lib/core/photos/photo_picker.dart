import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import 'photo_spec.dart';

enum PhotoSource { gallery, camera }

/// 사진을 고르거나 찍어서, 올릴 수 있는 JPEG로 바꿔 준다. 테스트에서는 가짜로 바꿔 끼운다.
abstract interface class PhotoPicker {
  /// [spec]대로 줄이고 위치 정보(EXIF)를 지운 JPEG 목록. 취소하면 빈 목록.
  /// 갤러리에서는 [limit]장까지 한 번에 고른다.
  Future<List<Uint8List>> pick(
    PhotoSource source,
    PhotoSpec spec, {
    int limit = 1,
  });
}

/// image_picker로 고르고(긴 변을 [PhotoSpec.maxLongSide]로 줄임),
/// flutter_image_compress로 다시 저장해 EXIF(촬영 위치·기기 정보)를 지운다.
/// image_picker만으로 줄이면 안드로이드에서 EXIF가 그대로 남을 수 있어서 두 단계로 한다.
class DevicePhotoPicker implements PhotoPicker {
  final _picker = ImagePicker();

  @override
  Future<List<Uint8List>> pick(
    PhotoSource source,
    PhotoSpec spec, {
    int limit = 1,
  }) async {
    if (limit < 1) return const [];
    final max = spec.maxLongSide.toDouble();
    final List<XFile> files;
    if (source == PhotoSource.camera || limit == 1) {
      final file = await _picker.pickImage(
        source: source == PhotoSource.camera
            ? ImageSource.camera
            : ImageSource.gallery,
        maxWidth: max,
        maxHeight: max,
      );
      files = [?file];
    } else {
      files = await _picker.pickMultiImage(
        maxWidth: max,
        maxHeight: max,
        limit: limit,
      );
    }

    final out = <Uint8List>[];
    for (final file in files.take(limit)) {
      // 이미 긴 변이 기준 이하라 크기는 그대로 두고, 품질만 맞춰 EXIF 없이 다시 저장한다.
      // (사진 방향은 EXIF의 회전 정보대로 바로 세워 저장한다)
      final jpeg = await FlutterImageCompress.compressWithFile(
        file.path,
        minWidth: spec.maxLongSide,
        minHeight: spec.maxLongSide,
        quality: spec.quality,
        format: CompressFormat.jpeg,
        keepExif: false,
      );
      if (jpeg == null) {
        debugPrint('[photo] 사진을 줄이지 못했어요: ${file.name}');
        continue;
      }
      out.add(jpeg);
    }
    return out;
  }
}

final photoPickerProvider = Provider<PhotoPicker>((ref) => DevicePhotoPicker());
