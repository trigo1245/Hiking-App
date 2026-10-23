import 'dart:async';

import '../domain/track_point.dart';

/// 위치 받는 통로를 앱 전체에서 하나로 관리한다.
///
/// 위치 패키지(geolocator)는 안드로이드에서 위치 통로를 하나만 연다. 이미 열려 있으면
/// 새 설정을 무시하고 열려 있는 통로를 그대로 넘겨준다. 그래서 홈 지도가 먼저 연
/// "알림 없는 지도용 통로"를 기록이 같이 쓰게 되면, 상단 고정 알림이 뜨지 않고(화면이
/// 꺼지면 기록이 끊길 수 있음) 첫 위치도 5m 움직이기 전까지 오지 않는다.
///
/// 이 허브는 둘을 한 줄로 세운다.
/// - 기록 중이 아닐 때: 지도를 보는 화면이 있으면 지도용 통로를 연다.
/// - 기록이 시작되면: 지도용 통로를 먼저 닫고, 기록용 통로(상단 알림 포함)를 연다.
///   기록 위치는 지도에도 같이 보내 준다.
/// - 기록이 끝나면: 기록용 통로를 닫고, 지도를 보는 화면이 있으면 지도용 통로를 다시 연다.
class LocationHub {
  LocationHub({required this._openRecording, required this._openMap}) {
    _mapOut = StreamController<LocationSample>.broadcast(
      onListen: _syncMapSource,
      onCancel: _syncMapSource,
    );
  }

  final Stream<LocationSample> Function() _openRecording;
  final Stream<LocationSample> Function() _openMap;

  late final StreamController<LocationSample> _mapOut;
  StreamSubscription<LocationSample>? _mapSource;
  StreamSubscription<LocationSample>? _recordingSource;
  bool _recording = false;

  /// 작업을 한 줄로 세워, 닫기가 끝난 뒤에 다음 통로를 연다.
  Future<void> _queue = Future.value();

  bool get isRecording => _recording;

  /// 지도용 위치. 기록 중이면 기록 위치가 그대로 온다.
  Stream<LocationSample> watchMap() => _mapOut.stream;

  /// 기록용 위치. 구독하는 동안 기록용 통로가 열려 있다. (한 번에 하나만 구독한다)
  Stream<LocationSample> watchRecording() {
    late final StreamController<LocationSample> out;
    out = StreamController<LocationSample>(
      onListen: () {
        _recording = true;
        _enqueue(() async {
          await _mapSource?.cancel();
          _mapSource = null;
          if (!_recording || out.isClosed) return;
          _recordingSource = _openRecording().listen((sample) {
            out.add(sample);
            if (_mapOut.hasListener) _mapOut.add(sample);
          }, onError: out.addError);
        });
      },
      onCancel: () {
        _recording = false;
        _enqueue(() async {
          await _recordingSource?.cancel();
          _recordingSource = null;
        });
        _syncMapSource();
      },
    );
    return out.stream;
  }

  /// 지금 상태에 맞게 지도용 통로를 열거나 닫는다.
  void _syncMapSource() {
    _enqueue(() async {
      final wanted = _mapOut.hasListener && !_recording;
      if (wanted && _mapSource == null) {
        _mapSource = _openMap().listen(_mapOut.add, onError: _mapOut.addError);
      } else if (!wanted && _mapSource != null) {
        await _mapSource!.cancel();
        _mapSource = null;
      }
    });
  }

  void _enqueue(Future<void> Function() task) {
    _queue = _queue.then((_) => task());
  }
}
