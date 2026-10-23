import 'dart:math' as math;

import '../../../core/utils/geo.dart';
import '../../recording/domain/track_point.dart';
import 'course.dart';

/// 기록이 코스를 완주했다고 판정된 결과
class CourseCompletion {
  const CourseCompletion({
    required this.courseId,
    required this.startedAt,
    required this.reachedSummitAt,
    required this.overlapRatio,
  });

  final String courseId;

  /// 들머리를 마지막으로 지난 시각
  final DateTime startedAt;

  /// 정상에 처음 도착한 시각
  final DateTime reachedSummitAt;

  /// 코스 중 기록 경로와 겹친 비율 (0~1)
  final double overlapRatio;

  /// 최단시간 랭킹에 쓰는 등정 시간 (하산 제외)
  Duration get ascent => reachedSummitAt.difference(startedAt);
}

/// 정상까지 가지 않은 산행이 코스를 얼마나 따라갔는지
class CourseProgress {
  const CourseProgress({
    required this.courseId,
    required this.progress,
    required this.startedAt,
  });

  final String courseId;

  /// 들머리에서 코스를 따라 간 비율 (0~1)
  final double progress;

  /// 들머리를 처음 지난 시각
  final DateTime startedAt;
}

/// 기록이 등록된 코스를 완주했는지 판정한다. (CLAUDE.md 6-2장 "코스 매칭")
abstract final class CourseMatcher {
  /// 코스 선에서 이 거리 안이면 "겹친다"
  static const overlapRadiusM = 30.0;

  /// 완주로 인정하는 겹침 비율
  static const minOverlapRatio = 0.8;

  /// 들머리에서 이 거리 안에서 출발해야 한다
  static const startRadiusM = 100.0;

  /// 정상에서 이 거리 안에 도달해야 한다
  static const summitRadiusM = 50.0;

  /// 정확도가 이보다 나쁜 점은 판정에 쓰지 않는다 (기록 계산과 같은 기준)
  static const maxAccuracyM = 30.0;

  /// 겹침 비율을 잴 때 코스 선 위에 찍는 점 간격
  static const _sampleStepM = 10.0;

  /// 진행률을 남기는 최소 비율. 이보다 적으면 그 코스에 간 것으로 보지 않는다.
  static const minProgress = 0.1;

  /// [track]으로 완주한 코스들
  static List<CourseCompletion> matchAll(
    Iterable<Course> courses,
    List<TrackPoint> track,
  ) => [for (final course in courses) ?match(course, track)];

  /// 완주하지 못한 코스 중 [minProgress] 이상 다녀온 코스들의 진행률
  static List<CourseProgress> progressAll(
    Iterable<Course> courses,
    List<TrackPoint> track,
  ) => [
    for (final course in courses)
      if (match(course, track) == null)
        if (progress(course, track) case final p?
            when p.progress >= minProgress)
          p,
  ];

  /// 들머리 100m 안에서 출발해 코스를 어디까지 따라갔는지 잰다.
  ///
  /// 코스 선 위에 10m마다 점을 찍고, 들머리부터 앞으로 가며 경로에서 30m 안에 있는
  /// 가장 먼 점을 찾는다. 단, 들머리부터 그 점까지 80% 이상을 따라갔어야 한다
  /// (완주 판정과 같은 기준이라, 길을 벗어났다가 다른 길로 정상 근처에 간 경우는 짧게 잡힌다).
  /// 들머리를 지나지 않았으면 null.
  static CourseProgress? progress(Course course, List<TrackPoint> track) {
    final good = [
      for (final p in track)
        if (p.accuracy <= maxAccuracyM) p,
    ];
    if (good.length < 2 || course.path.length < 2) return null;
    final startIndex = good.indexWhere(
      (p) =>
          _distance(GeoPoint(p.latitude, p.longitude), course.start) <=
          startRadiusM,
    );
    if (startIndex < 0 || startIndex >= good.length - 1) return null;
    final after = [
      for (final p in good.sublist(startIndex))
        GeoPoint(p.latitude, p.longitude),
    ];

    final samples = _sampleAlong(course.path, _sampleStepM);
    var covered = 0;
    var furthest = 0;
    for (var i = 0; i < samples.length; i++) {
      if (_distanceToPolyline(samples[i], after) > overlapRadiusM) continue;
      covered++;
      if (covered / (i + 1) >= minOverlapRatio) furthest = i;
    }
    if (furthest == 0) return null;
    return CourseProgress(
      courseId: course.id,
      progress: furthest / (samples.length - 1),
      startedAt: good[startIndex].recordedAt,
    );
  }

