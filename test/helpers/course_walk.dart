import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:hiking_app/core/utils/geo.dart';
import 'package:hiking_app/features/courses/domain/course.dart';
import 'package:hiking_app/features/recording/domain/track_point.dart';

/// data/trails/courses의 실제 코스 파일을 읽는다.
Course loadCourse(String id) {
  final f = jsonDecode(
    File('data/trails/courses/$id.geojson').readAsStringSync(),
  ) as Map<String, dynamic>;
  final path = [
    for (final c
        in ((f['geometry'] as Map)['coordinates'] as List).cast<List>())
      GeoPoint((c[1] as num).toDouble(), (c[0] as num).toDouble()),
  ];
  return Course(
    id: id,
    mountainName: '',
    name: id,
    startName: '',
    endName: '',
    distanceM: 0,
    path: path,
    summit: path.last,
  );
}

final walkStart = DateTime.utc(2026, 10, 20, 0);

/// [path]를 따라 10m마다 점을 찍고, GPS 오차처럼 최대 [noiseM]만큼 흔든다.
/// 10초에 10m (시속 3.6km)로 걷는다고 본다.
List<TrackPoint> walk(
  List<GeoPoint> path, {
  double noiseM = 8,
  DateTime? from,
  double accuracy = 5,
}) {
  final out = <TrackPoint>[];
  var t = from ?? walkStart;
  var i = 0;
  void add(GeoPoint p) {
    // 결정적인 흔들림 (테스트가 매번 같은 결과를 내도록)
    final dLat = math.sin(i * 1.7) * noiseM / 111320;
    final dLon =
        math.cos(i * 2.3) * noiseM / (111320 * math.cos(p.lat * math.pi / 180));
    out.add(
      TrackPoint(
        segment: 0,
        latitude: p.lat + dLat,
        longitude: p.lon + dLon,
        accuracy: accuracy,
        recordedAt: t,
      ),
    );
    t = t.add(const Duration(seconds: 10));
    i++;
  }

  // 꼭짓점 간격과 상관없이 정확히 10m마다 점을 찍는다.
  add(path.first);
  var carry = 0.0;
  for (var k = 1; k < path.length; k++) {
    final a = path[k - 1];
    final b = path[k];
    final length = haversineMeters(a.lat, a.lon, b.lat, b.lon);
    var at = 10 - carry;
    while (at <= length) {
      final t = at / length;
      add(GeoPoint(a.lat + (b.lat - a.lat) * t, a.lon + (b.lon - a.lon) * t));
      at += 10;
    }
    carry = length - (at - 10);
  }
  return out;
}

/// 점을 북쪽으로 [meters]만큼 옮긴다.
GeoPoint shiftNorth(GeoPoint p, double meters) =>
    GeoPoint(p.lat + meters / 111320, p.lon);

/// 시연용 기록 생성기가 쓰는 실제 코스 4개 (산 이름·코스 이름까지 채운다)
List<Course> demoCourses() {
  Course named(String id, String mountain, String name) {
    final c = loadCourse(id);
    return Course(
      id: id,
      mountainName: mountain,
      name: name,
      startName: '',
      endName: '',
      distanceM: 0,
      path: c.path,
      summit: c.summit,
    );
  }

  return [
    named('geumjeongsan-beomeosa', '금정산', '범어사 코스'),
    named('geumjeongsan-sanseong', '금정산', '산성마을 코스'),
    named('seunghaksan-donga', '승학산', '동아대 코스'),
    named('seunghaksan-gudeok', '승학산', '구덕문화공원 코스'),
  ];
}
