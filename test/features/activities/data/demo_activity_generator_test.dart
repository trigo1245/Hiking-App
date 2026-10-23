import 'package:flutter_test/flutter_test.dart';
import 'package:hiking_app/features/activities/data/activities_repository.dart';
import 'package:hiking_app/features/activities/data/demo_activity_generator.dart';
import 'package:hiking_app/features/courses/domain/course_matching.dart';
import 'package:hiking_app/features/recording/data/recording_repository.dart';
import 'package:hiking_app/features/recording/domain/track_stats.dart';

import '../../../helpers/course_walk.dart';
import '../../../helpers/pump_app.dart';

void main() {
  final now = DateTime(2026, 10, 24, 12);

  test('시연용 기록 8개가 정한 상황대로 판정된다 (완주·진행률·속도 이상·개인 기록)', () async {
    final db = testDatabase();
    final recording = RecordingRepository(db);
    final courses = demoCourses();

    final ids = await DemoActivityGenerator(
      recording,
      ActivitiesRepository(db),
    ).createDemoHikes(courses: courses, userId: 'u1', now: now);
    expect(ids, hasLength(8));

    final results = <String, String>{};
    for (final id in ids) {
      final summary = await recording.loadSummary(id);
      final points = await recording.loadPoints(id);
      if (summary.isFlagged) {
        results[summary.title] = '속도 이상';
        continue;
      }
      final done = CourseMatcher.matchAll(courses, points);
      final partial = CourseMatcher.progressAll(courses, points);
      results[summary.title] = [
        for (final c in done) '완주 ${c.courseId}',
        for (final p in partial)
          '${p.courseId} ${(p.progress * 100).round() ~/ 10 * 10}%대',
      ].join(', ');
    }

    expect(results, {
      '시연용 금정산 첫 산행': '완주 geumjeongsan-beomeosa',
      '시연용 승학산 동아대 산행': '완주 seunghaksan-donga',
      '시연용 시민공원 산책': '',
      '시연용 구덕 코스 30%에서 하산': 'seunghaksan-gudeok 30%대',
      '시연용 차로 이동한 구간이 섞인 기록': '속도 이상',
      '시연용 산성마을 62%에서 하산': 'geumjeongsan-sanseong 60%대',
      '시연용 금정산 두 번째 산행': '완주 geumjeongsan-beomeosa',
      '시연용 금정산 세 번째 산행': '완주 geumjeongsan-beomeosa',
    });
  });

  test('범어사 코스는 회차가 갈수록 빨라지고, 첫 산행에는 일시정지 구간이 있다', () async {
    final db = testDatabase();
    final recording = RecordingRepository(db);
    final courses = demoCourses();
    final ids = await DemoActivityGenerator(
      recording,
      ActivitiesRepository(db),
    ).createDemoHikes(courses: courses, userId: 'u1', now: now);

    final beomeosa = courses.first;
    final ascents = [
      for (final i in [0, 6, 7])
        CourseMatcher.match(beomeosa, await recording.loadPoints(ids[i]))!
            .ascent,
    ];
    expect(ascents[0], greaterThan(ascents[1]));
    expect(ascents[1], greaterThan(ascents[2]));

    final first = await recording.loadPoints(ids[0]);
    expect(first.map((p) => p.segment).toSet(), {0, 1});
  });

  test('다시 만들면 이전 시연용 기록을 지우고 새로 만든다 (다른 기록은 그대로)', () async {
    final db = testDatabase();
    final recording = RecordingRepository(db);
    final activities = ActivitiesRepository(db);
    final generator = DemoActivityGenerator(recording, activities);

    // 사용자가 직접 남긴 기록 하나
    final mine = await recording.start(now, userId: 'u1');
    await recording.finish(
      mine.activityId,
      endedAt: now,
      stats: TrackStatsCalculator().stats,
      title: '10월 24일 등산',
    );

    await generator.createDemoHikes(
      courses: demoCourses(),
      userId: 'u1',
      now: now,
    );
    await generator.createDemoHikes(
      courses: demoCourses(),
      userId: 'u1',
      now: now,
    );

    final all = await activities.watchFinished('u1').first;
    expect(all, hasLength(9));
    expect(all.where((a) => a.title == '10월 24일 등산'), hasLength(1));

    expect(await generator.removeDemoHikes(userId: 'u1'), 8);
    expect(await activities.watchFinished('u1').first, hasLength(1));
  });
}
