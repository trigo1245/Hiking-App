// 부산 산들의 코스를 자동으로 만든다. (산마다 들머리 → 정상 코스 최대 2개)
//
// 사용법 (먼저 tool/fetch_vworld_trails.dart로 부산 전체 등산로를 받아 둔다):
//   dart run tool/auto_courses.dart
//
// 방법
//  1. 정상: OpenStreetMap 봉우리 중 산 이름이 같은 것, 여러 개면 가장 높은 것
//  2. 들머리: 그 산 등산로에서 길이 더 이어지지 않는 끝점 중
//     정상까지 0.8~6km이고, 서로 다른 방향에서 올라가는 2개
//  3. 이름: 들머리 위치의 동 이름 (브이월드 지오코더). 예: "청룡동 코스"
//
// 입력: data/trails/raw/vworld/busan.geojson, data/trails/courses.json (직접 만든 산은 건너뜀)
// 출력: data/trails/courses_auto.json, data/trails/courses/auto/*.geojson,
//       data/trails/courses/auto/preview.geojson (geojson.io로 확인용)
// 캐시: data/trails/raw/osm/busan_peaks.json (OpenStreetMap 봉우리, ODbL)
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'src/trail_graph.dart';

const _busanBbox = [128.84, 35.04, 129.30, 35.33]; // 서, 남, 동, 북
const _minCourseM = 800.0;
const _maxCourseM = 6000.0;

/// 정상 봉우리에서 이만큼 안에 등산로가 있어야 한다.
const _summitSnapM = 200.0;

