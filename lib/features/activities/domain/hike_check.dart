import 'dart:math' as math;

import '../../courses/domain/course.dart';
import '../../recording/domain/track_point.dart';

/// 산행인지 확인한다 (기록 저장 전 경고용). 아래 중 하나라도 맞으면 산행으로 본다.
/// ① 코스를 완주했거나 진행률 10% 이상 → 들머리 100m 안을 지나므로 ②에 포함된다
/// ② 등록된 코스 선에서 [nearCourseM] 안을 지난 적이 있다 (기기에 저장한 코스, 인터넷 없이 확인)
/// ③ 오른 높이 [minGainM] 이상이면서 1km당 [minGainPerKm] 이상 (등록되지 않은 산)
///
/// GPS 고도는 흔들리므로 ③은 보조로 두고, 코스 근처 여부를 먼저 본다.
abstract final class HikeCheck {
  static const nearCourseM = 200.0;
  static const minGainM = 100.0;
  static const minGainPerKm = 30.0;

  /// 정확도가 이보다 나쁜 점은 보지 않는다 (코스 매칭과 같다)
  static const maxAccuracyM = 30.0;

  /// 경로를 이 간격마다 하나씩만 본다 (코스 수 × 점 수가 많아도 빠르게)
  static const _sampleStepM = 25.0;

  static bool isHike({
    required double distanceM,
    required double elevationGainM,
    required List<TrackPoint> track,
    required Iterable<Course> courses,
  }) =>
      passesNearCourse(track, courses) ||
      climbsEnough(distanceM: distanceM, elevationGainM: elevationGainM);

  /// ③ 오른 높이 기준
  static bool climbsEnough({
    required double distanceM,
    required double elevationGainM,
  }) {
    if (elevationGainM < minGainM || distanceM <= 0) return false;
    return elevationGainM / (distanceM / 1000) >= minGainPerKm;
  }

  /// ② 등록된 코스 선 근처를 지났는지
  static bool passesNearCourse(
    List<TrackPoint> track,
    Iterable<Course> courses,
  ) {
    final points = _sample(track);
    if (points.isEmpty) return false;
    for (final course in courses) {
      if (course.path.length < 2) continue;
      final box = _Box.around(course.path, nearCourseM);
      for (final p in points) {
        if (!box.contains(p)) continue;
        if (_distanceToPolyline(p, course.path) <= nearCourseM) return true;
      }
    }
    return false;
  }

  /// 정확한 점만, 약 [_sampleStepM]마다 하나씩
  static List<GeoPoint> _sample(List<TrackPoint> track) {
    final out = <GeoPoint>[];
    GeoPoint? last;
    for (final t in track) {
      if (t.accuracy > maxAccuracyM) continue;
      final p = GeoPoint(t.latitude, t.longitude);
      if (last == null || _flatDistance(last, p) >= _sampleStepM) {
        out.add(p);
        last = p;
      }
    }
    return out;
  }

  static double _flatDistance(GeoPoint a, GeoPoint b) {
    const metersPerDegLat = 111320.0;
    final dx =
        (b.lon - a.lon) * metersPerDegLat * math.cos(a.lat * math.pi / 180);
    final dy = (b.lat - a.lat) * metersPerDegLat;
    return math.sqrt(dx * dx + dy * dy);
  }

  /// 점에서 꺾은선까지의 가장 짧은 거리(m). 짧은 거리라 평면으로 펴서 계산한다.
  static double _distanceToPolyline(GeoPoint p, List<GeoPoint> line) {
    const metersPerDegLat = 111320.0;
    final metersPerDegLon = metersPerDegLat * math.cos(p.lat * math.pi / 180);
    (double, double) xy(GeoPoint q) =>
        ((q.lon - p.lon) * metersPerDegLon, (q.lat - p.lat) * metersPerDegLat);

    var best = double.infinity;
    var (ax, ay) = xy(line.first);
    for (var i = 1; i < line.length; i++) {
      final (bx, by) = xy(line[i]);
      final dx = bx - ax;
      final dy = by - ay;
      final len2 = dx * dx + dy * dy;
      final t = len2 == 0 ? 0.0 : ((-ax * dx - ay * dy) / len2).clamp(0.0, 1.0);
      final cx = ax + t * dx;
      final cy = ay + t * dy;
      best = math.min(best, math.sqrt(cx * cx + cy * cy));
      (ax, ay) = (bx, by);
    }
    return best;
  }
}

/// 코스 선을 [marginM]만큼 넓힌 위경도 상자 (멀리 있는 코스는 거리 계산 없이 건너뛴다)
class _Box {
  const _Box(this.minLat, this.maxLat, this.minLon, this.maxLon);

  factory _Box.around(List<GeoPoint> path, double marginM) {
    var minLat = path.first.lat, maxLat = path.first.lat;
    var minLon = path.first.lon, maxLon = path.first.lon;
    for (final p in path) {
      minLat = math.min(minLat, p.lat);
      maxLat = math.max(maxLat, p.lat);
      minLon = math.min(minLon, p.lon);
      maxLon = math.max(maxLon, p.lon);
    }
    final dLat = marginM / 111320.0;
    final dLon = marginM / (111320.0 * math.cos(minLat * math.pi / 180));
    return _Box(minLat - dLat, maxLat + dLat, minLon - dLon, maxLon + dLon);
  }

  final double minLat, maxLat, minLon, maxLon;

  bool contains(GeoPoint p) =>
      p.lat >= minLat && p.lat <= maxLat && p.lon >= minLon && p.lon <= maxLon;
}
