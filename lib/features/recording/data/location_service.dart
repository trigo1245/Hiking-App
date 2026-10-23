import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

import '../domain/track_point.dart';
import 'location_hub.dart';

enum LocationAccess {
  granted,

  /// 위치 서비스(GPS)가 꺼져 있음
  serviceDisabled,
  denied,

  /// "다시 묻지 않음" 상태라 설정 앱에서만 바꿀 수 있음
  deniedForever,

  /// "대략적인 위치"만 허용됨. 등산 경로를 그리기에는 부족하다.
  approximateOnly,
}

/// 위치 권한과 위치 수집. 테스트에서는 가짜로 바꿔 끼운다.
abstract interface class LocationService {
  /// 위치 권한을 확인하고, 필요하면 요청한다.
  Future<LocationAccess> requestAccess();

  /// Android 13 이상에서 "기록 중" 알림을 보여 주려면 필요하다. 거절해도 기록은 된다.
  Future<void> requestNotificationPermission();

  /// 구독하는 동안 위치를 보낸다. 구독 중에는 상단 고정 알림이 뜨고 화면이 꺼져도 계속된다.
  Stream<LocationSample> watchPositions();

  /// 정밀 위치 권한이 이미 있는지 (묻지 않고 확인만 한다)
  Future<bool> hasPreciseAccess();

  /// 지도에 내 위치를 보여 주기 위한 위치. 기록이 아니므로 알림 없이, 화면이 켜져 있을 때만 받는다.
  Stream<LocationSample> watchMapPosition();

  Future<void> openAppSettings();
  Future<void> openLocationSettings();
}

class GeolocatorLocationService implements LocationService {
  /// 기록용·지도용 위치 통로를 한 줄로 관리한다. (location_hub.dart 설명 참고)
  late final LocationHub _hub = LocationHub(
    openRecording: _openRecordingStream,
    openMap: _openMapStream,
  );

  @override
  Future<LocationAccess> requestAccess() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return LocationAccess.serviceDisabled;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    switch (permission) {
      case LocationPermission.deniedForever:
        return LocationAccess.deniedForever;
      case LocationPermission.denied:
      case LocationPermission.unableToDetermine:
        return LocationAccess.denied;
      case LocationPermission.whileInUse:
      case LocationPermission.always:
        break;
    }

    final accuracy = await Geolocator.getLocationAccuracy();
    if (accuracy == LocationAccuracyStatus.reduced) {
      return LocationAccess.approximateOnly;
    }
    return LocationAccess.granted;
  }

  @override
  Future<void> requestNotificationPermission() async {
    await Permission.notification.request();
  }

  @override
  Stream<LocationSample> watchPositions() => _hub.watchRecording();

  @override
  Stream<LocationSample> watchMapPosition() => _hub.watchMap();

  /// 기록용 통로: 상단 고정 알림과 함께 화면이 꺼져도 위치를 받는다.
  Stream<LocationSample> _openRecordingStream() {
    final settings = AndroidSettings(
      // Google Play 서비스의 통합 위치 대신 GPS를 직접 쓴다.
      // 통합 위치는 "Google 위치 정확도"가 꺼져 있으면 GPS가 켜져 있어도 오류를 낸다.
      // 산에서는 네트워크 위치가 거의 도움이 되지 않아 GPS만으로 충분하다.
      forceLocationManager: true,
      accuracy: LocationAccuracy.best,
      // 5m 이상 움직였을 때만 받는다. 멈춰 있을 때 GPS 흔들림으로 거리가 늘어나는 것을 줄인다.
      distanceFilter: 5,
      intervalDuration: const Duration(seconds: 3),
      // 해수면 기준 고도 (기본값은 GPS 타원체 기준이라 한국에서 약 20~30m 높게 나온다)
      useMSLAltitude: true,
      foregroundNotificationConfig: const ForegroundNotificationConfig(
        notificationTitle: '등산 기록 중이에요',
        notificationText: '화면이 꺼져도 계속 기록할게요',
        notificationChannelName: '등산 기록',
        enableWakeLock: true,
        setOngoing: true,
      ),
    );

    return Geolocator.getPositionStream(locationSettings: settings)
        .map(_toSample);
  }

  @override
  Future<bool> hasPreciseAccess() async {
    if (!await Geolocator.isLocationServiceEnabled()) return false;
    final permission = await Geolocator.checkPermission();
    if (permission != LocationPermission.whileInUse &&
        permission != LocationPermission.always) {
      return false;
    }
    return await Geolocator.getLocationAccuracy() ==
        LocationAccuracyStatus.precise;
  }

  /// 지도용 통로: 알림 없이 화면이 켜져 있을 때만 받는다.
  Stream<LocationSample> _openMapStream() {
    final settings = AndroidSettings(
      forceLocationManager: true,
      accuracy: LocationAccuracy.high,
      distanceFilter: 5,
      intervalDuration: const Duration(seconds: 3),
      useMSLAltitude: true,
    );
    return Geolocator.getPositionStream(locationSettings: settings)
        .map(_toSample);
  }

  static LocationSample _toSample(Position p) => LocationSample(
    latitude: p.latitude,
    longitude: p.longitude,
    // 고도를 모르면 0과 정확도 0이 함께 온다.
    altitude: p.altitude == 0 && p.altitudeAccuracy == 0 ? null : p.altitude,
    accuracy: p.accuracy,
    speed: p.speed,
    recordedAt: p.timestamp,
  );

  @override
  Future<void> openAppSettings() => Geolocator.openAppSettings();

  @override
  Future<void> openLocationSettings() => Geolocator.openLocationSettings();
}

final locationServiceProvider = Provider<LocationService>(
  (ref) => GeolocatorLocationService(),
);
