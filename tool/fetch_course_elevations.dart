// 코스 경로의 점마다 고도(해발 m)를 받아 코스 GeoJSON에 넣는다.
// 코스 예상 소요시간(경사 보정)에 쓴다. 브이월드·OSM 등산로에는 고도가 없어서 따로 받는다.
//
// 사용법 (build_courses.dart, auto_courses.dart 다음, export_courses_sql.dart 전에):
//   dart run tool/fetch_course_elevations.dart
//
// 고도 출처: OpenTopoData 공개 API의 SRTM 30m (NASA, 공개 자료)
// - 한 번에 100점, 1초에 1번, 하루 1,000번까지. 받은 값은 캐시 파일에 모아 두고 다시 묻지 않는다.
// - 캐시: data/trails/raw/elevation/srtm30m_cache.json (받은 원본이라 raw에 둔다)
// 결과: 각 코스 GeoJSON의 properties.elevations_m (경로 좌표와 같은 순서·개수)
import 'dart:convert';
import 'dart:io';

const _cachePath = 'data/trails/raw/elevation/srtm30m_cache.json';
const _batch = 100;

/// 코스 GeoJSON 파일 목록 (직접 정의한 코스 + 자동 생성 코스)
List<File> _courseFiles() => [
  for (final dir in ['data/trails/courses', 'data/trails/courses/auto'])
    for (final f in Directory(dir).listSync().whereType<File>())
      if (f.path.endsWith('.geojson') && !f.path.endsWith('preview.geojson')) f,
];

/// 캐시 키: 소수점 6자리 (약 10cm)
String _key(num lat, num lon) =>
    '${lat.toStringAsFixed(6)},${lon.toStringAsFixed(6)}';

Future<void> main() async {
  final cacheFile = File(_cachePath)..parent.createSync(recursive: true);
  final cache = cacheFile.existsSync()
      ? (jsonDecode(cacheFile.readAsStringSync()) as Map<String, dynamic>).map(
          (k, v) => MapEntry(k, (v as num?)?.toDouble()),
        )
      : <String, double?>{};

  final files = _courseFiles();
  final features = {
    for (final f in files)
      f: jsonDecode(f.readAsStringSync()) as Map<String, dynamic>,
  };
  List<List<num>> coordsOf(Map<String, dynamic> feature) => [
    for (final c in (feature['geometry']['coordinates'] as List))
      (c as List).cast<num>(),
  ];

  // 아직 캐시에 없는 점만 모아서 묻는다.
  final missing = <String>{
    for (final feature in features.values)
      for (final c in coordsOf(feature))
        if (!cache.containsKey(_key(c[1], c[0]))) _key(c[1], c[0]),
  }.toList();
  stdout.writeln('코스 ${files.length}개, 새로 받을 점 ${missing.length}개');

  final client = HttpClient();
  try {
    for (var i = 0; i < missing.length; i += _batch) {
      final part = missing.sublist(
        i,
        i + _batch > missing.length ? missing.length : i + _batch,
      );
      final uri = Uri.https('api.opentopodata.org', '/v1/srtm30m', {
        'locations': part.join('|'),
      });
      final request = await client.getUrl(uri);
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode != 200) {
        stderr.writeln('고도 받기 실패 (${response.statusCode}): $body');
        break; // 받은 데까지 캐시에 저장하고 끝낸다. 다시 실행하면 이어서 받는다.
      }
      final results = (jsonDecode(body)['results'] as List)
          .cast<Map<String, dynamic>>();
      for (final (j, r) in results.indexed) {
        cache[part[j]] = (r['elevation'] as num?)?.toDouble();
      }
      stdout.writeln('  ${i + part.length} / ${missing.length}');
      cacheFile.writeAsStringSync(jsonEncode(cache));
      // 공개 API 이용 규칙: 1초에 1번
      await Future<void>.delayed(const Duration(milliseconds: 1100));
    }
  } finally {
    client.close();
  }

  var done = 0;
  for (final MapEntry(key: file, value: feature) in features.entries) {
    final elevations = [
      for (final c in coordsOf(feature)) cache[_key(c[1], c[0])],
    ];
    if (elevations.any((e) => e == null)) {
      stderr.writeln('고도가 비어 있어 건너뜀: ${file.path}');
      continue;
    }
    (feature['properties'] as Map<String, dynamic>)['elevations_m'] = [
      for (final e in elevations) double.parse(e!.toStringAsFixed(1)),
    ];
    file.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(feature));
    done++;
  }
  stdout.writeln('고도를 넣은 코스: $done / ${files.length}');
}
