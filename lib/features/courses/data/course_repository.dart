import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../domain/course.dart';
import 'course_remote.dart';

/// 기기에 저장해 둔 코스. 지도는 항상 여기서 읽는다(오프라인에서도 보이도록).
class CourseRepository {
  CourseRepository(this._db, this._remote);

  final AppDatabase _db;
  final CourseRemote _remote;

  Stream<List<Course>> watchAll() =>
      (_db.select(_db.courses)
            ..orderBy([(c) => OrderingTerm.asc(c.mountainName)]))
          .watch()
          .map((rows) => rows.map(_toCourse).toList());

  /// 기기에 저장된 코스의 버전 (코스 수, 서버 기준 마지막 수정 시각)
  Future<CatalogVersion> localVersion() async {
    final count = _db.courses.id.count();
    final latest = _db.courses.updatedAt.max();
    final row = await (_db.selectOnly(
      _db.courses,
    )..addColumns([count, latest])).getSingle();
    return CatalogVersion(
      count: row.read(count) ?? 0,
      latestUpdate: row.read(latest),
    );
  }

  /// 서버의 코스가 바뀌었을 때만 내려받아 기기 저장본을 통째로 바꾼다.
  /// 먼저 버전(코스 수, 마지막 수정 시각)만 물어보고, 같으면 내려받지 않는다.
  /// 인터넷이 없으면 저장본을 그대로 두고 false를 돌려준다.
  Future<bool> sync() async {
    final List<Course> courses;
    try {
      final remote = await _remote.fetchVersion();
      if (remote.sameAs(await localVersion())) return true;
      courses = await _remote.fetchCourses();
    } catch (error) {
      debugPrint('[courses] 코스 받기 실패, 저장해 둔 코스를 씀: $error');
      return false;
    }
    await _db.transaction(() async {
      await _db.delete(_db.courses).go();
      await _db.batch(
        (b) => b.insertAll(_db.courses, [
          for (final c in courses)
            CoursesCompanion.insert(
              id: c.id,
              mountainName: c.mountainName,
              name: c.name,
              startName: c.startName,
              endName: c.endName,
              distanceM: c.distanceM,
              officialTimeMin: Value(c.officialTimeMin),
              officialDifficulty: Value(c.officialDifficulty),
              pathJson: jsonEncode([
                for (final p in c.path) [p.lon, p.lat],
              ]),
              summitLat: c.summit.lat,
              summitLon: c.summit.lon,
              // 서버의 수정 시각을 그대로 저장해야 다음 비교가 맞는다.
              updatedAt: c.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0),
            ),
        ]),
      );
    });
    return true;
  }

  static Course _toCourse(CourseRow r) => Course(
    id: r.id,
    mountainName: r.mountainName,
    name: r.name,
    startName: r.startName,
    endName: r.endName,
    distanceM: r.distanceM,
    officialTimeMin: r.officialTimeMin,
    officialDifficulty: r.officialDifficulty,
    path: [
      for (final c in (jsonDecode(r.pathJson) as List).cast<List>())
        GeoPoint((c[1] as num).toDouble(), (c[0] as num).toDouble()),
    ],
    summit: GeoPoint(r.summitLat, r.summitLon),
    updatedAt: r.updatedAt,
  );
}

final courseRepositoryProvider = Provider<CourseRepository>((ref) {
  return CourseRepository(
    ref.watch(appDatabaseProvider),
    ref.watch(courseRemoteProvider),
  );
});

/// 기기에 저장된 코스 목록. 바뀌면 자동으로 새로 온다.
final coursesProvider = StreamProvider<List<Course>>((ref) {
  return ref.watch(courseRepositoryProvider).watchAll();
});
