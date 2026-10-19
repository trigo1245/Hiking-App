import 'dart:async';

import 'package:hiking_app/features/recording/data/location_service.dart';
import 'package:hiking_app/features/recording/domain/track_point.dart';

/// 테스트에서 위치를 직접 보내는 가짜 위치 서비스.
class FakeLocationService implements LocationService {
  FakeLocationService({this.access = LocationAccess.granted});

  LocationAccess access;
  StreamController<LocationSample>? _controller;
  int notificationRequests = 0;
  final opened = <String>[];

  bool get isListening => _controller?.hasListener ?? false;

  void emit(LocationSample sample) => _controller!.add(sample);
  void emitError(Object error) => _controller!.addError(error);

  @override
  Future<LocationAccess> requestAccess() async => access;

  @override
  Future<void> requestNotificationPermission() async => notificationRequests++;

  @override
  Stream<LocationSample> watchPositions() {
    _controller = StreamController<LocationSample>();
    return _controller!.stream;
  }

  /// 지도용 위치 권한이 이미 있는지
  bool preciseAccess = false;
  StreamController<LocationSample>? _mapController;

  void emitMapPosition(LocationSample sample) => _mapController!.add(sample);

  @override
  Future<bool> hasPreciseAccess() async => preciseAccess;

  @override
  Stream<LocationSample> watchMapPosition() {
    _mapController = StreamController<LocationSample>();
    return _mapController!.stream;
  }

  @override
  Future<void> openAppSettings() async => opened.add('app');

  @override
  Future<void> openLocationSettings() async => opened.add('location');
}
