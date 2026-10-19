import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/geo.dart';
import '../../courses/data/course_repository.dart';
import '../../courses/domain/course.dart';
import '../../recording/data/recording_repository.dart';
import '../../recording/domain/track_point.dart';
import '../../recording/domain/track_stats.dart';

/// 시연용 등산 기록을 만든다. (개발용 버튼에서만 쓴다)
/// 실제 코스 선을 따라 오르고(GPS처럼 조금 흔들림), 정상에서 쉬었다가 같은 길로 내려온다.
/// 일반 기록과 같은 경로로 저장되므로, 업로드·코스 완주 판정까지 실제처럼 동작한다.
class DemoActivityGenerator {
  DemoActivityGenerator(this._recording);

  final RecordingRepository _recording;

  /// 기록 3개를 만들고 ID를 돌려준다.
  /// - 금정산 범어사 코스 2회 (같은 코스 비교용, 두 번째가 더 빠름)
  /// - 승학산 동아대 코스 1회
  Future<List<String>> createDemoHikes({
    required List<Course> courses,
    required String userId,
    required DateTime now,
  }) async {
    Course? find(String mountain, String name) => courses
        .where((c) => c.mountainName == mountain && c.name.contains(name))
        .firstOrNull;
    final beomeosa = find('금정산', '범어사') ?? courses.firstOrNull;
    final donga = find('승학산', '동아대') ?? courses.lastOrNull;
    if (beomeosa == null || donga == null) return const [];

    return [
      await _hike(
        beomeosa,
        userId: userId,
        start: now.subtract(const Duration(days: 12, hours: 3)),
        upSecondsPer10m: 13,
        title: '시연용 금정산 첫 산행',
      ),
      await _hike(
        donga,
        userId: userId,
        start: now.subtract(const Duration(days: 6, hours: 4)),
        upSecondsPer10m: 12,
        title: '시연용 승학산 산행',
      ),
      await _hike(
        beomeosa,
        userId: userId,
        start: now.subtract(const Duration(days: 2, hours: 5)),
        upSecondsPer10m: 10,
        title: '시연용 금정산 두 번째 산행',
      ),
    ];
  }

  Future<String> _hike(
    Course course, {
    required String userId,
    required DateTime start,
    required int upSecondsPer10m,
    required String title,
  }) async {
    final path = _resample(course.path, 10);
    final length = (path.length - 1) * 10.0;
    // 코스 길이에 맞춘 그럴듯한 고도: 출발 60m, 평균 경사 약 16% (최대 750m 오름)
    final gain = math.min(750.0, length * 0.16);
    double altitudeAt(int i) =>
        60 + gain * (i / (path.length - 1)) + math.sin(i / 7) * 4;

    final session = await _recording.start(start, userId: userId);
    final calculator = TrackStatsCalculator();
    var t = start;
    var n = 0;
    Future<void> add(GeoPoint p, double altitude) async {
      // 결정적인 흔들림 (최대 약 4m)
      final dLat = math.sin(n * 1.3) * 4 / 111320;
      final dLon =
          math.cos(n * 1.9) * 4 / (111320 * math.cos(p.lat * math.pi / 180));
      final point = TrackPoint(
        segment: 0,
        latitude: p.lat + dLat,
        longitude: p.lon + dLon,
        altitude: altitude,
        accuracy: 5 + (n % 4).toDouble(),
        recordedAt: t,
      );
      await _recording.addPoint(session.activityId, point);
      calculator.add(point);
      n++;
    }

    // 오르막: 후반으로 갈수록 조금씩 느려진다 (피로도 분석 확인용)
    for (var i = 0; i < path.length; i++) {
      await add(path[i], altitudeAt(i));
      final slowdown = i > path.length / 2 ? 3 : 0;
      t = t.add(Duration(seconds: upSecondsPer10m + slowdown));
    }
    // 정상에서 10분 쉬기
    for (var k = 0; k < 10; k++) {
      t = t.add(const Duration(minutes: 1));
      await add(path.last, altitudeAt(path.length - 1));
    }
    // 같은 길로 내려오기
    for (var i = path.length - 1; i >= 0; i--) {
      t = t.add(const Duration(seconds: 8));
      await add(path[i], altitudeAt(i));
    }

    await _recording.finish(
      session.activityId,
      endedAt: t,
      stats: calculator.stats,
      title: title,
    );
    return session.activityId;
  }

  /// 선 위에 [stepM] 간격으로 점을 다시 찍는다.
  static List<GeoPoint> _resample(List<GeoPoint> path, double stepM) {
    final out = <GeoPoint>[path.first];
    var carry = 0.0;
    for (var i = 1; i < path.length; i++) {
      final a = path[i - 1];
      final b = path[i];
      final len = haversineMeters(a.lat, a.lon, b.lat, b.lon);
      var at = stepM - carry;
      while (at <= len) {
        final f = at / len;
        out.add(
          GeoPoint(a.lat + (b.lat - a.lat) * f, a.lon + (b.lon - a.lon) * f),
        );
        at += stepM;
      }
      carry = len - (at - stepM);
    }
    return out;
  }
}

final demoActivityGeneratorProvider = Provider<DemoActivityGenerator>((ref) {
  return DemoActivityGenerator(ref.watch(recordingRepositoryProvider));
});

/// 시연용 기록에 쓸 코스 목록
final demoCoursesProvider = FutureProvider.autoDispose<List<Course>>(
  (ref) => ref.watch(courseRepositoryProvider).watchAll().first,
);
