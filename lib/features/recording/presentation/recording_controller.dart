import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/clock.dart';
import '../data/location_service.dart';
import '../data/recording_repository.dart';
import '../domain/recording_session.dart';
import '../domain/track_point.dart';
import '../domain/track_stats.dart';

/// 기록 화면이 보여 줄 상태.
class RecordingState {
  const RecordingState({
    this.session,
    this.stats = const TrackStats(),
    this.currentAltitude,
    this.hasFix = false,
    this.signalLost = false,
  });

  /// null이면 기록 중이 아님
  final RecordingSession? session;
  final TrackStats stats;
  final double? currentAltitude;

  /// 이번 구간에서 위치를 한 번이라도 받았는지
  final bool hasFix;

  /// 위치 수집 중 오류가 났는지 (GPS 꺼짐, 권한 해제 등)
  final bool signalLost;

  bool get isActive => session != null;
  bool get isPaused => session?.status == RecordingStatus.paused;

  RecordingState copyWith({
    RecordingSession? session,
    TrackStats? stats,
    double? currentAltitude,
    bool? hasFix,
    bool? signalLost,
  }) => RecordingState(
    session: session ?? this.session,
    stats: stats ?? this.stats,
    currentAltitude: currentAltitude ?? this.currentAltitude,
    hasFix: hasFix ?? this.hasFix,
    signalLost: signalLost ?? this.signalLost,
  );
}

/// 기록 시작·일시정지·재개·종료와 위치 수집을 맡는다.
/// 화면을 벗어나도 기록이 이어지도록 앱 전체에서 하나만 유지된다.
class RecordingController extends Notifier<RecordingState> {
  StreamSubscription<LocationSample>? _subscription;
  TrackStatsCalculator _calculator = TrackStatsCalculator();

  /// 위치 저장이 순서대로 끝나도록 이어 붙이는 작업 줄
  Future<void> _pendingWrites = Future.value();

  RecordingRepository get _repository => ref.read(recordingRepositoryProvider);
  LocationService get _location => ref.read(locationServiceProvider);
  DateTime _now() => ref.read(clockProvider)();

  @override
  RecordingState build() {
    ref.onDispose(() => _subscription?.cancel());
    return const RecordingState();
  }

  /// 권한을 확인하고 새 기록을 시작한다. 권한이 없으면 시작하지 않고 그 이유를 돌려준다.
  Future<LocationAccess> start() async {
    if (state.isActive) return LocationAccess.granted;

    final access = await _location.requestAccess();
    if (access != LocationAccess.granted) return access;
    await _location.requestNotificationPermission();

    final session = await _repository.start(_now());
    _calculator = TrackStatsCalculator();
    state = RecordingState(session: session);
    _listen();
    return access;
  }

  Future<void> pause() async {
    final session = state.session;
    if (session == null || session.status != RecordingStatus.recording) return;
    await _stopListening();
    state = state.copyWith(
      session: await _repository.pause(session.activityId, _now()),
    );
  }

  Future<void> resume() async {
    final session = state.session;
    if (session == null || session.status != RecordingStatus.paused) return;
    state = RecordingState(
      session: await _repository.resume(session.activityId, _now()),
      stats: state.stats,
      currentAltitude: state.currentAltitude,
    );
    _listen();
  }

  /// 기록을 끝내고 요약 수치를 저장한다. 끝난 기록의 ID를 돌려준다.
  Future<String?> finish() async {
    final session = state.session;
    if (session == null) return null;
    await _stopListening();

    await _repository.finish(
      session.activityId,
      endedAt: session.pausedAt ?? _now(),
      stats: _calculator.stats,
      title: defaultActivityTitle(session.startedAt),
    );
    state = const RecordingState();
    return session.activityId;
  }

  /// 앱이 기록 중에 꺼졌다면 그 기록을 찾는다. 기록 중이면 찾지 않는다.
  /// 결과를 저장해 두지 않고 매번 DB에서 확인한다. (방금 끝낸 기록을 다시 묻지 않도록)
  Future<UnfinishedRecording?> findUnfinished() async {
    if (state.isActive) return null;
    return _repository.loadUnfinished();
  }

  /// 앱이 꺼지기 전에 하던 기록을 불러온다. 일시정지 상태로 복원된다.
  void restore(UnfinishedRecording unfinished) {
    _calculator = TrackStatsCalculator()..addAll(unfinished.points);
    state = RecordingState(
      session: unfinished.session,
      stats: _calculator.stats,
      currentAltitude: unfinished.points.lastOrNull?.altitude,
    );
  }

  void _listen() {
    _subscription?.cancel();
    _subscription = _location.watchPositions().listen(
      _onSample,
      onError: (Object error) {
        debugPrint('[recording] 위치 수집 오류: $error');
        state = state.copyWith(signalLost: true);
      },
    );
  }

  void _onSample(LocationSample sample) {
    final session = state.session;
    if (session == null || session.status != RecordingStatus.recording) return;

    final point = TrackPoint.fromSample(sample, segment: session.segment);
    // 받은 즉시 DB에 저장한다. 앱이 강제 종료돼도 여기까지는 남는다.
    _pendingWrites = _pendingWrites.then(
      (_) => _repository.addPoint(session.activityId, point),
    );
    _calculator.add(point);
    state = state.copyWith(
      stats: _calculator.stats,
      currentAltitude: sample.altitude,
      hasFix: true,
      signalLost: false,
    );
  }

  Future<void> _stopListening() async {
    await _subscription?.cancel();
    _subscription = null;
    await _pendingWrites;
  }
}

final recordingControllerProvider =
    NotifierProvider<RecordingController, RecordingState>(
      RecordingController.new,
    );
