import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hiking_app/features/recording/data/location_hub.dart';
import 'package:hiking_app/features/recording/domain/track_point.dart';

/// 실제 위치 패키지처럼 "통로"를 열고 닫는 가짜. 몇 번 열렸는지, 지금 열려 있는지 기록한다.
class FakeSource {
  StreamController<LocationSample>? controller;
  int opens = 0;

  bool get isOpen => controller?.hasListener ?? false;

  Stream<LocationSample> open() {
    opens++;
    controller = StreamController<LocationSample>();
    return controller!.stream;
  }

  void emit(double lat) => controller!.add(
    LocationSample(
      latitude: lat,
      longitude: 129,
      accuracy: 5,
      recordedAt: DateTime.utc(2026, 10, 24),
    ),
  );
}

void main() {
  late FakeSource recording;
  late FakeSource map;
  late LocationHub hub;

  /// 허브 안의 작업 줄(닫고 열기)이 끝나도록 기다린다.
  Future<void> settle() => Future<void>.delayed(Duration.zero);

  setUp(() {
    recording = FakeSource();
    map = FakeSource();
    hub = LocationHub(openRecording: recording.open, openMap: map.open);
  });

  test('지도만 볼 때는 지도용 통로를 연다', () async {
    final got = <double>[];
    final sub = hub.watchMap().listen((s) => got.add(s.latitude));
    await settle();

    expect(map.isOpen, isTrue);
    expect(recording.opens, 0);
    map.emit(35.1);
    await settle();
    expect(got, [35.1]);
    await sub.cancel();
    await settle();
    expect(map.isOpen, isFalse);
  });

  test('기록을 시작하면 지도용 통로를 닫고 기록용 통로를 연다 (상단 알림이 붙는 통로)', () async {
    final mapGot = <double>[];
    final recGot = <double>[];
    hub.watchMap().listen((s) => mapGot.add(s.latitude));
    await settle();
    expect(map.isOpen, isTrue);

    final recSub = hub.watchRecording().listen((s) => recGot.add(s.latitude));
    await settle();

    expect(map.isOpen, isFalse);
    expect(recording.isOpen, isTrue);

    // 기록 위치가 기록과 지도 모두에 간다.
    recording.emit(35.2);
    await settle();
    expect(recGot, [35.2]);
    expect(mapGot, [35.2]);

    // 기록이 끝나면 지도용 통로를 다시 연다.
    await recSub.cancel();
    await settle();
    expect(recording.isOpen, isFalse);
    expect(map.isOpen, isTrue);
    expect(map.opens, 2);
  });

  test('기록 중에 지도 화면이 새로 열려도 지도용 통로를 따로 열지 않는다', () async {
    hub.watchRecording().listen((_) {});
    await settle();
    final got = <double>[];
    hub.watchMap().listen((s) => got.add(s.latitude));
    await settle();

    expect(map.opens, 0);
    recording.emit(35.3);
    await settle();
    expect(got, [35.3]);
  });

  test('지도를 보는 화면이 없으면 기록이 끝나도 지도용 통로를 열지 않는다', () async {
    final sub = hub.watchRecording().listen((_) {});
    await settle();
    await sub.cancel();
    await settle();
    expect(map.opens, 0);
  });

  test('기록용 통로의 오류는 기록 쪽에 전달된다', () async {
    Object? error;
    hub.watchRecording().listen((_) {}, onError: (Object e) => error = e);
    await settle();
    recording.controller!.addError(StateError('gps off'));
    await settle();
    expect(error, isA<StateError>());
  });
}
