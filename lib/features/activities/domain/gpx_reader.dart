import '../../recording/domain/track_point.dart';

/// [buildGpx]가 만든 GPX를 다시 위치 점으로 읽는다. (다른 기기에서 기록을 받을 때 사용)
/// - `<trkseg>`마다 구간 번호를 0, 1, 2…로 매긴다 (일시정지로 나뉜 구간).
/// - 정확도는 `<hk:accuracy>`에서 읽고, 없으면 [defaultAccuracy]로 둔다.
List<TrackPoint> parseGpx(String gpx, {double defaultAccuracy = 10}) {
  final segmentPattern = RegExp(r'<trkseg>(.*?)</trkseg>', dotAll: true);
  final pointPattern = RegExp(
    r'<trkpt\s+lat="([-\d.eE]+)"\s+lon="([-\d.eE]+)"\s*>(.*?)</trkpt>',
    dotAll: true,
  );
  String? tag(String body, String name) =>
      RegExp('<$name>([^<]*)</$name>').firstMatch(body)?.group(1)?.trim();

  final out = <TrackPoint>[];
  var segment = 0;
  for (final seg in segmentPattern.allMatches(gpx)) {
    for (final p in pointPattern.allMatches(seg.group(1)!)) {
      final body = p.group(3)!;
      final time = tag(body, 'time');
      if (time == null) continue; // 시각이 없는 점은 쓸 수 없다.
      out.add(
        TrackPoint(
          segment: segment,
          latitude: double.parse(p.group(1)!),
          longitude: double.parse(p.group(2)!),
          altitude: double.tryParse(tag(body, 'ele') ?? ''),
          accuracy:
              double.tryParse(tag(body, 'hk:accuracy') ?? '') ??
              defaultAccuracy,
          recordedAt: DateTime.parse(time),
        ),
      );
    }
    segment++;
  }
  return out;
}
