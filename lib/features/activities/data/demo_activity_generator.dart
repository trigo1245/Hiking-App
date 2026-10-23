import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/geo.dart';
import '../../courses/data/course_repository.dart';
import '../../courses/domain/course.dart';
import '../../recording/data/recording_repository.dart';
import '../../recording/domain/recording_session.dart';
import '../../recording/domain/track_point.dart';
import '../../recording/domain/track_stats.dart';
import 'activities_repository.dart';

/// 시연용 기록의 제목 머리말. 지울 때 이 말로 찾는다.
const demoTitlePrefix = '시연용';

/// 시연용 등산 기록을 만든다. (개발용 버튼에서만 쓴다)
/// 실제 코스 선을 따라 걷고(GPS처럼 조금 흔들림), 일반 기록과 같은 경로로 저장되므로
/// 업로드·완주 판정·진행률·분석까지 실제처럼 동작한다.
///
/// 확인할 수 있는 상황 (최근 두 달에 나눠 만든다. 월별 그래프·연속 주 확인용)
/// - 범어사 코스 완주 3번 (점점 빨라짐, 첫 산행에는 일시정지 1번) → 같은 코스 비교, 랭킹 내 순위
/// - 동아대 코스 완주 1번
/// - 산성마을 코스 62%에서 하산 → 진행률 표시, 조망을 뺀 리뷰 쓰기 가능
/// - 구덕문화공원 코스 30%에서 하산 → 진행률 표시, 리뷰는 아직 못 씀(40% 미만)
/// - 차로 이동한 구간이 섞인 기록 → 속도 이상 표시, 완주로 인정하지 않음
/// - 코스와 관계없는 공원 산책 → 개인 기록으로만 저장
class DemoActivityGenerator {
  DemoActivityGenerator(this._recording, this._activities);

  final RecordingRepository _recording;
  final ActivitiesRepository _activities;

  /// 이 기기에 있는 [userId]의 시연용 기록을 지운다. 지운 개수를 돌려준다.
  /// (서버 쪽은 supabase/seed/demo_data.sql이 지운다)
  Future<int> removeDemoHikes({required String userId}) =>
      _activities.deleteByTitlePrefix(userId, demoTitlePrefix);

  /// 기존 시연용 기록을 지우고 새로 만든다. 만든 기록 ID를 돌려준다.
  /// 필요한 코스(금정산 범어사·산성마을, 승학산 동아대·구덕문화공원)가 없으면 빈 목록.
  Future<List<String>> createDemoHikes({
    required List<Course> courses,
    required String userId,
    required DateTime now,
  }) async {
    Course? find(String mountain, String name) => courses
        .where((c) => c.mountainName == mountain && c.name.contains(name))
        .firstOrNull;
    final beomeosa = find('금정산', '범어사');
    final sanseong = find('금정산', '산성');
    final donga = find('승학산', '동아대');
    final gudeok = find('승학산', '구덕');
    if (beomeosa == null ||
        sanseong == null ||
        donga == null ||
        gudeok == null) {
      return const [];
    }
    await removeDemoHikes(userId: userId);

    DateTime daysAgo(int days, int hour) {
      final d = now.subtract(Duration(days: days));
      return DateTime(d.year, d.month, d.day, hour);
    }

    return [
      await _hike(
        beomeosa,
        userId: userId,
        start: daysAgo(62, 8),
        upSecondsPer10m: 14,
        title: '$demoTitlePrefix 금정산 첫 산행',
        pauseAt: 0.3,
      ),
      await _hike(
        donga,
        userId: userId,
        start: daysAgo(41, 9),
        upSecondsPer10m: 12,
        title: '$demoTitlePrefix 승학산 동아대 산행',
      ),
      await _parkWalk(
        userId: userId,
        start: daysAgo(27, 7),
        title: '$demoTitlePrefix 시민공원 산책',
      ),
      await _hike(
        gudeok,
        userId: userId,
        start: daysAgo(20, 10),
        upSecondsPer10m: 13,
        title: '$demoTitlePrefix 구덕 코스 30%에서 하산',
        turnAt: 0.3,
      ),
      await _hike(
        donga,
        userId: userId,
        start: daysAgo(16, 14),
        upSecondsPer10m: 12,
        title: '$demoTitlePrefix 차로 이동한 구간이 섞인 기록',
        carUntil: 0.4,
      ),
      await _hike(
        sanseong,
        userId: userId,
        start: daysAgo(13, 9),
        upSecondsPer10m: 13,
        title: '$demoTitlePrefix 산성마을 62%에서 하산',
        turnAt: 0.62,
      ),
      await _hike(
        beomeosa,
        userId: userId,
        start: daysAgo(6, 8),
        upSecondsPer10m: 12,
        title: '$demoTitlePrefix 금정산 두 번째 산행',
      ),
      await _hike(
        beomeosa,
        userId: userId,
        start: daysAgo(2, 7),
        upSecondsPer10m: 10,
        title: '$demoTitlePrefix 금정산 세 번째 산행',
      ),
    ];
  }