Future<void> main() async {
  final key = _readKey();
  final manual =
      jsonDecode(File('data/trails/courses.json').readAsStringSync()) as Map;
  final manualNames = {
    for (final m in (manual['mountains'] as List).cast<Map>()) m['name'],
  };

  stdout.writeln('등산로를 읽는 중...');
  final raw = jsonDecode(
    File('data/trails/raw/vworld/busan.geojson').readAsStringSync(),
  ) as Map;
  final features = (raw['features'] as List).cast<Map<String, dynamic>>();
  final graph = TrailGraph.fromFeatures(features);
  final peaks = await _loadPeaks();
  stdout.writeln(
    '구간 ${features.length}개, 노드 ${graph.nodes.length}개, '
    'OSM 봉우리 ${peaks.length}개',
  );

  // 구간(feature) → 노드, 산 이름 → 구간
  final featureNodes = <int, Set<int>>{};
  for (var n = 0; n < graph.nodes.length; n++) {
    for (final e in graph.edges[n]) {
      featureNodes.putIfAbsent(e.feature, () => {}).add(n);
    }
  }
  final byMountain = <String, List<int>>{};
  for (var f = 0; f < features.length; f++) {
    final name = '${(features[f]['properties'] as Map)['mntn_nm'] ?? ''}';
    if (name.isNotEmpty) byMountain.putIfAbsent(name, () => []).add(f);
  }

  final outDir = Directory('data/trails/courses/auto')
    ..createSync(recursive: true);
  for (final old in outDir.listSync().whereType<File>()) {
    old.deleteSync();
  }
  final mountainsOut = <Map<String, Object?>>[];
  final coursesOut = <Map<String, Object?>>[];
  final preview = <Map<String, Object?>>[];
  final skipped = <String>[];

  for (final name in byMountain.keys.toList()..sort()) {
    if (manualNames.contains(name)) {
      skipped.add('$name: 직접 만든 코스가 있어 건너뜀');
      continue;
    }
    if (!(name.endsWith('산') || name.endsWith('봉'))) {
      skipped.add('$name: 산 이름이 아님 (둘레길·종주길 등)');
      continue;
    }
    final mountainFeatures = byMountain[name]!.toSet();
    final mountainNodes = {
      for (final f in mountainFeatures) ...?featureNodes[f],
    };
    if (mountainNodes.isEmpty) continue;

    final peak = _pickPeak(name, peaks, graph, mountainNodes);
    if (peak == null) {
      skipped.add('$name: 같은 이름의 OSM 봉우리가 없음');
      continue;
    }
    final (summitNode, summitGap) = graph.nearest(
      peak.lat,
      peak.lon,
      where: mountainNodes.contains,
    );
    if (summitGap > _summitSnapM) {
      skipped.add(
        '$name: 봉우리(${peak.name}) 근처에 등산로가 없음 (${summitGap.round()}m)',
      );
      continue;
    }

    final fromSummit = graph.shortestFrom(summitNode, maxM: _maxCourseM);
    final candidates = <_Candidate>[];
    for (final n in mountainNodes) {
      if (graph.degree(n) != 1) continue;
      final d = fromSummit.distance[n];
      if (d < _minCourseM || d > _maxCourseM) continue;
      if (graph.distance(n, summitNode) < 400) continue;
      final path = fromSummit.pathTo(n)!.reversed.toList(); // 들머리 → 정상
      final lengths = graph.featureLengths(path);
      final onMountain = lengths.entries
          .where((e) => mountainFeatures.contains(e.key))
          .fold(0.0, (s, e) => s + e.value);
      if (onMountain / d < 0.6) continue; // 다른 산 길을 주로 지나면 제외
      candidates.add(_Candidate(n, path, d, _bearing(graph, summitNode, n)));
    }
    if (candidates.isEmpty) {
      skipped.add('$name: 알맞은 들머리 후보가 없음');
      continue;
    }

    final picked = _pickTwo(graph, candidates);
    final region = await _region(key, peak.lat, peak.lon);
    // 받은 범위가 사각형이라 김해·양산 산도 섞여 있다. 정상이 부산인 산만 남긴다.
    if (!region.startsWith('부산')) {
      skipped.add('$name: 부산 밖의 산 ($region)');
      continue;
    }
    final mountainId = 'auto-$name';
    mountainsOut.add({
      'id': mountainId,
      'name': name,
      'region': region,
      // OSM에 높이가 없으면 모름(null)
      'height_m': peak.ele > 0 ? peak.ele : null,
      'summit': {'name': peak.name, 'lat': peak.lat, 'lon': peak.lon},
      'source': 'OpenStreetMap 봉우리 (ODbL)',
    });

    final usedNames = <String>{};
    for (final (i, c) in picked.indexed) {
      final start = graph.nodes[c.node];
      final dong = await _dong(key, start.lat, start.lon) ?? '$name ${i + 1}';
      var courseName = '$dong 코스';
      if (!usedNames.add(courseName)) courseName = '$dong 코스 ${i + 1}';
      final id = '$mountainId-${i + 1}';
      final stats = graph.pathStats(c.path);
      final feature = {
        'type': 'Feature',
        'properties': {
          'id': id,
          'mountain_id': mountainId,
          'mountain_name': name,
          'course_name': courseName,
          'start_name': '$dong 들머리',
          'end_name': peak.name,
          'direction': 'ascent',
          'distance_m': stats.distanceM.round(),
          'official_time_min': stats.upMinutes.round(),
          'official_difficulty': stats.difficulty,
          'auto': true,
          'source':
              '브이월드 2D데이터 API (LT_L_FRSTCLIMB, 산림청 등산로), 정상: OpenStreetMap',
          'built_at': DateTime.now().toIso8601String().substring(0, 10),
        },
        'geometry': {
          'type': 'LineString',
          'coordinates': [
            for (final n in c.path)
              [_round(graph.nodes[n].lon), _round(graph.nodes[n].lat)],
          ],
        },
      };
      final file = File(
        '${outDir.path}/$id.geojson',
      )..writeAsStringSync(const JsonEncoder.withIndent('  ').convert(feature));
      coursesOut.add({
        'id': id,
        'mountain': mountainId,
        'name': courseName,
        'file': file.path.replaceAll(r'\', '/'),
      });
      preview
        ..add({
          ...feature,
          'properties': {
            ...feature['properties']! as Map,
            'stroke': i == 0 ? '#03B26C' : '#3182F6',
            'stroke-width': 4,
          },
        })
        ..add(
          _point(start.lat, start.lon, '들머리: $name $courseName', '#3182F6'),
        );
      stdout.writeln(
        '$name (${peak.name}, ${peak.ele.round()}m) $courseName: '
        '${(stats.distanceM / 1000).toStringAsFixed(2)}km, '
        '오르막 ${stats.upMinutes.round()}분',
      );
    }
    preview.add(_point(peak.lat, peak.lon, '정상: ${peak.name}', '#F04452'));
  }

  File('${outDir.path}/preview.geojson').writeAsStringSync(
    jsonEncode({'type': 'FeatureCollection', 'features': preview}),
  );
  File('data/trails/courses_auto.json').writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert({
      '_설명':
          '자동 생성 코스 (dart run tool/auto_courses.dart). 직접 고치지 말고 '
          '잘못된 산은 courses.json에 직접 정의하면 자동 생성에서 빠진다.',
      'mountains': mountainsOut,
      'courses': coursesOut,
    }),
  );

  stdout
    ..writeln()
    ..writeln('산 ${mountainsOut.length}개, 코스 ${coursesOut.length}개를 만들었어요.')
    ..writeln('건너뛴 산 ${skipped.length}개:');
  for (final s in skipped) {
    stdout.writeln('  - $s');
  }
}

