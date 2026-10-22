import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_setup.dart';
import '../domain/course.dart';

/// 서버에서 코스 목록을 받는 창구. 테스트에서는 가짜로 바꿔 끼운다.
abstract interface class CourseRemote {
  Future<List<Course>> fetchCourses();

  /// 코스 수와 마지막 수정 시각만 받는다. (몇십 바이트)
  Future<CatalogVersion> fetchVersion();
}

class SupabaseCourseRemote implements CourseRemote {
  SupabaseCourseRemote(this._client);

  final SupabaseClient _client;

  @override
  Future<List<Course>> fetchCourses() async {
    final rows = await _client.from('course_catalog').select();
    return rows.map(courseFromCatalogRow).toList();
  }

  @override
  Future<CatalogVersion> fetchVersion() async {
    final rows = await _client.rpc<List<dynamic>>('get_course_catalog_version');
    final r = rows.cast<Map<String, dynamic>>().first;
    return CatalogVersion(
      count: r['course_count'] as int,
      latestUpdate: switch (r['latest_update']) {
        final String s => DateTime.parse(s),
        _ => null,
      },
    );
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
    updatedAt: switch (row['updated_at']) {
      final String s => DateTime.parse(s),
      _ => null,
    },
  );
}

final courseRemoteProvider = Provider<CourseRemote>((ref) {
  return SupabaseCourseRemote(ref.watch(supabaseClientProvider));
});
