import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

part 'app_database.g.dart';

/// 등산 기록 한 건. 기록 중에도 행이 있어서, 앱이 강제 종료돼도 이어서 기록할 수 있다.
@DataClassName('ActivityRow')
class Activities extends Table {
  /// 기기에서 만든 UUID. 서버 업로드 때도 같은 ID를 써서 중복을 막는다.
  TextColumn get id => text()();

  /// 기록한 사용자의 Supabase ID. 한 기기에서 계정을 바꿔 써도 섞이지 않게 한다.
  /// (스키마 1에서 만든 기록은 null)
  TextColumn get userId => text().nullable()();
  TextColumn get title => text().nullable()();

  /// recording / paused / finished
  TextColumn get status => text()();

  DateTimeColumn get startedAt => dateTime()();
  DateTimeColumn get endedAt => dateTime().nullable()();

  /// 지금까지 일시정지했던 시간의 합
  IntColumn get pausedMs => integer().withDefault(const Constant(0))();

  /// 일시정지 중이면 일시정지를 누른 시각
  DateTimeColumn get pausedAt => dateTime().nullable()();

  /// 일시정지 후 다시 시작할 때마다 1씩 늘어난다. 구간이 다르면 점 사이 거리를 더하지 않는다.
  IntColumn get currentSegment => integer().withDefault(const Constant(0))();

  // 아래는 기록을 끝낼 때 계산해 저장하는 요약 값
  IntColumn get elapsedS => integer().nullable()();
  IntColumn get movingS => integer().nullable()();
  RealColumn get distanceM => real().nullable()();
  RealColumn get elevationGainM => real().nullable()();
  RealColumn get maxAltitudeM => real().nullable()();
  IntColumn get pointCount => integer().nullable()();
  BoolColumn get isFlagged => boolean().withDefault(const Constant(false))();

  /// pending / done / failed (업로드 기능에서 사용)
  TextColumn get uploadStatus =>
      text().withDefault(const Constant('pending'))();

  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// 수집한 위치 원본. 정확도가 나쁜 점도 그대로 저장한다. (계산에서만 제외)
@DataClassName('TrackPointRow')
@TableIndex(name: 'track_points_activity', columns: {#activityId})
class TrackPoints extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get activityId =>
      text().references(Activities, #id, onDelete: KeyAction.cascade)();
  IntColumn get segment => integer()();
  RealColumn get latitude => real()();
  RealColumn get longitude => real()();
  RealColumn get altitude => real().nullable()();
  RealColumn get accuracy => real()();
  RealColumn get speed => real().nullable()();
  DateTimeColumn get recordedAt => dateTime()();
}

@DriftDatabase(tables: [Activities, TrackPoints])
class AppDatabase extends _$AppDatabase {
  /// [executor]를 넘기지 않으면 기기 저장소의 `hiking_app` DB를 연다.
  /// 테스트에서는 메모리 DB를 넘긴다.
  AppDatabase([QueryExecutor? executor])
    : super(executor ?? driftDatabase(name: 'hiking_app'));

  /// 테이블 구조를 바꾸면 1 올리고, 아래 onUpgrade에 바꾸는 방법을 적는다.
  /// (이미 설치된 앱의 DB를 지우지 않고 고치기 위해)
  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (m, from, to) async {
      if (from < 2) await m.addColumn(activities, activities.userId);
    },
    beforeOpen: (details) async {
      // 기록을 지우면 위치 점도 함께 지워지도록 외래 키를 켠다.
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});
