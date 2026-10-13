import 'dart:io';

import 'package:hiking_app/features/recording/domain/track_point.dart';

/// test_data/의 GPX를 읽어 위치 목록으로 바꾼다. (테스트용 간단 파서)
List<LocationSample> readGpx(String path, {double accuracy = 5}) {
  final xml = File(path).readAsStringSync();
  final pattern = RegExp(
    r'<trkpt lat="([-\d.]+)" lon="([-\d.]+)">\s*<ele>([-\d.]+)</ele>\s*<time>([^<]+)</time>',
  );
  return [
    for (final m in pattern.allMatches(xml))
      LocationSample(
        latitude: double.parse(m.group(1)!),
        longitude: double.parse(m.group(2)!),
        altitude: double.parse(m.group(3)!),
        accuracy: accuracy,
        recordedAt: DateTime.parse(m.group(4)!),
      ),
  ];
}