  /// [track]이 [course]를 완주했으면 결과를, 아니면 null을 돌려준다.
  ///
  /// 1. 정상 50m 안에 처음 들어온 점을 찾는다.
  /// 2. 그 전에 들머리 100m 안을 마지막으로 지난 점을 찾는다. (등정 시작)
  /// 3. 두 점 사이 경로(오르막)가 코스 선의 80% 이상을 30m 안에서 따라갔는지 본다.
  static CourseCompletion? match(Course course, List<TrackPoint> track) {
    final points = [
      for (final p in track)
        if (p.accuracy <= maxAccuracyM) GeoPoint(p.latitude, p.longitude),
    ];
    final times = [
      for (final p in track)
        if (p.accuracy <= maxAccuracyM) p.recordedAt,
    ];
    if (points.length < 2 || course.path.length < 2) return null;

    final summit = course.path.last;
    final summitIndex = points.indexWhere(
      (p) => _distance(p, summit) <= summitRadiusM,
    );
    if (summitIndex <= 0) return null;

    final startIndex = points
        .sublist(0, summitIndex)
        .lastIndexWhere((p) => _distance(p, course.start) <= startRadiusM);
    if (startIndex < 0) return null;
    if (!times[summitIndex].isAfter(times[startIndex])) return null;

    final ascent = points.sublist(startIndex, summitIndex + 1);
    final ratio = overlapRatio(course.path, ascent);
    if (ratio < minOverlapRatio) return null;

    return CourseCompletion(
      courseId: course.id,
      startedAt: times[startIndex],
      reachedSummitAt: times[summitIndex],
      overlapRatio: ratio,
    );
  }

  /// 겹침 비율 = 코스 선 중 [track]에서 30m 안에 있는 부분 / 코스 전체.
  /// 코스 선 위에 10m마다 점을 찍어, 그중 경로 가까이 있는 점의 비율로 잰다.
  static double overlapRatio(List<GeoPoint> coursePath, List<GeoPoint> track) {
    final samples = _sampleAlong(coursePath, _sampleStepM);
    if (samples.isEmpty || track.length < 2) return 0;
    var covered = 0;
    for (final s in samples) {
      if (_distanceToPolyline(s, track) <= overlapRadiusM) covered++;
    }
    return covered / samples.length;
  }

  static double _distance(GeoPoint a, GeoPoint b) =>
      haversineMeters(a.lat, a.lon, b.lat, b.lon);

  /// 선 위에 [stepM] 간격으로 점을 찍는다. (양 끝점 포함)
  static List<GeoPoint> _sampleAlong(List<GeoPoint> path, double stepM) {
    final out = <GeoPoint>[path.first];
    var carry = 0.0; // 이전 선분에서 남은 거리
    for (var i = 1; i < path.length; i++) {
      final a = path[i - 1];
      final b = path[i];
      final length = _distance(a, b);
      var at = stepM - carry;
      while (at <= length) {
        final t = at / length;
        out.add(
          GeoPoint(a.lat + (b.lat - a.lat) * t, a.lon + (b.lon - a.lon) * t),
        );
        at += stepM;
      }
      carry = length - (at - stepM);
    }
    out.add(path.last);
    return out;
  }

  /// 점에서 꺾은선까지의 가장 짧은 거리(m).
  /// 짧은 거리라 점 주변을 평면으로 펴서 계산한다.
  static double _distanceToPolyline(GeoPoint p, List<GeoPoint> line) {
    const metersPerDegLat = 111320.0;
    final metersPerDegLon = metersPerDegLat * math.cos(p.lat * math.pi / 180);
    (double, double) xy(GeoPoint q) =>
        ((q.lon - p.lon) * metersPerDegLon, (q.lat - p.lat) * metersPerDegLat);

    var best = double.infinity;
    var (ax, ay) = xy(line.first);
    for (var i = 1; i < line.length; i++) {
      final (bx, by) = xy(line[i]);
      // 원점(p)에서 선분 a-b까지의 거리
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
