// 브이월드 2D데이터 API에서 등산로(산림청) 데이터를 받아 GeoJSON으로 저장한다.
//
// 사용법:
//   dart run tool/fetch_vworld_trails.dart
//
// data/trails/courses.json의 areas 범위마다
// data/trails/raw/vworld/{area id}.geojson 을 만든다. (좌표: WGS84 경도·위도)
// API 키는 tool_env.json의 VWORLD_API_KEY를 쓴다. (앱에는 넣지 않는다)
import 'dart:convert';
import 'dart:io';

const _layer = 'LT_L_FRSTCLIMB'; // 등산로
const _domain = 'http://localhost'; // 브이월드 인증키에 등록한 주소
const _pageSize = 1000;

Future<void> main() async {
  final key = _readKey();
  final config = jsonDecode(
    File('data/trails/courses.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  final outDir = Directory('data/trails/raw/vworld')
    ..createSync(recursive: true);

  for (final area in (config['areas'] as List).cast<Map<String, dynamic>>()) {
    final bbox = (area['bbox'] as List).join(',');
    final features = <Object?>[];
    var page = 1;
    var totalPages = 1;
    while (page <= totalPages) {
      final uri = Uri.https('api.vworld.kr', '/req/data', {
        'service': 'data',
        'version': '2.0',
        'request': 'GetFeature',
        'data': _layer,
        'key': key,
        'domain': _domain,
        'format': 'json',
        'crs': 'EPSG:4326',
        'geometry': 'true',
        'attribute': 'true',
        'size': '$_pageSize',
        'page': '$page',
        'geomFilter': 'BOX($bbox)',
      });
      final response =
          (await _getJson(uri))['response'] as Map<String, dynamic>;
      if (response['status'] != 'OK') {
        stderr.writeln('${area['id']} $page쪽 요청 실패: ${response['error']}');
        exit(1);
      }
      totalPages = int.parse((response['page'] as Map)['total'] as String);
      final collection =
          (response['result'] as Map)['featureCollection'] as Map;
      features.addAll(collection['features'] as List);
      page++;
    }

    final file = File('${outDir.path}/${area['id']}.geojson');
    file.writeAsStringSync(
      jsonEncode({
        'type': 'FeatureCollection',
        'source': '브이월드 2D데이터 API ($_layer, 산림청 등산로)',
        'fetched_at': DateTime.now().toIso8601String(),
        'bbox': area['bbox'],
        'features': features,
      }),
    );
    stdout.writeln(
      '${area['name']}: 등산로 구간 ${features.length}개 → ${file.path}',
    );
  }
}

String _readKey() {
  final file = File('tool_env.json');
  if (!file.existsSync()) {
    stderr.writeln(
      'tool_env.json이 없어요. {"VWORLD_API_KEY": "..."} 형태로 만들어 주세요.',
    );
    exit(66);
  }
  final key = (jsonDecode(file.readAsStringSync()) as Map)['VWORLD_API_KEY'];
  if (key is! String || key.isEmpty) {
    stderr.writeln('tool_env.json에 VWORLD_API_KEY가 없어요.');
    exit(66);
  }
  return key;
}

Future<Map<String, dynamic>> _getJson(Uri uri) async {
  final client = HttpClient();
  try {
    final request = await client.getUrl(uri);
    final response = await request.close();
    final body = await response.transform(utf8.decoder).join();
    return jsonDecode(body) as Map<String, dynamic>;
  } finally {
    client.close();
  }
}
