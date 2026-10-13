// GPX 파일의 점을 에뮬레이터에 순서대로 보내 "걸어가는" 상황을 흉내 낸다.
//
// 사용법:
//   dart run tool/replay_gpx.dart <gpx 파일> [간격(초), 기본 3]
//   예) dart run tool/replay_gpx.dart test_data/synthetic_climb.gpx 1
//
// 에뮬레이터가 켜져 있어야 한다. 내부적으로 `adb emu geo fix <경도> <위도> <고도>`를 실행한다.
import 'dart:io';

Future<void> main(List<String> args) async {
  if (args.isEmpty) {
    stderr.writeln('사용법: dart run tool/replay_gpx.dart <gpx 파일> [간격(초), 기본 3]');
    exit(64);
  }

  final file = File(args[0]);
  if (!file.existsSync()) {
    stderr.writeln('파일이 없어요: ${args[0]}');
    exit(66);
  }
  final interval = Duration(
    milliseconds: ((double.tryParse(args.elementAtOrNull(1) ?? '') ?? 3) * 1000)
        .round(),
  );

  // <trkpt lat=".." lon=".."> ... <ele>..</ele> (lat/lon 순서는 상관없음)
  final trkpt = RegExp(r'<trkpt\b([^>]*)>([\s\S]*?)</trkpt>');
  final points = [
    for (final m in trkpt.allMatches(file.readAsStringSync()))
      (
        lat: _attr(m.group(1)!, 'lat'),
        lon: _attr(m.group(1)!, 'lon'),
        ele: RegExp(r'<ele>([-\d.]+)</ele>').firstMatch(m.group(2)!)?.group(1),
      ),
  ];
  if (points.isEmpty) {
    stderr.writeln('GPX에서 <trkpt>를 찾지 못했어요.');
    exit(65);
  }

  final adb = _findAdb();
  stdout.writeln(
    '${points.length}개 점을 ${interval.inMilliseconds / 1000}초 간격으로 보낼게요.',
  );
  for (var i = 0; i < points.length; i++) {
    final p = points[i];
    // 경도가 먼저다.
    final result = await Process.run(adb, [
      'emu',
      'geo',
      'fix',
      p.lon,
      p.lat,
      ?p.ele,
    ]);
    if (result.exitCode != 0) {
      stderr.writeln('adb 실행 실패: ${result.stderr}');
      exit(1);
    }
    stdout.writeln('[${i + 1}/${points.length}] ${p.lat}, ${p.lon}, ${p.ele}');
    if (i < points.length - 1) await Future<void>.delayed(interval);
  }
  stdout.writeln('끝났어요.');
}

String _attr(String attrs, String name) =>
    RegExp('$name="([-\\d.]+)"').firstMatch(attrs)!.group(1)!;

/// PATH에 adb가 없으면 Android SDK 기본 위치에서 찾는다.
String _findAdb() {
  final exe = Platform.isWindows ? 'adb.exe' : 'adb';
  final sdk =
      Platform.environment['ANDROID_HOME'] ??
      Platform.environment['ANDROID_SDK_ROOT'] ??
      (Platform.isWindows
          ? '${Platform.environment['LOCALAPPDATA']}\\Android\\sdk'
          : '${Platform.environment['HOME']}/Library/Android/sdk');
  final candidate = File(
    '$sdk${Platform.pathSeparator}platform-tools'
    '${Platform.pathSeparator}$exe',
  );
  return candidate.existsSync() ? candidate.path : exe;
}