  /// 코스를 따라 [turnAt] 지점(1이면 정상)까지 올랐다가 같은 길로 내려온다.
  /// - [pauseAt]: 그 지점에서 20분 일시정지했다가 다시 시작한다.
  /// - [carUntil]: 처음부터 그 지점까지는 차로 이동한 것처럼 빠르다(시속 36km).
  Future<String> _hike(
    Course course, {
    required String userId,
    required DateTime start,
    required int upSecondsPer10m,
    required String title,
    double turnAt = 1,
    double? pauseAt,
    double? carUntil,
  }) async {
    final path = _resample(course.path, 10);
    final length = (path.length - 1) * 10.0;
    // 코스 길이에 맞춘 그럴듯한 고도: 출발 60m, 평균 경사 약 16% (최대 750m 오름).
    // 60~72% 지점은 경사 36% 급경사 (위험 구간 표시 확인용)
    final gain = math.min(750.0, length * 0.16);
    const steepFrom = 0.6, steepTo = 0.72, steepLen = steepTo - steepFrom;
    final steepGain = math.min(0.36 * steepLen * length, gain * 0.5);
    final gentleGain = gain - steepGain;
    double climbed(double x) {
      if (x <= steepFrom) return gentleGain * x / (1 - steepLen);
      if (x <= steepTo) {
        return gentleGain * steepFrom / (1 - steepLen) +
            steepGain * (x - steepFrom) / steepLen;
      }
      return gentleGain * (x - steepLen) / (1 - steepLen) + steepGain;
    }

    double altitudeAt(int i) =>
        60 + climbed(i / (path.length - 1)) + math.sin(i / 7) * 4;

    final top = ((path.length - 1) * turnAt).round();
    final pauseIndex = pauseAt == null
        ? null
        : ((path.length - 1) * pauseAt).round();
    final carIndex = carUntil == null
        ? -1
        : ((path.length - 1) * carUntil).round();
    final w = _Writer(_recording, await _recording.start(start, userId: userId));

    // 오르막: 후반으로 갈수록 조금씩 느려진다 (피로도 분석 확인용)
    // 40% 지점에서 3분 쉬어 간다 (휴식 구간 표시 확인용)
    final restAt = (top * 0.4).round();
    for (var i = 0; i <= top; i++) {
      await w.add(path[i], altitudeAt(i));
      if (i == restAt && i > carIndex) await w.stay(path[i], altitudeAt(i), 3);
      if (i == pauseIndex) w.pause(const Duration(minutes: 20));
      final slowdown = i > path.length / 2 ? 3 : 0;
      w.wait(Duration(seconds: i < carIndex ? 1 : upSecondsPer10m + slowdown));
    }
    // 정상(또는 돌아선 곳)에서 쉬기
    await w.stay(path[top], altitudeAt(top), turnAt >= 1 ? 10 : 3);
    // 같은 길로 내려오기
    for (var i = top; i >= 0; i--) {
      w.wait(const Duration(seconds: 8));
      await w.add(path[i], altitudeAt(i));
    }
    return w.finish(title);
  }

  /// 산이 아닌 평지 공원을 1.5km 걸었다가 돌아온다. (등록된 코스와 겹치지 않는다)
  Future<String> _parkWalk({
    required String userId,
    required DateTime start,
    required String title,
  }) async {
    const from = GeoPoint(35.1655, 129.0560); // 부산시민공원 근처 평지
    final path = [
      for (var i = 0; i <= 150; i++)
        GeoPoint(from.lat + i * 10 / 111320, from.lon),
    ];
    final w = _Writer(_recording, await _recording.start(start, userId: userId));
    for (final p in [...path, ...path.reversed.skip(1)]) {
      await w.add(p, 22 + math.sin(p.lat * 4000) * 2);
      w.wait(const Duration(seconds: 9));
    }
    return w.finish(title);
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

/// 기록 하나에 점을 차례로 넣는다. GPS처럼 조금씩 흔든다.
class _Writer {
  _Writer(this._recording, RecordingSession session)
    : _id = session.activityId,
      _t = session.startedAt;

  final RecordingRepository _recording;
  final String _id;
  final _calculator = TrackStatsCalculator();
  DateTime _t;
  int _n = 0;
  int _segment = 0;

  void wait(Duration d) => _t = _t.add(d);

  /// 일시정지: 시간이 흐르고 다음 점부터 새 구간이 된다.
  void pause(Duration d) {
    _t = _t.add(d);
    _segment++;
  }

  /// 제자리에서 [minutes]분 쉰다 (1분마다 점 하나).
  Future<void> stay(GeoPoint p, double altitude, int minutes) async {
    for (var k = 0; k < minutes; k++) {
      wait(const Duration(minutes: 1));
      await add(p, altitude);
    }
  }

  Future<void> add(GeoPoint p, double altitude) async {
    // 결정적인 흔들림 (최대 약 4m)
    final dLat = math.sin(_n * 1.3) * 4 / 111320;
    final dLon =
        math.cos(_n * 1.9) * 4 / (111320 * math.cos(p.lat * math.pi / 180));
    final point = TrackPoint(
      segment: _segment,
      latitude: p.lat + dLat,
      longitude: p.lon + dLon,
      altitude: altitude,
      accuracy: 5 + (_n % 4).toDouble(),
      recordedAt: _t,
    );
    await _recording.addPoint(_id, point);
    _calculator.add(point);
    _n++;
  }

  Future<String> finish(String title) async {
    await _recording.finish(
      _id,
      endedAt: _t,
      stats: _calculator.stats,
      title: title,
    );
    return _id;
  }
}

final demoActivityGeneratorProvider = Provider<DemoActivityGenerator>((ref) {
  return DemoActivityGenerator(
    ref.watch(recordingRepositoryProvider),
    ref.watch(activitiesRepositoryProvider),
  );
});

/// 시연용 기록에 쓸 코스 목록
final demoCoursesProvider = FutureProvider.autoDispose<List<Course>>(
  (ref) => ref.watch(courseRepositoryProvider).watchAll().first,
);