class _Peak {
  const _Peak(this.name, this.lat, this.lon, this.ele);
  final String name;
  final double lat;
  final double lon;
  final double ele;
}

class _Candidate {
  _Candidate(this.node, this.path, this.lengthM, this.bearing);
  final int node;

  /// 들머리 → 정상 노드 경로
  final List<int> path;
  final double lengthM;

  /// 정상에서 본 들머리 방향 (도)
  final double bearing;
}

/// 산 이름과 같은(또는 "산이름(봉우리)") OSM 봉우리 중 등산로 근처에서 가장 높은 것
_Peak? _pickPeak(
  String name,
  List<_Peak> peaks,
  TrailGraph graph,
  Set<int> mountainNodes,
) {
  bool sameName(String peak) =>
      peak == name || peak.startsWith('$name(') || peak.startsWith('$name ');
  final near = [
    for (final p in peaks)
      if (sameName(p.name) &&
          graph.nearest(p.lat, p.lon, where: mountainNodes.contains).$2 < 1500)
        p,
  ];
  if (near.isEmpty) return null;
  near.sort((a, b) => b.ele.compareTo(a.ele));
  return near.first;
}

/// 길이가 알맞은(약 2.8km에 가까운) 후보를 먼저 고르고,
/// 두 번째는 방향이 45도 이상 다르고 첫 번째 길과 40% 넘게 겹치지 않는 것을 고른다.
List<_Candidate> _pickTwo(TrailGraph graph, List<_Candidate> candidates) {
  candidates.sort(
    (a, b) => (a.lengthM - 2800).abs().compareTo((b.lengthM - 2800).abs()),
  );
  final first = candidates.first;
  final firstEdges = _edgeSet(first.path);
  for (final c in candidates.skip(1)) {
    if (graph.distance(c.node, first.node) < 500) continue;
    var diff = (c.bearing - first.bearing).abs() % 360;
    if (diff > 180) diff = 360 - diff;
    if (diff < 45) continue;
    var shared = 0.0;
    for (var i = 1; i < c.path.length; i++) {
      if (firstEdges.contains(_edgeKey(c.path[i - 1], c.path[i]))) {
        shared += graph.distance(c.path[i - 1], c.path[i]);
      }
    }
    if (shared / c.lengthM > 0.4) continue;
    return [first, c];
  }
  return [first];
}

Set<(int, int)> _edgeSet(List<int> path) => {
  for (var i = 1; i < path.length; i++) _edgeKey(path[i - 1], path[i]),
};

(int, int) _edgeKey(int a, int b) => a < b ? (a, b) : (b, a);

