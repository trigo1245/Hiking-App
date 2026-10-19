import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../courses/data/course_repository.dart';
import '../../courses/domain/course.dart';
import '../../courses/domain/course_matching.dart';
import '../../recording/data/recording_repository.dart';
import '../../recording/domain/track_point.dart';
import '../domain/activity_analysis.dart';
import '../domain/activity_summary.dart';
import 'activities_providers.dart';

/// 기록 상세에 필요한 것: 요약 수치, 위치 원본, 완주한 코스
class ActivityDetail {
  const ActivityDetail({
    required this.summary,
    required this.points,
    required this.completions,
  });

  final ActivitySummary summary;
  final List<TrackPoint> points;

  /// 이 기록으로 완주한 코스 (기기에 저장된 코스로 다시 판정한다)
  final List<(Course, CourseCompletion)> completions;
}

final activityDetailProvider = FutureProvider.autoDispose
    .family<ActivityDetail, String>((ref, id) async {
      final recording = ref.watch(recordingRepositoryProvider);
      // 업로드 상태가 바뀌면(다시 올리기 등) 요약을 새로 읽는다.
      ref.watch(myActivitiesProvider);
      final summary = await recording.loadSummary(id);
      final points = await recording.loadPoints(id);
      final courses = ref.watch(coursesProvider).value ?? const <Course>[];
      return ActivityDetail(
        summary: summary,
        points: points,
        completions: summary.isFlagged
            ? const []
            : [
                for (final c in courses)
                  if (CourseMatcher.match(c, points) case final result?)
                    (c, result),
              ],
      );
    });

/// 구독자용 상세 분석 (구독자 화면에서만 계산한다)
final activityAnalysisProvider = FutureProvider.autoDispose
    .family<ActivityAnalysis, String>((ref, id) async {
      final detail = await ref.watch(activityDetailProvider(id).future);
      return ActivityAnalyzer.analyze(detail.points);
    });

/// 같은 코스를 완주한 내 기록들 (등정 시간 순서가 아니라 날짜 순서)
typedef CourseAttempt = ({String activityId, DateTime date, Duration ascent});

final myCourseAttemptsProvider = FutureProvider.autoDispose
    .family<List<CourseAttempt>, String>((ref, courseId) async {
      final courses = ref.watch(coursesProvider).value ?? const <Course>[];
      final course = courses.where((c) => c.id == courseId).firstOrNull;
      if (course == null) return const [];
      final recording = ref.watch(recordingRepositoryProvider);
      final activities = await ref.watch(myActivitiesProvider.future);
      final attempts = <CourseAttempt>[];
      for (final a in activities) {
        if (a.isFlagged) continue;
        final result = CourseMatcher.match(
          course,
          await recording.loadPoints(a.id),
        );
        if (result != null) {
          attempts.add((
            activityId: a.id,
            date: a.startedAt,
            ascent: result.ascent,
          ));
        }
      }
      attempts.sort((x, y) => x.date.compareTo(y.date));
      return attempts;
    });
