import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_setup.dart';
import '../domain/course.dart';

/// 서버에서 코스 목록을 받는 창구. 테스트에서는 가짜로 바꿔 끼운다.
abstract interface class CourseRemote {
  Future<List<Course>> fetchCourses();
}

class SupabaseCourseRemote implements CourseRemote {
  SupabaseCourseRemote(this._client);

  final SupabaseClient _client;

  @override
  Future<List<Course>> fetchCourses() async {
    final rows = await _client.from('course_catalog').select();
    return rows.map(courseFromCatalogRow).toList();
  }
}

/// 서버 course_catalog 뷰의 한 행 → [Course]. 테스트를 위해 공개한다.
Course courseFromCatalogRow(Map<String, dynamic> row) {
  final path = row['path'] as Map<String, dynamic>;
  return Course(
    id: row['id'] as String,
    mountainName: row['mountain_name'] as String,
    name: row['name'] as String,
    startName: row['start_name'] as String,
    endName: row['end_name'] as String,
    distanceM: (row['distance_m'] as num).toDouble(),
    officialTimeMin: row['official_time_min'] as int?,
    officialDifficulty: row['official_difficulty'] as String?,
    path: [
      for (final c in (path['coordinates'] as List).cast<List>())
        GeoPoint((c[1] as num).toDouble(), (c[0] as num).toDouble()),
    ],
    summit: GeoPoint(
      (row['summit_lat'] as num).toDouble(),
      (row['summit_lon'] as num).toDouble(),
    ),
  );
}

final courseRemoteProvider = Provider<CourseRemote>((ref) {
  return SupabaseCourseRemote(ref.watch(supabaseClientProvider));
});
