import '../../recording/domain/track_point.dart';

/// 기록의 위치 점들을 GPX 1.1 문서로 만든다.
/// 일시정지로 나뉜 구간마다 `<trkseg>`를 따로 만든다.
/// 정확도(accuracy)는 표준 GPX에 칸이 없어 `<extensions>`에 넣는다. (서버에서 다시 거를 때 사용)
String buildGpx({required String title, required List<TrackPoint> points}) {
  final out = StringBuffer()
    ..writeln('<?xml version="1.0" encoding="UTF-8"?>')
    ..writeln(
      '<gpx version="1.1" creator="hiking_app" '
      'xmlns="http://www.topografix.com/GPX/1/1" '
      'xmlns:hk="urn:hiking-app:gpx:1">',
    )
    ..writeln('  <trk>')
    ..writeln('    <name>${_escape(title)}</name>');

  int? segment;
  for (final p in points) {
    if (p.segment != segment) {
      if (segment != null) out.writeln('    </trkseg>');
      out.writeln('    <trkseg>');
      segment = p.segment;
    }
    out.write('      <trkpt lat="${p.latitude}" lon="${p.longitude}">');
    if (p.altitude != null) out.write('<ele>${p.altitude}</ele>');
    out.write('<time>${p.recordedAt.toUtc().toIso8601String()}</time>');
    out.write(
      '<extensions><hk:accuracy>${p.accuracy}</hk:accuracy></extensions>',
    );
    out.writeln('</trkpt>');
  }
  if (segment != null) out.writeln('    </trkseg>');

  out
    ..writeln('  </trk>')
    ..writeln('</gpx>');
  return out.toString();
}

String _escape(String s) => s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');
