// 브이월드 등산로 구간을 이어 "들머리 → 정상" 코스를 만든다.
//
// 사용법 (먼저 tool/fetch_vworld_trails.dart로 원본을 받아 둔다):
//   dart run tool/build_courses.dart
//
// 입력: data/trails/courses.json, data/trails/raw/vworld/{area}.geojson
// 출력: data/trails/courses/{course id}.geojson   (코스 하나 = LineString 하나, 들머리 → 정상)
//       data/trails/courses/preview.geojson       (geojson.io에 끌어다 놓아 눈으로 확인하는 용도)
//
// 방법: 구간의 모든 꼭짓점을 노드로 보고, 5m 이내 꼭짓점은 같은 노드로 합친다(구간 연결).
// 들머리·정상에서 가장 가까운 노드 사이를 다익스트라로 가장 짧게 잇는다.
import 'dart:convert';
import 'dart:io';

import 'src/trail_graph.dart';

void main() {
  final config = jsonDecode(
    File('data/trails/courses.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  final mountains = {
    for (final m in (config['mountains'] as List).cast<Map<String, dynamic>>())
      m['id'] as String: m,
  };
  final outDir = Directory('data/trails/courses')..createSync(recursive: true);
  final graphs = <String, TrailGraph>{};
  final preview = <Map<String, Object?>>[];

  for (final course
      in (config['courses'] as List).cast<Map<String, dynamic>>()) {
    final mountain = mountains[course['mountain']]!;
    final area = mountain['area'] as String;
    final graph = graphs[area] ??= TrailGraph.fromFile(
      'data/trails/raw/vworld/$area.geojson',
    );

    final start = course['start'] as Map<String, dynamic>;
    final summit = mountain['summit'] as Map<String, dynamic>;
    final (startNode, startGap) = graph.nearest(_lat(start), _lon(start));
    final (summitNode, summitGap) = graph.nearest(_lat(summit), _lon(summit));
    final path = graph.shortestPath(startNode, summitNode);
    if (path == null) {
      stderr.writeln('${course['id']}: 들머리와 정상이 등산로로 이어지지 않아요.');
      exitCode = 1;
      continue;
    }

    final coords = [for (final n in path) graph.nodes[n]];
    final stats = graph.pathStats(path);
    final feature = {
      'type': 'Feature',
      'properties': {
        'id': course['id'],
        'mountain_id': mountain['id'],
        'mountain_name': mountain['name'],
        'course_name': course['name'],
        'start_name': start['name'],
        'end_name': summit['name'],
        'direction': 'ascent',
        'distance_m': stats.distanceM.round(),
        'official_time_min': stats.upMinutes.round(),
        'official_difficulty': stats.difficulty,
        'start_gap_m': startGap.round(),
        'summit_gap_m': summitGap.round(),
        'source': '브이월드 2D데이터 API (LT_L_FRSTCLIMB, 산림청 등산로)',
        'built_at': DateTime.now().toIso8601String().substring(0, 10),
      },
      'geometry': {
        'type': 'LineString',
        'coordinates': [
          for (final c in coords) [_round(c.lon), _round(c.lat)],
        ],
      },
    };
    File('${outDir.path}/${course['id']}.geojson')
        .writeAsStringSync(const JsonEncoder.withIndent('  ').convert(feature));

    preview
      ..add({
        ...feature,
        'properties': {
          ...feature['properties']! as Map,
          'stroke': _colors[preview.length ~/ 3 % _colors.length],
          'stroke-width': 4,
        },
      })
      ..add(_point(start, '들머리: ${course['name']}', '#3182F6'))
      ..add(_point(summit, '정상: ${summit['name']}', '#F04452'));

    stdout.writeln(
      '${mountain['name']} ${course['name']}: '
      '${(stats.distanceM / 1000).toStringAsFixed(2)}km, '
      '공식 오르막 ${stats.upMinutes.round()}분, 난이도 ${stats.difficulty}, '
      '점 ${coords.length}개 | 들머리↔등산로 ${startGap.round()}m, '
      '정상↔등산로 ${summitGap.round()}m',
    );
  }

  File('${outDir.path}/preview.geojson').writeAsStringSync(
    jsonEncode({'type': 'FeatureCollection', 'features': preview}),
  );
}

const _colors = ['#03B26C', '#FF9500', '#8E44AD', '#00A3C4'];

double _lat(Map<String, dynamic> p) => (p['lat'] as num).toDouble();
double _lon(Map<String, dynamic> p) => (p['lon'] as num).toDouble();
double _round(double v) => (v * 1e6).round() / 1e6;

Map<String, Object?> _point(
  Map<String, dynamic> p,
  String title,
  String color,
) => {
  'type': 'Feature',
  'properties': {'title': title, 'marker-color': color},
  'geometry': {
    'type': 'Point',
    'coordinates': [_lon(p), _lat(p)],
  },
};