double _bearing(TrailGraph graph, int from, int to) {
  final a = graph.nodes[from];
  final b = graph.nodes[to];
  final y = (b.lon - a.lon) * math.cos(a.lat * math.pi / 180);
  final x = b.lat - a.lat;
  return (math.atan2(y, x) * 180 / math.pi + 360) % 360;
}

double _round(double v) => (v * 1e6).round() / 1e6;

Map<String, Object?> _point(
  double lat,
  double lon,
  String title,
  String color,
) => {
  'type': 'Feature',
  'properties': {'title': title, 'marker-color': color},
  'geometry': {
    'type': 'Point',
    'coordinates': [lon, lat],
  },
};

/// OpenStreetMap 봉우리 (이름 있는 것). 한 번 받으면 파일로 저장해 다시 쓴다.
Future<List<_Peak>> _loadPeaks() async {
  final cache = File('data/trails/raw/osm/busan_peaks.json');
  if (!cache.existsSync()) {
    stdout.writeln('OpenStreetMap 봉우리를 받는 중...');
    final [w, s, e, n] = _busanBbox;
    final query =
        '[out:json][timeout:60];node["natural"="peak"]["name"]($s,$w,$n,$e);out body;';
    final client = HttpClient()
      ..userAgent = 'hiking_app-dev (com.hikingapp.hiking_app)';
    try {
      final request = await client.postUrl(
        Uri.parse('https://overpass-api.de/api/interpreter'),
      );
      request.headers.contentType = ContentType(
        'application',
        'x-www-form-urlencoded',
        charset: 'utf-8',
      );
      request.write('data=${Uri.encodeQueryComponent(query)}');
      final body = await (await request.close()).transform(utf8.decoder).join();
      cache
        ..parent.createSync(recursive: true)
        ..writeAsStringSync(body);
    } finally {
      client.close();
    }
  }
  final json = jsonDecode(cache.readAsStringSync()) as Map;
  return [
    for (final el in (json['elements'] as List).cast<Map>())
      _Peak(
        '${(el['tags'] as Map)['name']}',
        (el['lat'] as num).toDouble(),
        (el['lon'] as num).toDouble(),
        double.tryParse('${(el['tags'] as Map)['ele'] ?? ''}') ?? 0,
      ),
  ];
}

/// 브이월드 지오코더로 좌표의 주소를 받는다.
Future<Map?> _address(String key, double lat, double lon) async {
  final uri = Uri.https('api.vworld.kr', '/req/address', {
    'service': 'address',
    'request': 'getAddress',
    'version': '2.0',
    'crs': 'epsg:4326',
    'point': '$lon,$lat',
    'format': 'json',
    'type': 'parcel',
    'key': key,
    'domain': 'http://localhost',
  });
  final client = HttpClient();
  try {
    final body = await (await (await client.getUrl(
      uri,
    )).close()).transform(utf8.decoder).join();
    final response = (jsonDecode(body) as Map)['response'] as Map;
    if (response['status'] != 'OK') return null;
    return ((response['result'] as List).first as Map)['structure'] as Map;
  } catch (_) {
    return null;
  } finally {
    client.close();
  }
}

/// 들머리의 동 이름. 예: 청룡동
Future<String?> _dong(String key, double lat, double lon) async {
  final s = await _address(key, lat, lon);
  final dong = '${s?['level4L'] ?? ''}';
  return dong.isEmpty ? null : dong;
}

/// 정상의 지역. 예: 부산 금정구
Future<String> _region(String key, double lat, double lon) async {
  final s = await _address(key, lat, lon);
  if (s == null) return '부산';
  final city = '${s['level1']}'.replaceAll('광역시', '').replaceAll('특별자치도', '');
  return '$city ${s['level2']}'.trim();
}

String _readKey() {
  final file = File('tool_env.json');
  if (!file.existsSync()) {
    stderr.writeln(
      'tool_env.json이 없어요. {"VWORLD_API_KEY": "..."} 형태로 만들어 주세요.',
    );
    exit(66);
  }
  return (jsonDecode(file.readAsStringSync()) as Map)['VWORLD_API_KEY']
      as String;
}
