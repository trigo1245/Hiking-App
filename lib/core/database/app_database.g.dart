// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $ActivitiesTable extends Activities
    with TableInfo<$ActivitiesTable, ActivityRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ActivitiesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startedAtMeta = const VerificationMeta(
    'startedAt',
  );
  @override
  late final GeneratedColumn<DateTime> startedAt = GeneratedColumn<DateTime>(
    'started_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endedAtMeta = const VerificationMeta(
    'endedAt',
  );
  @override
  late final GeneratedColumn<DateTime> endedAt = GeneratedColumn<DateTime>(
    'ended_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _pausedMsMeta = const VerificationMeta(
    'pausedMs',
  );
  @override
  late final GeneratedColumn<int> pausedMs = GeneratedColumn<int>(
    'paused_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _pausedAtMeta = const VerificationMeta(
    'pausedAt',
  );
  @override
  late final GeneratedColumn<DateTime> pausedAt = GeneratedColumn<DateTime>(
    'paused_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _currentSegmentMeta = const VerificationMeta(
    'currentSegment',
  );
  @override
  late final GeneratedColumn<int> currentSegment = GeneratedColumn<int>(
    'current_segment',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _elapsedSMeta = const VerificationMeta(
    'elapsedS',
  );
  @override
  late final GeneratedColumn<int> elapsedS = GeneratedColumn<int>(
    'elapsed_s',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _movingSMeta = const VerificationMeta(
    'movingS',
  );
  @override
  late final GeneratedColumn<int> movingS = GeneratedColumn<int>(
    'moving_s',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _distanceMMeta = const VerificationMeta(
    'distanceM',
  );
  @override
  late final GeneratedColumn<double> distanceM = GeneratedColumn<double>(
    'distance_m',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _elevationGainMMeta = const VerificationMeta(
    'elevationGainM',
  );
  @override
  late final GeneratedColumn<double> elevationGainM = GeneratedColumn<double>(
    'elevation_gain_m',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _maxAltitudeMMeta = const VerificationMeta(
    'maxAltitudeM',
  );
  @override
  late final GeneratedColumn<double> maxAltitudeM = GeneratedColumn<double>(
    'max_altitude_m',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _pointCountMeta = const VerificationMeta(
    'pointCount',
  );
  @override
  late final GeneratedColumn<int> pointCount = GeneratedColumn<int>(
    'point_count',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isFlaggedMeta = const VerificationMeta(
    'isFlagged',
  );
  @override
  late final GeneratedColumn<bool> isFlagged = GeneratedColumn<bool>(
    'is_flagged',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_flagged" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _uploadStatusMeta = const VerificationMeta(
    'uploadStatus',
  );
  @override
  late final GeneratedColumn<String> uploadStatus = GeneratedColumn<String>(
    'upload_status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('pending'),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    userId,
    title,
    status,
    startedAt,
    endedAt,
    pausedMs,
    pausedAt,
    currentSegment,
    elapsedS,
    movingS,
    distanceM,
    elevationGainM,
    maxAltitudeM,
    pointCount,
    isFlagged,
    uploadStatus,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'activities';
  @override
  VerificationContext validateIntegrity(
    Insertable<ActivityRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('started_at')) {
      context.handle(
        _startedAtMeta,
        startedAt.isAcceptableOrUnknown(data['started_at']!, _startedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_startedAtMeta);
    }
    if (data.containsKey('ended_at')) {
      context.handle(
        _endedAtMeta,
        endedAt.isAcceptableOrUnknown(data['ended_at']!, _endedAtMeta),
      );
    }
    if (data.containsKey('paused_ms')) {
      context.handle(
        _pausedMsMeta,
        pausedMs.isAcceptableOrUnknown(data['paused_ms']!, _pausedMsMeta),
      );
    }
    if (data.containsKey('paused_at')) {
      context.handle(
        _pausedAtMeta,
        pausedAt.isAcceptableOrUnknown(data['paused_at']!, _pausedAtMeta),
      );
    }
    if (data.containsKey('current_segment')) {
      context.handle(
        _currentSegmentMeta,
        currentSegment.isAcceptableOrUnknown(
          data['current_segment']!,
          _currentSegmentMeta,
        ),
      );
    }
    if (data.containsKey('elapsed_s')) {
      context.handle(
        _elapsedSMeta,
        elapsedS.isAcceptableOrUnknown(data['elapsed_s']!, _elapsedSMeta),
      );
    }
    if (data.containsKey('moving_s')) {
      context.handle(
        _movingSMeta,
        movingS.isAcceptableOrUnknown(data['moving_s']!, _movingSMeta),
      );
    }
    if (data.containsKey('distance_m')) {
      context.handle(
        _distanceMMeta,
        distanceM.isAcceptableOrUnknown(data['distance_m']!, _distanceMMeta),
      );
    }
    if (data.containsKey('elevation_gain_m')) {
      context.handle(
        _elevationGainMMeta,
        elevationGainM.isAcceptableOrUnknown(
          data['elevation_gain_m']!,
          _elevationGainMMeta,
        ),
      );
    }
    if (data.containsKey('max_altitude_m')) {
      context.handle(
        _maxAltitudeMMeta,
        maxAltitudeM.isAcceptableOrUnknown(
          data['max_altitude_m']!,
          _maxAltitudeMMeta,
        ),
      );
    }
    if (data.containsKey('point_count')) {
      context.handle(
        _pointCountMeta,
        pointCount.isAcceptableOrUnknown(data['point_count']!, _pointCountMeta),
      );
    }
    if (data.containsKey('is_flagged')) {
      context.handle(
        _isFlaggedMeta,
        isFlagged.isAcceptableOrUnknown(data['is_flagged']!, _isFlaggedMeta),
      );
    }
    if (data.containsKey('upload_status')) {
      context.handle(
        _uploadStatusMeta,
        uploadStatus.isAcceptableOrUnknown(
          data['upload_status']!,
          _uploadStatusMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ActivityRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ActivityRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      ),
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      ),
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      startedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}started_at'],
      )!,
      endedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}ended_at'],
      ),
      pausedMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}paused_ms'],
      )!,
      pausedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}paused_at'],
      ),
      currentSegment: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}current_segment'],
      )!,
      elapsedS: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}elapsed_s'],
      ),
      movingS: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}moving_s'],
      ),
      distanceM: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}distance_m'],
      ),
      elevationGainM: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}elevation_gain_m'],
      ),
      maxAltitudeM: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}max_altitude_m'],
      ),
      pointCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}point_count'],
      ),
      isFlagged: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_flagged'],
      )!,
      uploadStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}upload_status'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $ActivitiesTable createAlias(String alias) {
    return $ActivitiesTable(attachedDatabase, alias);
  }
}

class ActivityRow extends DataClass implements Insertable<ActivityRow> {
  /// 기기에서 만든 UUID. 서버 업로드 때도 같은 ID를 써서 중복을 막는다.
  final String id;

  /// 기록한 사용자의 Supabase ID. 한 기기에서 계정을 바꿔 써도 섞이지 않게 한다.
  /// (스키마 1에서 만든 기록은 null)
  final String? userId;
  final String? title;

  /// recording / paused / finished
  final String status;
  final DateTime startedAt;
  final DateTime? endedAt;

  /// 지금까지 일시정지했던 시간의 합
  final int pausedMs;

  /// 일시정지 중이면 일시정지를 누른 시각
  final DateTime? pausedAt;

  /// 일시정지 후 다시 시작할 때마다 1씩 늘어난다. 구간이 다르면 점 사이 거리를 더하지 않는다.
  final int currentSegment;
  final int? elapsedS;
  final int? movingS;
  final double? distanceM;
  final double? elevationGainM;
  final double? maxAltitudeM;
  final int? pointCount;
  final bool isFlagged;

