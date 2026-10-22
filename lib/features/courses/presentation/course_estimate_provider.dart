import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../activities/presentation/stats_providers.dart';
import '../data/course_repository.dart';
import '../domain/competition.dart';
import '../domain/course.dart';
import '../domain/course_estimate.dart';
import 'competition_providers.dart';

/// 구독자용 "나에게 맞춘 예상". 코스 고도가 없으면 null.
/// 내 산행 분석·코스 고도는 기기에 있어 인터넷이 없어도 계산된다.
/// (완주자 평균·내 완주 기록은 서버에서 받은 경우에만 함께 보여 준다)
final courseEstimateProvider = FutureProvider.autoDispose
    .family<CourseEstimate?, String>((ref, courseId) async {
      final courses = ref.watch(coursesProvider).value ?? const <Course>[];
      final course = courses.where((c) => c.id == courseId).firstOrNull;
      if (course == null) return null;
      final profile = CourseProfile.of(course);
      if (profile == null) return null;

      final hikes = await ref.watch(myAnalysesProvider.future);
      final completions = await ref.watch(myCompletionsProvider.future);
      final stats = ref.watch(courseStatsProvider(courseId)).value;
      return CourseEstimate.of(
        profile: profile,
        hikes: hikes,
        myCompletions: [
          for (final c in completions ?? const <MyCompletion>[])
            if (c.courseId == courseId) c,
        ],
        communityAverage: (stats != null && stats.completionCount > 0)
            ? stats.averageAscent
            : null,
        officialTimeMin: course.officialTimeMin,
      );
    });
