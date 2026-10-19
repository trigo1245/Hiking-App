import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// GPX 파일을 휴대폰 공유 창으로 내보낸다. 테스트에서는 가짜로 바꿔 끼운다.
abstract interface class GpxSharer {
  Future<void> share({required String fileName, required String gpx});
}

class PlatformGpxSharer implements GpxSharer {
  @override
  Future<void> share({required String fileName, required String gpx}) async {
    // 공유 창은 파일 경로가 필요해서 임시 폴더에 잠깐 저장한다.
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$fileName');
    await file.writeAsString(gpx);
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'application/gpx+xml')],
        title: fileName,
      ),
    );
  }
}

final gpxSharerProvider = Provider<GpxSharer>((ref) => PlatformGpxSharer());