  /// pending / done / failed (업로드 기능에서 사용)
  final String uploadStatus;
  final DateTime createdAt;
  const ActivityRow({
    required this.id,
    this.userId,
    this.title,
    required this.status,
    required this.startedAt,
    this.endedAt,
    required this.pausedMs,
    this.pausedAt,
    required this.currentSegment,
    this.elapsedS,
    this.movingS,
    this.distanceM,
    this.elevationGainM,
    this.maxAltitudeM,
    this.pointCount,
    required this.isFlagged,
    required this.uploadStatus,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || userId != null) {
      map['user_id'] = Variable<String>(userId);
    }
    if (!nullToAbsent || title != null) {
      map['title'] = Variable<String>(title);
    }
    map['status'] = Variable<String>(status);
    map['started_at'] = Variable<DateTime>(startedAt);
    if (!nullToAbsent || endedAt != null) {
      map['ended_at'] = Variable<DateTime>(endedAt);
    }
    map['paused_ms'] = Variable<int>(pausedMs);
    if (!nullToAbsent || pausedAt != null) {
      map['paused_at'] = Variable<DateTime>(pausedAt);
    }
    map['current_segment'] = Variable<int>(currentSegment);
    if (!nullToAbsent || elapsedS != null) {
      map['elapsed_s'] = Variable<int>(elapsedS);
    }
    if (!nullToAbsent || movingS != null) {
      map['moving_s'] = Variable<int>(movingS);
    }
    if (!nullToAbsent || distanceM != null) {
      map['distance_m'] = Variable<double>(distanceM);
    }
    if (!nullToAbsent || elevationGainM != null) {
      map['elevation_gain_m'] = Variable<double>(elevationGainM);
    }
    if (!nullToAbsent || maxAltitudeM != null) {
      map['max_altitude_m'] = Variable<double>(maxAltitudeM);
    }
    if (!nullToAbsent || pointCount != null) {
      map['point_count'] = Variable<int>(pointCount);
    }
    map['is_flagged'] = Variable<bool>(isFlagged);
    map['upload_status'] = Variable<String>(uploadStatus);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  ActivitiesCompanion toCompanion(bool nullToAbsent) {
    return ActivitiesCompanion(
      id: Value(id),
      userId: userId == null && nullToAbsent
          ? const Value.absent()
          : Value(userId),
      title: title == null && nullToAbsent
          ? const Value.absent()
          : Value(title),
      status: Value(status),
      startedAt: Value(startedAt),
      endedAt: endedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(endedAt),
      pausedMs: Value(pausedMs),
      pausedAt: pausedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(pausedAt),
      currentSegment: Value(currentSegment),
      elapsedS: elapsedS == null && nullToAbsent
          ? const Value.absent()
          : Value(elapsedS),
      movingS: movingS == null && nullToAbsent
          ? const Value.absent()
          : Value(movingS),
      distanceM: distanceM == null && nullToAbsent
          ? const Value.absent()
          : Value(distanceM),
      elevationGainM: elevationGainM == null && nullToAbsent
          ? const Value.absent()
          : Value(elevationGainM),
      maxAltitudeM: maxAltitudeM == null && nullToAbsent
          ? const Value.absent()
          : Value(maxAltitudeM),
      pointCount: pointCount == null && nullToAbsent
          ? const Value.absent()
          : Value(pointCount),
      isFlagged: Value(isFlagged),
      uploadStatus: Value(uploadStatus),
      createdAt: Value(createdAt),
    );
  }

  factory ActivityRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ActivityRow(
      id: serializer.fromJson<String>(json['id']),
      userId: serializer.fromJson<String?>(json['userId']),
      title: serializer.fromJson<String?>(json['title']),
      status: serializer.fromJson<String>(json['status']),
      startedAt: serializer.fromJson<DateTime>(json['startedAt']),
      endedAt: serializer.fromJson<DateTime?>(json['endedAt']),
      pausedMs: serializer.fromJson<int>(json['pausedMs']),
      pausedAt: serializer.fromJson<DateTime?>(json['pausedAt']),
      currentSegment: serializer.fromJson<int>(json['currentSegment']),
      elapsedS: serializer.fromJson<int?>(json['elapsedS']),
      movingS: serializer.fromJson<int?>(json['movingS']),
      distanceM: serializer.fromJson<double?>(json['distanceM']),
      elevationGainM: serializer.fromJson<double?>(json['elevationGainM']),
      maxAltitudeM: serializer.fromJson<double?>(json['maxAltitudeM']),
      pointCount: serializer.fromJson<int?>(json['pointCount']),
      isFlagged: serializer.fromJson<bool>(json['isFlagged']),
      uploadStatus: serializer.fromJson<String>(json['uploadStatus']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'userId': serializer.toJson<String?>(userId),
      'title': serializer.toJson<String?>(title),
      'status': serializer.toJson<String>(status),
      'startedAt': serializer.toJson<DateTime>(startedAt),
      'endedAt': serializer.toJson<DateTime?>(endedAt),
      'pausedMs': serializer.toJson<int>(pausedMs),
      'pausedAt': serializer.toJson<DateTime?>(pausedAt),
      'currentSegment': serializer.toJson<int>(currentSegment),
      'elapsedS': serializer.toJson<int?>(elapsedS),
      'movingS': serializer.toJson<int?>(movingS),
      'distanceM': serializer.toJson<double?>(distanceM),
      'elevationGainM': serializer.toJson<double?>(elevationGainM),
      'maxAltitudeM': serializer.toJson<double?>(maxAltitudeM),
      'pointCount': serializer.toJson<int?>(pointCount),
      'isFlagged': serializer.toJson<bool>(isFlagged),
      'uploadStatus': serializer.toJson<String>(uploadStatus),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  ActivityRow copyWith({
    String? id,
    Value<String?> userId = const Value.absent(),
    Value<String?> title = const Value.absent(),
    String? status,
    DateTime? startedAt,
    Value<DateTime?> endedAt = const Value.absent(),
    int? pausedMs,
    Value<DateTime?> pausedAt = const Value.absent(),
    int? currentSegment,
    Value<int?> elapsedS = const Value.absent(),
    Value<int?> movingS = const Value.absent(),
    Value<double?> distanceM = const Value.absent(),
    Value<double?> elevationGainM = const Value.absent(),
    Value<double?> maxAltitudeM = const Value.absent(),
    Value<int?> pointCount = const Value.absent(),
    bool? isFlagged,
    String? uploadStatus,
    DateTime? createdAt,
  }) => ActivityRow(
    id: id ?? this.id,
    userId: userId.present ? userId.value : this.userId,
    title: title.present ? title.value : this.title,
    status: status ?? this.status,
    startedAt: startedAt ?? this.startedAt,
    endedAt: endedAt.present ? endedAt.value : this.endedAt,
    pausedMs: pausedMs ?? this.pausedMs,
    pausedAt: pausedAt.present ? pausedAt.value : this.pausedAt,
    currentSegment: currentSegment ?? this.currentSegment,
    elapsedS: elapsedS.present ? elapsedS.value : this.elapsedS,
    movingS: movingS.present ? movingS.value : this.movingS,
    distanceM: distanceM.present ? distanceM.value : this.distanceM,
    elevationGainM: elevationGainM.present
        ? elevationGainM.value
        : this.elevationGainM,
    maxAltitudeM: maxAltitudeM.present ? maxAltitudeM.value : this.maxAltitudeM,
    pointCount: pointCount.present ? pointCount.value : this.pointCount,
    isFlagged: isFlagged ?? this.isFlagged,
    uploadStatus: uploadStatus ?? this.uploadStatus,
    createdAt: createdAt ?? this.createdAt,
  );
  ActivityRow copyWithCompanion(ActivitiesCompanion data) {
    return ActivityRow(
      id: data.id.present ? data.id.value : this.id,
      userId: data.userId.present ? data.userId.value : this.userId,
      title: data.title.present ? data.title.value : this.title,
      status: data.status.present ? data.status.value : this.status,
      startedAt: data.startedAt.present ? data.startedAt.value : this.startedAt,
      endedAt: data.endedAt.present ? data.endedAt.value : this.endedAt,
      pausedMs: data.pausedMs.present ? data.pausedMs.value : this.pausedMs,
      pausedAt: data.pausedAt.present ? data.pausedAt.value : this.pausedAt,
      currentSegment: data.currentSegment.present
          ? data.currentSegment.value
          : this.currentSegment,
      elapsedS: data.elapsedS.present ? data.elapsedS.value : this.elapsedS,
      movingS: data.movingS.present ? data.movingS.value : this.movingS,
      distanceM: data.distanceM.present ? data.distanceM.value : this.distanceM,
      elevationGainM: data.elevationGainM.present
          ? data.elevationGainM.value
          : this.elevationGainM,
      maxAltitudeM: data.maxAltitudeM.present
          ? data.maxAltitudeM.value
          : this.maxAltitudeM,
      pointCount: data.pointCount.present
          ? data.pointCount.value
          : this.pointCount,
      isFlagged: data.isFlagged.present ? data.isFlagged.value : this.isFlagged,
      uploadStatus: data.uploadStatus.present
          ? data.uploadStatus.value
          : this.uploadStatus,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ActivityRow(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('title: $title, ')
          ..write('status: $status, ')
          ..write('startedAt: $startedAt, ')
          ..write('endedAt: $endedAt, ')
          ..write('pausedMs: $pausedMs, ')
          ..write('pausedAt: $pausedAt, ')
          ..write('currentSegment: $currentSegment, ')
          ..write('elapsedS: $elapsedS, ')
          ..write('movingS: $movingS, ')
          ..write('distanceM: $distanceM, ')
          ..write('elevationGainM: $elevationGainM, ')
          ..write('maxAltitudeM: $maxAltitudeM, ')
          ..write('pointCount: $pointCount, ')
          ..write('isFlagged: $isFlagged, ')
          ..write('uploadStatus: $uploadStatus, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    userId,
    title,
    status,
    startedAt,
    endedAt,
    pausedMs,
    pausedAt,
    currentSegment,
    elapsedS,
    movingS,
    distanceM,
    elevationGainM,
    maxAltitudeM,
    pointCount,
    isFlagged,
    uploadStatus,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ActivityRow &&
          other.id == this.id &&
          other.userId == this.userId &&
          other.title == this.title &&
          other.status == this.status &&
          other.startedAt == this.startedAt &&
          other.endedAt == this.endedAt &&
          other.pausedMs == this.pausedMs &&
          other.pausedAt == this.pausedAt &&
          other.currentSegment == this.currentSegment &&
          other.elapsedS == this.elapsedS &&
          other.movingS == this.movingS &&
          other.distanceM == this.distanceM &&
          other.elevationGainM == this.elevationGainM &&
          other.maxAltitudeM == this.maxAltitudeM &&
          other.pointCount == this.pointCount &&
          other.isFlagged == this.isFlagged &&
          other.uploadStatus == this.uploadStatus &&
          other.createdAt == this.createdAt);
}

class ActivitiesCompanion extends UpdateCompanion<ActivityRow> {
  final Value<String> id;
  final Value<String?> userId;
  final Value<String?> title;
  final Value<String> status;
  final Value<DateTime> startedAt;
  final Value<DateTime?> endedAt;
  final Value<int> pausedMs;
  final Value<DateTime?> pausedAt;
  final Value<int> currentSegment;
  final Value<int?> elapsedS;
  final Value<int?> movingS;
  final Value<double?> distanceM;
  final Value<double?> elevationGainM;
  final Value<double?> maxAltitudeM;
  final Value<int?> pointCount;
  final Value<bool> isFlagged;
  final Value<String> uploadStatus;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const ActivitiesCompanion({
    this.id = const Value.absent(),
    this.userId = const Value.absent(),
    this.title = const Value.absent(),
    this.status = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.endedAt = const Value.absent(),
    this.pausedMs = const Value.absent(),
    this.pausedAt = const Value.absent(),
    this.currentSegment = const Value.absent(),
    this.elapsedS = const Value.absent(),
    this.movingS = const Value.absent(),
    this.distanceM = const Value.absent(),
    this.elevationGainM = const Value.absent(),
    this.maxAltitudeM = const Value.absent(),
    this.pointCount = const Value.absent(),
    this.isFlagged = const Value.absent(),
    this.uploadStatus = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ActivitiesCompanion.insert({
    required String id,
    this.userId = const Value.absent(),
    this.title = const Value.absent(),
    required String status,
    required DateTime startedAt,
    this.endedAt = const Value.absent(),
    this.pausedMs = const Value.absent(),
    this.pausedAt = const Value.absent(),
    this.currentSegment = const Value.absent(),
    this.elapsedS = const Value.absent(),
    this.movingS = const Value.absent(),
    this.distanceM = const Value.absent(),
    this.elevationGainM = const Value.absent(),
    this.maxAltitudeM = const Value.absent(),
    this.pointCount = const Value.absent(),
    this.isFlagged = const Value.absent(),
    this.uploadStatus = const Value.absent(),
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       status = Value(status),
       startedAt = Value(startedAt),
       createdAt = Value(createdAt);
  static Insertable<ActivityRow> custom({
    Expression<String>? id,
    Expression<String>? userId,
    Expression<String>? title,
    Expression<String>? status,
    Expression<DateTime>? startedAt,
    Expression<DateTime>? endedAt,
    Expression<int>? pausedMs,
    Expression<DateTime>? pausedAt,
    Expression<int>? currentSegment,
    Expression<int>? elapsedS,
    Expression<int>? movingS,
    Expression<double>? distanceM,
    Expression<double>? elevationGainM,
    Expression<double>? maxAltitudeM,
    Expression<int>? pointCount,
    Expression<bool>? isFlagged,
    Expression<String>? uploadStatus,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (userId != null) 'user_id': userId,
      if (title != null) 'title': title,
      if (status != null) 'status': status,
      if (startedAt != null) 'started_at': startedAt,
      if (endedAt != null) 'ended_at': endedAt,
      if (pausedMs != null) 'paused_ms': pausedMs,
      if (pausedAt != null) 'paused_at': pausedAt,
      if (currentSegment != null) 'current_segment': currentSegment,
      if (elapsedS != null) 'elapsed_s': elapsedS,
      if (movingS != null) 'moving_s': movingS,
      if (distanceM != null) 'distance_m': distanceM,
      if (elevationGainM != null) 'elevation_gain_m': elevationGainM,
      if (maxAltitudeM != null) 'max_altitude_m': maxAltitudeM,
      if (pointCount != null) 'point_count': pointCount,
      if (isFlagged != null) 'is_flagged': isFlagged,
      if (uploadStatus != null) 'upload_status': uploadStatus,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ActivitiesCompanion copyWith({
    Value<String>? id,
    Value<String?>? userId,
    Value<String?>? title,
    Value<String>? status,
    Value<DateTime>? startedAt,
    Value<DateTime?>? endedAt,
    Value<int>? pausedMs,
    Value<DateTime?>? pausedAt,
    Value<int>? currentSegment,
    Value<int?>? elapsedS,
    Value<int?>? movingS,
    Value<double?>? distanceM,
    Value<double?>? elevationGainM,
    Value<double?>? maxAltitudeM,
    Value<int?>? pointCount,
    Value<bool>? isFlagged,
    Value<String>? uploadStatus,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return ActivitiesCompanion(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      status: status ?? this.status,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      pausedMs: pausedMs ?? this.pausedMs,
      pausedAt: pausedAt ?? this.pausedAt,
      currentSegment: currentSegment ?? this.currentSegment,
      elapsedS: elapsedS ?? this.elapsedS,
      movingS: movingS ?? this.movingS,
      distanceM: distanceM ?? this.distanceM,
      elevationGainM: elevationGainM ?? this.elevationGainM,
      maxAltitudeM: maxAltitudeM ?? this.maxAltitudeM,
      pointCount: pointCount ?? this.pointCount,
      isFlagged: isFlagged ?? this.isFlagged,
      uploadStatus: uploadStatus ?? this.uploadStatus,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (startedAt.present) {
      map['started_at'] = Variable<DateTime>(startedAt.value);
    }
    if (endedAt.present) {
      map['ended_at'] = Variable<DateTime>(endedAt.value);
    }
    if (pausedMs.present) {
      map['paused_ms'] = Variable<int>(pausedMs.value);
    }
    if (pausedAt.present) {
      map['paused_at'] = Variable<DateTime>(pausedAt.value);
    }
    if (currentSegment.present) {
      map['current_segment'] = Variable<int>(currentSegment.value);
    }
    if (elapsedS.present) {
      map['elapsed_s'] = Variable<int>(elapsedS.value);
    }
    if (movingS.present) {
      map['moving_s'] = Variable<int>(movingS.value);
    }
    if (distanceM.present) {
      map['distance_m'] = Variable<double>(distanceM.value);
    }
    if (elevationGainM.present) {
      map['elevation_gain_m'] = Variable<double>(elevationGainM.value);
    }
    if (maxAltitudeM.present) {
      map['max_altitude_m'] = Variable<double>(maxAltitudeM.value);
    }
    if (pointCount.present) {
      map['point_count'] = Variable<int>(pointCount.value);
    }
    if (isFlagged.present) {
      map['is_flagged'] = Variable<bool>(isFlagged.value);
    }
    if (uploadStatus.present) {
      map['upload_status'] = Variable<String>(uploadStatus.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ActivitiesCompanion(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('title: $title, ')
          ..write('status: $status, ')
          ..write('startedAt: $startedAt, ')
          ..write('endedAt: $endedAt, ')
          ..write('pausedMs: $pausedMs, ')
          ..write('pausedAt: $pausedAt, ')
          ..write('currentSegment: $currentSegment, ')
          ..write('elapsedS: $elapsedS, ')
          ..write('movingS: $movingS, ')
          ..write('distanceM: $distanceM, ')
          ..write('elevationGainM: $elevationGainM, ')
          ..write('maxAltitudeM: $maxAltitudeM, ')
          ..write('pointCount: $pointCount, ')
          ..write('isFlagged: $isFlagged, ')
          ..write('uploadStatus: $uploadStatus, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TrackPointsTable extends TrackPoints
    with TableInfo<$TrackPointsTable, TrackPointRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TrackPointsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _activityIdMeta = const VerificationMeta(
    'activityId',
  );
  @override
  late final GeneratedColumn<String> activityId = GeneratedColumn<String>(
    'activity_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES activities (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _segmentMeta = const VerificationMeta(
    'segment',
  );
  @override
  late final GeneratedColumn<int> segment = GeneratedColumn<int>(
    'segment',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _latitudeMeta = const VerificationMeta(
    'latitude',
  );
  @override
  late final GeneratedColumn<double> latitude = GeneratedColumn<double>(
    'latitude',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _longitudeMeta = const VerificationMeta(
    'longitude',
  );
  @override
  late final GeneratedColumn<double> longitude = GeneratedColumn<double>(
    'longitude',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _altitudeMeta = const VerificationMeta(
    'altitude',
  );
  @override
  late final GeneratedColumn<double> altitude = GeneratedColumn<double>(
    'altitude',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _accuracyMeta = const VerificationMeta(
    'accuracy',
  );
  @override
  late final GeneratedColumn<double> accuracy = GeneratedColumn<double>(
    'accuracy',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _speedMeta = const VerificationMeta('speed');
  @override
  late final GeneratedColumn<double> speed = GeneratedColumn<double>(
    'speed',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _recordedAtMeta = const VerificationMeta(
    'recordedAt',
  );
  @override
  late final GeneratedColumn<DateTime> recordedAt = GeneratedColumn<DateTime>(
    'recorded_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    activityId,
    segment,
    latitude,
    longitude,
    altitude,
    accuracy,
    speed,
    recordedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'track_points';
  @override
  VerificationContext validateIntegrity(
    Insertable<TrackPointRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('activity_id')) {
      context.handle(
        _activityIdMeta,
        activityId.isAcceptableOrUnknown(data['activity_id']!, _activityIdMeta),
      );
    } else if (isInserting) {
      context.missing(_activityIdMeta);
    }
    if (data.containsKey('segment')) {
      context.handle(
        _segmentMeta,
        segment.isAcceptableOrUnknown(data['segment']!, _segmentMeta),
      );
    } else if (isInserting) {
      context.missing(_segmentMeta);
    }
    if (data.containsKey('latitude')) {
      context.handle(
        _latitudeMeta,
        latitude.isAcceptableOrUnknown(data['latitude']!, _latitudeMeta),
      );
    } else if (isInserting) {
      context.missing(_latitudeMeta);
    }
    if (data.containsKey('longitude')) {
      context.handle(
        _longitudeMeta,
        longitude.isAcceptableOrUnknown(data['longitude']!, _longitudeMeta),
      );
    } else if (isInserting) {
      context.missing(_longitudeMeta);
    }
    if (data.containsKey('altitude')) {
      context.handle(
        _altitudeMeta,
        altitude.isAcceptableOrUnknown(data['altitude']!, _altitudeMeta),
      );
    }
    if (data.containsKey('accuracy')) {
      context.handle(
        _accuracyMeta,
        accuracy.isAcceptableOrUnknown(data['accuracy']!, _accuracyMeta),
      );
    } else if (isInserting) {
      context.missing(_accuracyMeta);
    }
    if (data.containsKey('speed')) {
      context.handle(
        _speedMeta,
        speed.isAcceptableOrUnknown(data['speed']!, _speedMeta),
      );
    }
    if (data.containsKey('recorded_at')) {
      context.handle(
        _recordedAtMeta,
        recordedAt.isAcceptableOrUnknown(data['recorded_at']!, _recordedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_recordedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TrackPointRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TrackPointRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      activityId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}activity_id'],
      )!,
      segment: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}segment'],
      )!,
      latitude: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}latitude'],
      )!,
      longitude: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}longitude'],
      )!,
      altitude: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}altitude'],
      ),
      accuracy: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}accuracy'],
      )!,
      speed: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}speed'],
      ),
      recordedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}recorded_at'],
      )!,
    );
  }

  @override
  $TrackPointsTable createAlias(String alias) {
    return $TrackPointsTable(attachedDatabase, alias);
  }
}

class TrackPointRow extends DataClass implements Insertable<TrackPointRow> {
  final int id;
  final String activityId;
  final int segment;
  final double latitude;
  final double longitude;
  final double? altitude;
  final double accuracy;
  final double? speed;
  final DateTime recordedAt;
  const TrackPointRow({
    required this.id,
    required this.activityId,
    required this.segment,
    required this.latitude,
    required this.longitude,
    this.altitude,
    required this.accuracy,
    this.speed,
    required this.recordedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['activity_id'] = Variable<String>(activityId);
    map['segment'] = Variable<int>(segment);
    map['latitude'] = Variable<double>(latitude);
    map['longitude'] = Variable<double>(longitude);
    if (!nullToAbsent || altitude != null) {
      map['altitude'] = Variable<double>(altitude);
    }
    map['accuracy'] = Variable<double>(accuracy);
    if (!nullToAbsent || speed != null) {
      map['speed'] = Variable<double>(speed);
    }
    map['recorded_at'] = Variable<DateTime>(recordedAt);
    return map;
  }

  TrackPointsCompanion toCompanion(bool nullToAbsent) {
    return TrackPointsCompanion(
      id: Value(id),
      activityId: Value(activityId),
      segment: Value(segment),
      latitude: Value(latitude),
      longitude: Value(longitude),
      altitude: altitude == null && nullToAbsent
          ? const Value.absent()
          : Value(altitude),
      accuracy: Value(accuracy),
      speed: speed == null && nullToAbsent
          ? const Value.absent()
          : Value(speed),
      recordedAt: Value(recordedAt),
    );
  }

  factory TrackPointRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TrackPointRow(
      id: serializer.fromJson<int>(json['id']),
      activityId: serializer.fromJson<String>(json['activityId']),
      segment: serializer.fromJson<int>(json['segment']),
      latitude: serializer.fromJson<double>(json['latitude']),
      longitude: serializer.fromJson<double>(json['longitude']),
      altitude: serializer.fromJson<double?>(json['altitude']),
      accuracy: serializer.fromJson<double>(json['accuracy']),
      speed: serializer.fromJson<double?>(json['speed']),
      recordedAt: serializer.fromJson<DateTime>(json['recordedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'activityId': serializer.toJson<String>(activityId),
      'segment': serializer.toJson<int>(segment),
      'latitude': serializer.toJson<double>(latitude),
      'longitude': serializer.toJson<double>(longitude),
      'altitude': serializer.toJson<double?>(altitude),
      'accuracy': serializer.toJson<double>(accuracy),
      'speed': serializer.toJson<double?>(speed),
      'recordedAt': serializer.toJson<DateTime>(recordedAt),
    };
  }

  TrackPointRow copyWith({
    int? id,
    String? activityId,
    int? segment,
    double? latitude,
    double? longitude,
    Value<double?> altitude = const Value.absent(),
    double? accuracy,
    Value<double?> speed = const Value.absent(),
    DateTime? recordedAt,
  }) => TrackPointRow(
    id: id ?? this.id,
    activityId: activityId ?? this.activityId,
    segment: segment ?? this.segment,
    latitude: latitude ?? this.latitude,
    longitude: longitude ?? this.longitude,
    altitude: altitude.present ? altitude.value : this.altitude,
    accuracy: accuracy ?? this.accuracy,
    speed: speed.present ? speed.value : this.speed,
    recordedAt: recordedAt ?? this.recordedAt,
  );
  TrackPointRow copyWithCompanion(TrackPointsCompanion data) {
    return TrackPointRow(
      id: data.id.present ? data.id.value : this.id,
      activityId: data.activityId.present
          ? data.activityId.value
          : this.activityId,
      segment: data.segment.present ? data.segment.value : this.segment,
      latitude: data.latitude.present ? data.latitude.value : this.latitude,
      longitude: data.longitude.present ? data.longitude.value : this.longitude,
      altitude: data.altitude.present ? data.altitude.value : this.altitude,
      accuracy: data.accuracy.present ? data.accuracy.value : this.accuracy,
      speed: data.speed.present ? data.speed.value : this.speed,
      recordedAt: data.recordedAt.present
          ? data.recordedAt.value
          : this.recordedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TrackPointRow(')
          ..write('id: $id, ')
          ..write('activityId: $activityId, ')
          ..write('segment: $segment, ')
          ..write('latitude: $latitude, ')
          ..write('longitude: $longitude, ')
          ..write('altitude: $altitude, ')
          ..write('accuracy: $accuracy, ')
          ..write('speed: $speed, ')
          ..write('recordedAt: $recordedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    activityId,
    segment,
    latitude,
    longitude,
    altitude,
    accuracy,
    speed,
    recordedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TrackPointRow &&
          other.id == this.id &&
          other.activityId == this.activityId &&
          other.segment == this.segment &&
          other.latitude == this.latitude &&
          other.longitude == this.longitude &&
          other.altitude == this.altitude &&
          other.accuracy == this.accuracy &&
          other.speed == this.speed &&
          other.recordedAt == this.recordedAt);
}

class TrackPointsCompanion extends UpdateCompanion<TrackPointRow> {
  final Value<int> id;
  final Value<String> activityId;
  final Value<int> segment;
  final Value<double> latitude;
  final Value<double> longitude;
  final Value<double?> altitude;
  final Value<double> accuracy;
  final Value<double?> speed;
  final Value<DateTime> recordedAt;
  const TrackPointsCompanion({
    this.id = const Value.absent(),
    this.activityId = const Value.absent(),
    this.segment = const Value.absent(),
    this.latitude = const Value.absent(),
    this.longitude = const Value.absent(),
    this.altitude = const Value.absent(),
    this.accuracy = const Value.absent(),
    this.speed = const Value.absent(),
    this.recordedAt = const Value.absent(),
  });
  TrackPointsCompanion.insert({
    this.id = const Value.absent(),
    required String activityId,
    required int segment,
    required double latitude,
    required double longitude,
    this.altitude = const Value.absent(),
    required double accuracy,
    this.speed = const Value.absent(),
    required DateTime recordedAt,
  }) : activityId = Value(activityId),
       segment = Value(segment),
       latitude = Value(latitude),
       longitude = Value(longitude),
       accuracy = Value(accuracy),
       recordedAt = Value(recordedAt);
  static Insertable<TrackPointRow> custom({
    Expression<int>? id,
    Expression<String>? activityId,
    Expression<int>? segment,
    Expression<double>? latitude,
    Expression<double>? longitude,
    Expression<double>? altitude,
    Expression<double>? accuracy,
    Expression<double>? speed,
    Expression<DateTime>? recordedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (activityId != null) 'activity_id': activityId,
      if (segment != null) 'segment': segment,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (altitude != null) 'altitude': altitude,
      if (accuracy != null) 'accuracy': accuracy,
      if (speed != null) 'speed': speed,
      if (recordedAt != null) 'recorded_at': recordedAt,
    });
  }

  TrackPointsCompanion copyWith({
    Value<int>? id,
    Value<String>? activityId,
    Value<int>? segment,
    Value<double>? latitude,
    Value<double>? longitude,
    Value<double?>? altitude,
    Value<double>? accuracy,
    Value<double?>? speed,
    Value<DateTime>? recordedAt,
  }) {
    return TrackPointsCompanion(
      id: id ?? this.id,
      activityId: activityId ?? this.activityId,
      segment: segment ?? this.segment,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      altitude: altitude ?? this.altitude,
      accuracy: accuracy ?? this.accuracy,
      speed: speed ?? this.speed,
      recordedAt: recordedAt ?? this.recordedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (activityId.present) {
      map['activity_id'] = Variable<String>(activityId.value);
    }
    if (segment.present) {
      map['segment'] = Variable<int>(segment.value);
    }
    if (latitude.present) {
      map['latitude'] = Variable<double>(latitude.value);
    }
    if (longitude.present) {
      map['longitude'] = Variable<double>(longitude.value);
    }
    if (altitude.present) {
      map['altitude'] = Variable<double>(altitude.value);
    }
    if (accuracy.present) {
      map['accuracy'] = Variable<double>(accuracy.value);
    }
    if (speed.present) {
      map['speed'] = Variable<double>(speed.value);
    }
    if (recordedAt.present) {
      map['recorded_at'] = Variable<DateTime>(recordedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TrackPointsCompanion(')
          ..write('id: $id, ')
          ..write('activityId: $activityId, ')
          ..write('segment: $segment, ')
          ..write('latitude: $latitude, ')
          ..write('longitude: $longitude, ')
          ..write('altitude: $altitude, ')
          ..write('accuracy: $accuracy, ')
          ..write('speed: $speed, ')
          ..write('recordedAt: $recordedAt')
          ..write(')'))
        .toString();
  }
}

class $CoursesTable extends Courses with TableInfo<$CoursesTable, CourseRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CoursesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _mountainNameMeta = const VerificationMeta(
    'mountainName',
  );
  @override
  late final GeneratedColumn<String> mountainName = GeneratedColumn<String>(
    'mountain_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startNameMeta = const VerificationMeta(
    'startName',
  );
  @override
  late final GeneratedColumn<String> startName = GeneratedColumn<String>(
    'start_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endNameMeta = const VerificationMeta(
    'endName',
  );
  @override
  late final GeneratedColumn<String> endName = GeneratedColumn<String>(
    'end_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _distanceMMeta = const VerificationMeta(
    'distanceM',
  );
  @override
  late final GeneratedColumn<double> distanceM = GeneratedColumn<double>(
    'distance_m',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _officialTimeMinMeta = const VerificationMeta(
    'officialTimeMin',
  );
  @override
  late final GeneratedColumn<int> officialTimeMin = GeneratedColumn<int>(
    'official_time_min',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _officialDifficultyMeta =
      const VerificationMeta('officialDifficulty');
  @override
  late final GeneratedColumn<String> officialDifficulty =
      GeneratedColumn<String>(
        'official_difficulty',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _pathJsonMeta = const VerificationMeta(
    'pathJson',
  );
  @override
  late final GeneratedColumn<String> pathJson = GeneratedColumn<String>(
    'path_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _summitLatMeta = const VerificationMeta(
    'summitLat',
  );
  @override
  late final GeneratedColumn<double> summitLat = GeneratedColumn<double>(
    'summit_lat',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _summitLonMeta = const VerificationMeta(
    'summitLon',
  );
  @override
  late final GeneratedColumn<double> summitLon = GeneratedColumn<double>(
    'summit_lon',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _elevationsJsonMeta = const VerificationMeta(
    'elevationsJson',
  );
  @override
  late final GeneratedColumn<String> elevationsJson = GeneratedColumn<String>(
    'elevations_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    mountainName,
    name,
    startName,
    endName,
    distanceM,
    officialTimeMin,
    officialDifficulty,
    pathJson,
    summitLat,
    summitLon,
    updatedAt,
    elevationsJson,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'courses';
  @override
  VerificationContext validateIntegrity(
    Insertable<CourseRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('mountain_name')) {
      context.handle(
        _mountainNameMeta,
        mountainName.isAcceptableOrUnknown(
          data['mountain_name']!,
          _mountainNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_mountainNameMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('start_name')) {
      context.handle(
        _startNameMeta,
        startName.isAcceptableOrUnknown(data['start_name']!, _startNameMeta),
      );
    } else if (isInserting) {
      context.missing(_startNameMeta);
    }
    if (data.containsKey('end_name')) {
      context.handle(
        _endNameMeta,
        endName.isAcceptableOrUnknown(data['end_name']!, _endNameMeta),
      );
    } else if (isInserting) {
      context.missing(_endNameMeta);
    }
    if (data.containsKey('distance_m')) {
      context.handle(
        _distanceMMeta,
        distanceM.isAcceptableOrUnknown(data['distance_m']!, _distanceMMeta),
      );
    } else if (isInserting) {
      context.missing(_distanceMMeta);
    }
    if (data.containsKey('official_time_min')) {
      context.handle(
        _officialTimeMinMeta,
        officialTimeMin.isAcceptableOrUnknown(
          data['official_time_min']!,
          _officialTimeMinMeta,
        ),
      );
    }
    if (data.containsKey('official_difficulty')) {
      context.handle(
        _officialDifficultyMeta,
        officialDifficulty.isAcceptableOrUnknown(
          data['official_difficulty']!,
          _officialDifficultyMeta,
        ),
      );
    }
    if (data.containsKey('path_json')) {
      context.handle(
        _pathJsonMeta,
        pathJson.isAcceptableOrUnknown(data['path_json']!, _pathJsonMeta),
      );
    } else if (isInserting) {
      context.missing(_pathJsonMeta);
    }
    if (data.containsKey('summit_lat')) {
      context.handle(
        _summitLatMeta,
        summitLat.isAcceptableOrUnknown(data['summit_lat']!, _summitLatMeta),
      );
    } else if (isInserting) {
      context.missing(_summitLatMeta);
    }
    if (data.containsKey('summit_lon')) {
      context.handle(
        _summitLonMeta,
        summitLon.isAcceptableOrUnknown(data['summit_lon']!, _summitLonMeta),
      );
    } else if (isInserting) {
      context.missing(_summitLonMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('elevations_json')) {
      context.handle(
        _elevationsJsonMeta,
        elevationsJson.isAcceptableOrUnknown(
          data['elevations_json']!,
          _elevationsJsonMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CourseRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CourseRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      mountainName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mountain_name'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      startName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}start_name'],
      )!,
      endName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}end_name'],
      )!,
      distanceM: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}distance_m'],
      )!,
      officialTimeMin: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}official_time_min'],
      ),
      officialDifficulty: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}official_difficulty'],
      ),
      pathJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}path_json'],
      )!,
      summitLat: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}summit_lat'],
      )!,
      summitLon: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}summit_lon'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      elevationsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}elevations_json'],
      ),
    );
  }

  @override
  $CoursesTable createAlias(String alias) {
    return $CoursesTable(attachedDatabase, alias);
  }
}

class CourseRow extends DataClass implements Insertable<CourseRow> {
  /// 서버 courses.id (uuid)
  final String id;
  final String mountainName;
  final String name;
  final String startName;
  final String endName;
  final double distanceM;
  final int? officialTimeMin;
  final String? officialDifficulty;

  /// 경로 좌표 [[경도, 위도], ...] (들머리 → 정상) JSON 문자열
  final String pathJson;
  final double summitLat;
  final double summitLon;
  final DateTime updatedAt;

  /// 경로 점마다의 고도 [m, ...] JSON 문자열 (스키마 4). 없으면 null.
  final String? elevationsJson;
  const CourseRow({
    required this.id,
    required this.mountainName,
    required this.name,
    required this.startName,
    required this.endName,
    required this.distanceM,
    this.officialTimeMin,
    this.officialDifficulty,
    required this.pathJson,
    required this.summitLat,
    required this.summitLon,
    required this.updatedAt,
    this.elevationsJson,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['mountain_name'] = Variable<String>(mountainName);
    map['name'] = Variable<String>(name);
    map['start_name'] = Variable<String>(startName);
    map['end_name'] = Variable<String>(endName);
    map['distance_m'] = Variable<double>(distanceM);
    if (!nullToAbsent || officialTimeMin != null) {
      map['official_time_min'] = Variable<int>(officialTimeMin);
    }
    if (!nullToAbsent || officialDifficulty != null) {
      map['official_difficulty'] = Variable<String>(officialDifficulty);
    }
    map['path_json'] = Variable<String>(pathJson);
    map['summit_lat'] = Variable<double>(summitLat);
    map['summit_lon'] = Variable<double>(summitLon);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || elevationsJson != null) {
      map['elevations_json'] = Variable<String>(elevationsJson);
    }
    return map;
  }

  CoursesCompanion toCompanion(bool nullToAbsent) {
    return CoursesCompanion(
      id: Value(id),
      mountainName: Value(mountainName),
      name: Value(name),
      startName: Value(startName),
      endName: Value(endName),
      distanceM: Value(distanceM),
      officialTimeMin: officialTimeMin == null && nullToAbsent
          ? const Value.absent()
          : Value(officialTimeMin),
      officialDifficulty: officialDifficulty == null && nullToAbsent
          ? const Value.absent()
          : Value(officialDifficulty),
      pathJson: Value(pathJson),
      summitLat: Value(summitLat),
      summitLon: Value(summitLon),
      updatedAt: Value(updatedAt),
      elevationsJson: elevationsJson == null && nullToAbsent
          ? const Value.absent()
          : Value(elevationsJson),
    );
  }

  factory CourseRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CourseRow(
      id: serializer.fromJson<String>(json['id']),
      mountainName: serializer.fromJson<String>(json['mountainName']),
      name: serializer.fromJson<String>(json['name']),
      startName: serializer.fromJson<String>(json['startName']),
      endName: serializer.fromJson<String>(json['endName']),
      distanceM: serializer.fromJson<double>(json['distanceM']),
      officialTimeMin: serializer.fromJson<int?>(json['officialTimeMin']),
      officialDifficulty: serializer.fromJson<String?>(
        json['officialDifficulty'],
      ),
      pathJson: serializer.fromJson<String>(json['pathJson']),
      summitLat: serializer.fromJson<double>(json['summitLat']),
      summitLon: serializer.fromJson<double>(json['summitLon']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      elevationsJson: serializer.fromJson<String?>(json['elevationsJson']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'mountainName': serializer.toJson<String>(mountainName),
      'name': serializer.toJson<String>(name),
      'startName': serializer.toJson<String>(startName),
      'endName': serializer.toJson<String>(endName),
      'distanceM': serializer.toJson<double>(distanceM),
      'officialTimeMin': serializer.toJson<int?>(officialTimeMin),
      'officialDifficulty': serializer.toJson<String?>(officialDifficulty),
      'pathJson': serializer.toJson<String>(pathJson),
      'summitLat': serializer.toJson<double>(summitLat),
      'summitLon': serializer.toJson<double>(summitLon),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'elevationsJson': serializer.toJson<String?>(elevationsJson),
    };
  }

  CourseRow copyWith({
    String? id,
    String? mountainName,
    String? name,
    String? startName,
    String? endName,
    double? distanceM,
    Value<int?> officialTimeMin = const Value.absent(),
    Value<String?> officialDifficulty = const Value.absent(),
    String? pathJson,
    double? summitLat,
    double? summitLon,
    DateTime? updatedAt,
    Value<String?> elevationsJson = const Value.absent(),
  }) => CourseRow(
    id: id ?? this.id,
    mountainName: mountainName ?? this.mountainName,
    name: name ?? this.name,
    startName: startName ?? this.startName,
    endName: endName ?? this.endName,
    distanceM: distanceM ?? this.distanceM,
    officialTimeMin: officialTimeMin.present
        ? officialTimeMin.value
        : this.officialTimeMin,
    officialDifficulty: officialDifficulty.present
        ? officialDifficulty.value
        : this.officialDifficulty,
    pathJson: pathJson ?? this.pathJson,
    summitLat: summitLat ?? this.summitLat,
    summitLon: summitLon ?? this.summitLon,
    updatedAt: updatedAt ?? this.updatedAt,
    elevationsJson: elevationsJson.present
        ? elevationsJson.value
        : this.elevationsJson,
  );
  CourseRow copyWithCompanion(CoursesCompanion data) {
    return CourseRow(
      id: data.id.present ? data.id.value : this.id,
      mountainName: data.mountainName.present
          ? data.mountainName.value
          : this.mountainName,
      name: data.name.present ? data.name.value : this.name,
      startName: data.startName.present ? data.startName.value : this.startName,
      endName: data.endName.present ? data.endName.value : this.endName,
      distanceM: data.distanceM.present ? data.distanceM.value : this.distanceM,
      officialTimeMin: data.officialTimeMin.present
          ? data.officialTimeMin.value
          : this.officialTimeMin,
      officialDifficulty: data.officialDifficulty.present
          ? data.officialDifficulty.value
          : this.officialDifficulty,
      pathJson: data.pathJson.present ? data.pathJson.value : this.pathJson,
      summitLat: data.summitLat.present ? data.summitLat.value : this.summitLat,
      summitLon: data.summitLon.present ? data.summitLon.value : this.summitLon,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      elevationsJson: data.elevationsJson.present
          ? data.elevationsJson.value
          : this.elevationsJson,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CourseRow(')
          ..write('id: $id, ')
          ..write('mountainName: $mountainName, ')
          ..write('name: $name, ')
          ..write('startName: $startName, ')
          ..write('endName: $endName, ')
          ..write('distanceM: $distanceM, ')
          ..write('officialTimeMin: $officialTimeMin, ')
          ..write('officialDifficulty: $officialDifficulty, ')
          ..write('pathJson: $pathJson, ')
          ..write('summitLat: $summitLat, ')
          ..write('summitLon: $summitLon, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('elevationsJson: $elevationsJson')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    mountainName,
    name,
    startName,
    endName,
    distanceM,
    officialTimeMin,
    officialDifficulty,
    pathJson,
    summitLat,
    summitLon,
    updatedAt,
    elevationsJson,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CourseRow &&
          other.id == this.id &&
          other.mountainName == this.mountainName &&
          other.name == this.name &&
          other.startName == this.startName &&
          other.endName == this.endName &&
          other.distanceM == this.distanceM &&
          other.officialTimeMin == this.officialTimeMin &&
          other.officialDifficulty == this.officialDifficulty &&
          other.pathJson == this.pathJson &&
          other.summitLat == this.summitLat &&
          other.summitLon == this.summitLon &&
          other.updatedAt == this.updatedAt &&
          other.elevationsJson == this.elevationsJson);
}

class CoursesCompanion extends UpdateCompanion<CourseRow> {
  final Value<String> id;
  final Value<String> mountainName;
  final Value<String> name;
  final Value<String> startName;
  final Value<String> endName;
  final Value<double> distanceM;
  final Value<int?> officialTimeMin;
  final Value<String?> officialDifficulty;
  final Value<String> pathJson;
  final Value<double> summitLat;
  final Value<double> summitLon;
  final Value<DateTime> updatedAt;
  final Value<String?> elevationsJson;
  final Value<int> rowid;
  const CoursesCompanion({
    this.id = const Value.absent(),
    this.mountainName = const Value.absent(),
    this.name = const Value.absent(),
    this.startName = const Value.absent(),
    this.endName = const Value.absent(),
    this.distanceM = const Value.absent(),
    this.officialTimeMin = const Value.absent(),
    this.officialDifficulty = const Value.absent(),
    this.pathJson = const Value.absent(),
    this.summitLat = const Value.absent(),
    this.summitLon = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.elevationsJson = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CoursesCompanion.insert({
    required String id,
    required String mountainName,
    required String name,
    required String startName,
    required String endName,
    required double distanceM,
    this.officialTimeMin = const Value.absent(),
    this.officialDifficulty = const Value.absent(),
    required String pathJson,
    required double summitLat,
    required double summitLon,
    required DateTime updatedAt,
    this.elevationsJson = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       mountainName = Value(mountainName),
       name = Value(name),
       startName = Value(startName),
       endName = Value(endName),
       distanceM = Value(distanceM),
       pathJson = Value(pathJson),
       summitLat = Value(summitLat),
       summitLon = Value(summitLon),
       updatedAt = Value(updatedAt);
  static Insertable<CourseRow> custom({
    Expression<String>? id,
    Expression<String>? mountainName,
    Expression<String>? name,
    Expression<String>? startName,
    Expression<String>? endName,
    Expression<double>? distanceM,
    Expression<int>? officialTimeMin,
    Expression<String>? officialDifficulty,
    Expression<String>? pathJson,
    Expression<double>? summitLat,
    Expression<double>? summitLon,
    Expression<DateTime>? updatedAt,
    Expression<String>? elevationsJson,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (mountainName != null) 'mountain_name': mountainName,
      if (name != null) 'name': name,
      if (startName != null) 'start_name': startName,
      if (endName != null) 'end_name': endName,
      if (distanceM != null) 'distance_m': distanceM,
      if (officialTimeMin != null) 'official_time_min': officialTimeMin,
      if (officialDifficulty != null) 'official_difficulty': officialDifficulty,
      if (pathJson != null) 'path_json': pathJson,
      if (summitLat != null) 'summit_lat': summitLat,
      if (summitLon != null) 'summit_lon': summitLon,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (elevationsJson != null) 'elevations_json': elevationsJson,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CoursesCompanion copyWith({
    Value<String>? id,
    Value<String>? mountainName,
    Value<String>? name,
    Value<String>? startName,
    Value<String>? endName,
    Value<double>? distanceM,
    Value<int?>? officialTimeMin,
    Value<String?>? officialDifficulty,
    Value<String>? pathJson,
    Value<double>? summitLat,
    Value<double>? summitLon,
    Value<DateTime>? updatedAt,
    Value<String?>? elevationsJson,
    Value<int>? rowid,
  }) {
    return CoursesCompanion(
      id: id ?? this.id,
      mountainName: mountainName ?? this.mountainName,
      name: name ?? this.name,
      startName: startName ?? this.startName,
      endName: endName ?? this.endName,
      distanceM: distanceM ?? this.distanceM,
      officialTimeMin: officialTimeMin ?? this.officialTimeMin,
      officialDifficulty: officialDifficulty ?? this.officialDifficulty,
      pathJson: pathJson ?? this.pathJson,
      summitLat: summitLat ?? this.summitLat,
      summitLon: summitLon ?? this.summitLon,
      updatedAt: updatedAt ?? this.updatedAt,
      elevationsJson: elevationsJson ?? this.elevationsJson,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (mountainName.present) {
      map['mountain_name'] = Variable<String>(mountainName.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (startName.present) {
      map['start_name'] = Variable<String>(startName.value);
    }
    if (endName.present) {
      map['end_name'] = Variable<String>(endName.value);
    }
    if (distanceM.present) {
      map['distance_m'] = Variable<double>(distanceM.value);
    }
    if (officialTimeMin.present) {
      map['official_time_min'] = Variable<int>(officialTimeMin.value);
    }
    if (officialDifficulty.present) {
      map['official_difficulty'] = Variable<String>(officialDifficulty.value);
    }
    if (pathJson.present) {
      map['path_json'] = Variable<String>(pathJson.value);
    }
    if (summitLat.present) {
      map['summit_lat'] = Variable<double>(summitLat.value);
    }
    if (summitLon.present) {
      map['summit_lon'] = Variable<double>(summitLon.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (elevationsJson.present) {
      map['elevations_json'] = Variable<String>(elevationsJson.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CoursesCompanion(')
          ..write('id: $id, ')
          ..write('mountainName: $mountainName, ')
          ..write('name: $name, ')
          ..write('startName: $startName, ')
          ..write('endName: $endName, ')
          ..write('distanceM: $distanceM, ')
          ..write('officialTimeMin: $officialTimeMin, ')
          ..write('officialDifficulty: $officialDifficulty, ')
          ..write('pathJson: $pathJson, ')
          ..write('summitLat: $summitLat, ')
          ..write('summitLon: $summitLon, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('elevationsJson: $elevationsJson, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $ActivitiesTable activities = $ActivitiesTable(this);
  late final $TrackPointsTable trackPoints = $TrackPointsTable(this);
  late final $CoursesTable courses = $CoursesTable(this);
  late final Index trackPointsActivity = Index(
    'track_points_activity',
    'CREATE INDEX track_points_activity ON track_points (activity_id)',
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    activities,
    trackPoints,
    courses,
    trackPointsActivity,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'activities',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('track_points', kind: UpdateKind.delete)],
    ),
  ]);
  @override
  DriftDatabaseOptions get options =>
      const DriftDatabaseOptions(storeDateTimeAsText: true);
}

typedef $$ActivitiesTableCreateCompanionBuilder = ActivitiesCompanion Function({
  required String id,
  Value<String?> userId,
  Value<String?> title,
  required String status,
  required DateTime startedAt,
  Value<DateTime?> endedAt,
  Value<int> pausedMs,
  Value<DateTime?> pausedAt,
  Value<int> currentSegment,
  Value<int?> elapsedS,
  Value<int?> movingS,
  Value<double?> distanceM,
  Value<double?> elevationGainM,
  Value<double?> maxAltitudeM,
  Value<int?> pointCount,
  Value<bool> isFlagged,
  Value<String> uploadStatus,
  required DateTime createdAt,
  Value<int> rowid,
});
typedef $$ActivitiesTableUpdateCompanionBuilder = ActivitiesCompanion Function({
  Value<String> id,
  Value<String?> userId,
  Value<String?> title,
  Value<String> status,
  Value<DateTime> startedAt,
  Value<DateTime?> endedAt,
  Value<int> pausedMs,
  Value<DateTime?> pausedAt,
  Value<int> currentSegment,
  Value<int?> elapsedS,
  Value<int?> movingS,
  Value<double?> distanceM,
  Value<double?> elevationGainM,
  Value<double?> maxAltitudeM,
  Value<int?> pointCount,
  Value<bool> isFlagged,
  Value<String> uploadStatus,
  Value<DateTime> createdAt,
  Value<int> rowid,
});

final class $$ActivitiesTableReferences
    extends BaseReferences<_$AppDatabase, $ActivitiesTable, ActivityRow> {
  $$ActivitiesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$TrackPointsTable, List<TrackPointRow>>
  _trackPointsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.trackPoints,
    aliasName: 'activities__id__track_points__activity_id',
  );

  $$TrackPointsTableProcessedTableManager get trackPointsRefs {
    final manager = $$TrackPointsTableTableManager(
      $_db,
      $_db.trackPoints,
    ).filter((f) => f.activityId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_trackPointsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$ActivitiesTableFilterComposer
    extends Composer<_$AppDatabase, $ActivitiesTable> {
  $$ActivitiesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get endedAt => $composableBuilder(
    column: $table.endedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get pausedMs => $composableBuilder(
    column: $table.pausedMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get pausedAt => $composableBuilder(
    column: $table.pausedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get currentSegment => $composableBuilder(
    column: $table.currentSegment,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get elapsedS => $composableBuilder(
    column: $table.elapsedS,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get movingS => $composableBuilder(
    column: $table.movingS,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get distanceM => $composableBuilder(
    column: $table.distanceM,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get elevationGainM => $composableBuilder(
    column: $table.elevationGainM,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get maxAltitudeM => $composableBuilder(
    column: $table.maxAltitudeM,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get pointCount => $composableBuilder(
    column: $table.pointCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isFlagged => $composableBuilder(
    column: $table.isFlagged,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get uploadStatus => $composableBuilder(
    column: $table.uploadStatus,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> trackPointsRefs(
    Expression<bool> Function($$TrackPointsTableFilterComposer f) f,
  ) {
    final $$TrackPointsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.trackPoints,
      getReferencedColumn: (t) => t.activityId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TrackPointsTableFilterComposer(
            $db: $db,
            $table: $db.trackPoints,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ActivitiesTableOrderingComposer
    extends Composer<_$AppDatabase, $ActivitiesTable> {
  $$ActivitiesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get endedAt => $composableBuilder(
    column: $table.endedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get pausedMs => $composableBuilder(
    column: $table.pausedMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get pausedAt => $composableBuilder(
    column: $table.pausedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get currentSegment => $composableBuilder(
    column: $table.currentSegment,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get elapsedS => $composableBuilder(
    column: $table.elapsedS,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get movingS => $composableBuilder(
    column: $table.movingS,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get distanceM => $composableBuilder(
    column: $table.distanceM,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get elevationGainM => $composableBuilder(
    column: $table.elevationGainM,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get maxAltitudeM => $composableBuilder(
    column: $table.maxAltitudeM,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get pointCount => $composableBuilder(
    column: $table.pointCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isFlagged => $composableBuilder(
    column: $table.isFlagged,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get uploadStatus => $composableBuilder(
    column: $table.uploadStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ActivitiesTableAnnotationComposer
    extends Composer<_$AppDatabase, $ActivitiesTable> {
  $$ActivitiesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<DateTime> get startedAt =>
      $composableBuilder(column: $table.startedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get endedAt =>
      $composableBuilder(column: $table.endedAt, builder: (column) => column);

  GeneratedColumn<int> get pausedMs =>
      $composableBuilder(column: $table.pausedMs, builder: (column) => column);

  GeneratedColumn<DateTime> get pausedAt =>
      $composableBuilder(column: $table.pausedAt, builder: (column) => column);

  GeneratedColumn<int> get currentSegment => $composableBuilder(
    column: $table.currentSegment,
    builder: (column) => column,
  );

  GeneratedColumn<int> get elapsedS =>
      $composableBuilder(column: $table.elapsedS, builder: (column) => column);

  GeneratedColumn<int> get movingS =>
      $composableBuilder(column: $table.movingS, builder: (column) => column);

  GeneratedColumn<double> get distanceM =>
      $composableBuilder(column: $table.distanceM, builder: (column) => column);

  GeneratedColumn<double> get elevationGainM => $composableBuilder(
    column: $table.elevationGainM,
    builder: (column) => column,
  );

  GeneratedColumn<double> get maxAltitudeM => $composableBuilder(
    column: $table.maxAltitudeM,
    builder: (column) => column,
  );

  GeneratedColumn<int> get pointCount => $composableBuilder(
    column: $table.pointCount,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isFlagged =>
      $composableBuilder(column: $table.isFlagged, builder: (column) => column);

  GeneratedColumn<String> get uploadStatus => $composableBuilder(
    column: $table.uploadStatus,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  Expression<T> trackPointsRefs<T extends Object>(
    Expression<T> Function($$TrackPointsTableAnnotationComposer a) f,
  ) {
    final $$TrackPointsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.trackPoints,
      getReferencedColumn: (t) => t.activityId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TrackPointsTableAnnotationComposer(
            $db: $db,
            $table: $db.trackPoints,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ActivitiesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ActivitiesTable,
          ActivityRow,
          $$ActivitiesTableFilterComposer,
          $$ActivitiesTableOrderingComposer,
          $$ActivitiesTableAnnotationComposer,
          $$ActivitiesTableCreateCompanionBuilder,
          $$ActivitiesTableUpdateCompanionBuilder,
          (ActivityRow, $$ActivitiesTableReferences),
          ActivityRow,
          PrefetchHooks Function({bool trackPointsRefs})
        > {
  $$ActivitiesTableTableManager(_$AppDatabase db, $ActivitiesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ActivitiesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ActivitiesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ActivitiesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String?> userId = const Value.absent(),
                Value<String?> title = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<DateTime> startedAt = const Value.absent(),
                Value<DateTime?> endedAt = const Value.absent(),
                Value<int> pausedMs = const Value.absent(),
                Value<DateTime?> pausedAt = const Value.absent(),
                Value<int> currentSegment = const Value.absent(),
                Value<int?> elapsedS = const Value.absent(),
                Value<int?> movingS = const Value.absent(),
                Value<double?> distanceM = const Value.absent(),
                Value<double?> elevationGainM = const Value.absent(),
                Value<double?> maxAltitudeM = const Value.absent(),
                Value<int?> pointCount = const Value.absent(),
                Value<bool> isFlagged = const Value.absent(),
                Value<String> uploadStatus = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ActivitiesCompanion(
                id: id,
                userId: userId,
                title: title,
                status: status,
                startedAt: startedAt,
                endedAt: endedAt,
                pausedMs: pausedMs,
                pausedAt: pausedAt,
                currentSegment: currentSegment,
                elapsedS: elapsedS,
                movingS: movingS,
                distanceM: distanceM,
                elevationGainM: elevationGainM,
                maxAltitudeM: maxAltitudeM,
                pointCount: pointCount,
                isFlagged: isFlagged,
                uploadStatus: uploadStatus,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String?> userId = const Value.absent(),
                Value<String?> title = const Value.absent(),
                required String status,
                required DateTime startedAt,
                Value<DateTime?> endedAt = const Value.absent(),
                Value<int> pausedMs = const Value.absent(),
                Value<DateTime?> pausedAt = const Value.absent(),
                Value<int> currentSegment = const Value.absent(),
                Value<int?> elapsedS = const Value.absent(),
                Value<int?> movingS = const Value.absent(),
                Value<double?> distanceM = const Value.absent(),
                Value<double?> elevationGainM = const Value.absent(),
                Value<double?> maxAltitudeM = const Value.absent(),
                Value<int?> pointCount = const Value.absent(),
                Value<bool> isFlagged = const Value.absent(),
                Value<String> uploadStatus = const Value.absent(),
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => ActivitiesCompanion.insert(
                id: id,
                userId: userId,
                title: title,
                status: status,
                startedAt: startedAt,
                endedAt: endedAt,
                pausedMs: pausedMs,
                pausedAt: pausedAt,
                currentSegment: currentSegment,
                elapsedS: elapsedS,
                movingS: movingS,
                distanceM: distanceM,
                elevationGainM: elevationGainM,
                maxAltitudeM: maxAltitudeM,
                pointCount: pointCount,
                isFlagged: isFlagged,
                uploadStatus: uploadStatus,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ActivitiesTable, ActivityRow>(table),
                  $$ActivitiesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({trackPointsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (trackPointsRefs) db.trackPoints],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (trackPointsRefs)
                    await $_getPrefetchedData<
                      ActivityRow,
                      $ActivitiesTable,
                      TrackPointRow
                    >(
                      currentTable: table,
                      referencedTable: $$ActivitiesTableReferences
                          ._trackPointsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$ActivitiesTableReferences(
                            db,
                            table,
                            p0,
                          ).trackPointsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.activityId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$ActivitiesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ActivitiesTable,
      ActivityRow,
      $$ActivitiesTableFilterComposer,
      $$ActivitiesTableOrderingComposer,
      $$ActivitiesTableAnnotationComposer,
      $$ActivitiesTableCreateCompanionBuilder,
      $$ActivitiesTableUpdateCompanionBuilder,
      (ActivityRow, $$ActivitiesTableReferences),
      ActivityRow,
      PrefetchHooks Function({bool trackPointsRefs})
    >;
typedef $$TrackPointsTableCreateCompanionBuilder =
    TrackPointsCompanion Function({
      Value<int> id,
      required String activityId,
      required int segment,
      required double latitude,
      required double longitude,
      Value<double?> altitude,
      required double accuracy,
      Value<double?> speed,
      required DateTime recordedAt,
    });
typedef $$TrackPointsTableUpdateCompanionBuilder =
    TrackPointsCompanion Function({
      Value<int> id,
      Value<String> activityId,
      Value<int> segment,
      Value<double> latitude,
      Value<double> longitude,
      Value<double?> altitude,
      Value<double> accuracy,
      Value<double?> speed,
      Value<DateTime> recordedAt,
    });

final class $$TrackPointsTableReferences
    extends BaseReferences<_$AppDatabase, $TrackPointsTable, TrackPointRow> {
  $$TrackPointsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ActivitiesTable _activityIdTable(_$AppDatabase db) =>
      db.activities.createAlias('track_points__activity_id__activities__id');

  $$ActivitiesTableProcessedTableManager get activityId {
    final $_column = $_itemColumn<String>('activity_id')!;

    final manager = $$ActivitiesTableTableManager(
      $_db,
      $_db.activities,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_activityIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$TrackPointsTableFilterComposer
    extends Composer<_$AppDatabase, $TrackPointsTable> {
  $$TrackPointsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get segment => $composableBuilder(
    column: $table.segment,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get latitude => $composableBuilder(
    column: $table.latitude,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get longitude => $composableBuilder(
    column: $table.longitude,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get altitude => $composableBuilder(
    column: $table.altitude,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get accuracy => $composableBuilder(
    column: $table.accuracy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get speed => $composableBuilder(
    column: $table.speed,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get recordedAt => $composableBuilder(
    column: $table.recordedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$ActivitiesTableFilterComposer get activityId {
    final $$ActivitiesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.activityId,
      referencedTable: $db.activities,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ActivitiesTableFilterComposer(
            $db: $db,
            $table: $db.activities,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TrackPointsTableOrderingComposer
    extends Composer<_$AppDatabase, $TrackPointsTable> {
  $$TrackPointsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get segment => $composableBuilder(
    column: $table.segment,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get latitude => $composableBuilder(
    column: $table.latitude,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get longitude => $composableBuilder(
    column: $table.longitude,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get altitude => $composableBuilder(
    column: $table.altitude,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get accuracy => $composableBuilder(
    column: $table.accuracy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get speed => $composableBuilder(
    column: $table.speed,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get recordedAt => $composableBuilder(
    column: $table.recordedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$ActivitiesTableOrderingComposer get activityId {
    final $$ActivitiesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.activityId,
      referencedTable: $db.activities,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ActivitiesTableOrderingComposer(
            $db: $db,
            $table: $db.activities,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TrackPointsTableAnnotationComposer
    extends Composer<_$AppDatabase, $TrackPointsTable> {
  $$TrackPointsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get segment =>
      $composableBuilder(column: $table.segment, builder: (column) => column);

  GeneratedColumn<double> get latitude =>
      $composableBuilder(column: $table.latitude, builder: (column) => column);

  GeneratedColumn<double> get longitude =>
      $composableBuilder(column: $table.longitude, builder: (column) => column);

  GeneratedColumn<double> get altitude =>
      $composableBuilder(column: $table.altitude, builder: (column) => column);

  GeneratedColumn<double> get accuracy =>
      $composableBuilder(column: $table.accuracy, builder: (column) => column);

  GeneratedColumn<double> get speed =>
      $composableBuilder(column: $table.speed, builder: (column) => column);

  GeneratedColumn<DateTime> get recordedAt => $composableBuilder(
    column: $table.recordedAt,
    builder: (column) => column,
  );

  $$ActivitiesTableAnnotationComposer get activityId {
    final $$ActivitiesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.activityId,
      referencedTable: $db.activities,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ActivitiesTableAnnotationComposer(
            $db: $db,
            $table: $db.activities,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TrackPointsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TrackPointsTable,
          TrackPointRow,
          $$TrackPointsTableFilterComposer,
          $$TrackPointsTableOrderingComposer,
          $$TrackPointsTableAnnotationComposer,
          $$TrackPointsTableCreateCompanionBuilder,
          $$TrackPointsTableUpdateCompanionBuilder,
          (TrackPointRow, $$TrackPointsTableReferences),
          TrackPointRow,
          PrefetchHooks Function({bool activityId})
        > {
  $$TrackPointsTableTableManager(_$AppDatabase db, $TrackPointsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TrackPointsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TrackPointsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TrackPointsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> activityId = const Value.absent(),
                Value<int> segment = const Value.absent(),
                Value<double> latitude = const Value.absent(),
                Value<double> longitude = const Value.absent(),
                Value<double?> altitude = const Value.absent(),
                Value<double> accuracy = const Value.absent(),
                Value<double?> speed = const Value.absent(),
                Value<DateTime> recordedAt = const Value.absent(),
              }) => TrackPointsCompanion(
                id: id,
                activityId: activityId,
                segment: segment,
                latitude: latitude,
                longitude: longitude,
                altitude: altitude,
                accuracy: accuracy,
                speed: speed,
                recordedAt: recordedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String activityId,
                required int segment,
                required double latitude,
                required double longitude,
                Value<double?> altitude = const Value.absent(),
                required double accuracy,
                Value<double?> speed = const Value.absent(),
                required DateTime recordedAt,
              }) => TrackPointsCompanion.insert(
                id: id,
                activityId: activityId,
                segment: segment,
                latitude: latitude,
                longitude: longitude,
                altitude: altitude,
                accuracy: accuracy,
                speed: speed,
                recordedAt: recordedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$TrackPointsTable, TrackPointRow>(table),
                  $$TrackPointsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({activityId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (activityId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.activityId,
                        referencedTable: $$TrackPointsTableReferences
                            ._activityIdTable(db),
                        referencedColumn: $$TrackPointsTableReferences
                            ._activityIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$TrackPointsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TrackPointsTable,
      TrackPointRow,
      $$TrackPointsTableFilterComposer,
      $$TrackPointsTableOrderingComposer,
      $$TrackPointsTableAnnotationComposer,
      $$TrackPointsTableCreateCompanionBuilder,
      $$TrackPointsTableUpdateCompanionBuilder,
      (TrackPointRow, $$TrackPointsTableReferences),
      TrackPointRow,
      PrefetchHooks Function({bool activityId})
    >;
typedef $$CoursesTableCreateCompanionBuilder = CoursesCompanion Function({
  required String id,
  required String mountainName,
  required String name,
  required String startName,
  required String endName,
  required double distanceM,
  Value<int?> officialTimeMin,
  Value<String?> officialDifficulty,
  required String pathJson,
  required double summitLat,
  required double summitLon,
  required DateTime updatedAt,
  Value<String?> elevationsJson,
  Value<int> rowid,
});
typedef $$CoursesTableUpdateCompanionBuilder = CoursesCompanion Function({
  Value<String> id,
  Value<String> mountainName,
  Value<String> name,
  Value<String> startName,
  Value<String> endName,
  Value<double> distanceM,
  Value<int?> officialTimeMin,
  Value<String?> officialDifficulty,
  Value<String> pathJson,
  Value<double> summitLat,
  Value<double> summitLon,
  Value<DateTime> updatedAt,
  Value<String?> elevationsJson,
  Value<int> rowid,
});

class $$CoursesTableFilterComposer
    extends Composer<_$AppDatabase, $CoursesTable> {
  $$CoursesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mountainName => $composableBuilder(
    column: $table.mountainName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get startName => $composableBuilder(
    column: $table.startName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get endName => $composableBuilder(
    column: $table.endName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get distanceM => $composableBuilder(
    column: $table.distanceM,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get officialTimeMin => $composableBuilder(
    column: $table.officialTimeMin,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get officialDifficulty => $composableBuilder(
    column: $table.officialDifficulty,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get pathJson => $composableBuilder(
    column: $table.pathJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get summitLat => $composableBuilder(
    column: $table.summitLat,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get summitLon => $composableBuilder(
    column: $table.summitLon,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get elevationsJson => $composableBuilder(
    column: $table.elevationsJson,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CoursesTableOrderingComposer
    extends Composer<_$AppDatabase, $CoursesTable> {
  $$CoursesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mountainName => $composableBuilder(
    column: $table.mountainName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get startName => $composableBuilder(
    column: $table.startName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get endName => $composableBuilder(
    column: $table.endName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get distanceM => $composableBuilder(
    column: $table.distanceM,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get officialTimeMin => $composableBuilder(
    column: $table.officialTimeMin,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get officialDifficulty => $composableBuilder(
    column: $table.officialDifficulty,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get pathJson => $composableBuilder(
    column: $table.pathJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get summitLat => $composableBuilder(
    column: $table.summitLat,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get summitLon => $composableBuilder(
    column: $table.summitLon,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get elevationsJson => $composableBuilder(
    column: $table.elevationsJson,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CoursesTableAnnotationComposer
    extends Composer<_$AppDatabase, $CoursesTable> {
  $$CoursesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get mountainName => $composableBuilder(
    column: $table.mountainName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get startName =>
      $composableBuilder(column: $table.startName, builder: (column) => column);

  GeneratedColumn<String> get endName =>
      $composableBuilder(column: $table.endName, builder: (column) => column);

  GeneratedColumn<double> get distanceM =>
      $composableBuilder(column: $table.distanceM, builder: (column) => column);

  GeneratedColumn<int> get officialTimeMin => $composableBuilder(
    column: $table.officialTimeMin,
    builder: (column) => column,
  );

  GeneratedColumn<String> get officialDifficulty => $composableBuilder(
    column: $table.officialDifficulty,
    builder: (column) => column,
  );

  GeneratedColumn<String> get pathJson =>
      $composableBuilder(column: $table.pathJson, builder: (column) => column);

  GeneratedColumn<double> get summitLat =>
      $composableBuilder(column: $table.summitLat, builder: (column) => column);

  GeneratedColumn<double> get summitLon =>
      $composableBuilder(column: $table.summitLon, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get elevationsJson => $composableBuilder(
    column: $table.elevationsJson,
    builder: (column) => column,
  );
}

class $$CoursesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CoursesTable,
          CourseRow,
          $$CoursesTableFilterComposer,
          $$CoursesTableOrderingComposer,
          $$CoursesTableAnnotationComposer,
          $$CoursesTableCreateCompanionBuilder,
          $$CoursesTableUpdateCompanionBuilder,
          (CourseRow, BaseReferences<_$AppDatabase, $CoursesTable, CourseRow>),
          CourseRow,
          PrefetchHooks Function()
        > {
  $$CoursesTableTableManager(_$AppDatabase db, $CoursesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CoursesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CoursesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CoursesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> mountainName = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> startName = const Value.absent(),
                Value<String> endName = const Value.absent(),
                Value<double> distanceM = const Value.absent(),
                Value<int?> officialTimeMin = const Value.absent(),
                Value<String?> officialDifficulty = const Value.absent(),
                Value<String> pathJson = const Value.absent(),
                Value<double> summitLat = const Value.absent(),
                Value<double> summitLon = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<String?> elevationsJson = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CoursesCompanion(
                id: id,
                mountainName: mountainName,
                name: name,
                startName: startName,
                endName: endName,
                distanceM: distanceM,
                officialTimeMin: officialTimeMin,
                officialDifficulty: officialDifficulty,
                pathJson: pathJson,
                summitLat: summitLat,
                summitLon: summitLon,
                updatedAt: updatedAt,
                elevationsJson: elevationsJson,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String mountainName,
                required String name,
                required String startName,
                required String endName,
                required double distanceM,
                Value<int?> officialTimeMin = const Value.absent(),
                Value<String?> officialDifficulty = const Value.absent(),
                required String pathJson,
                required double summitLat,
                required double summitLon,
                required DateTime updatedAt,
                Value<String?> elevationsJson = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CoursesCompanion.insert(
                id: id,
                mountainName: mountainName,
                name: name,
                startName: startName,
                endName: endName,
                distanceM: distanceM,
                officialTimeMin: officialTimeMin,
                officialDifficulty: officialDifficulty,
                pathJson: pathJson,
                summitLat: summitLat,
                summitLon: summitLon,
                updatedAt: updatedAt,
                elevationsJson: elevationsJson,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$CoursesTable, CourseRow>(table),
                  BaseReferences<_$AppDatabase, $CoursesTable, CourseRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CoursesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CoursesTable,
      CourseRow,
      $$CoursesTableFilterComposer,
      $$CoursesTableOrderingComposer,
      $$CoursesTableAnnotationComposer,
      $$CoursesTableCreateCompanionBuilder,
      $$CoursesTableUpdateCompanionBuilder,
      (CourseRow, BaseReferences<_$AppDatabase, $CoursesTable, CourseRow>),
      CourseRow,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$ActivitiesTableTableManager get activities =>
      $$ActivitiesTableTableManager(_db, _db.activities);
  $$TrackPointsTableTableManager get trackPoints =>
      $$TrackPointsTableTableManager(_db, _db.trackPoints);
  $$CoursesTableTableManager get courses =>
      $$CoursesTableTableManager(_db, _db.courses);
}
