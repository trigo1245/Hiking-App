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
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:hiking_app/core/utils/geo.dart';

const _snapM = 5.0;

void main() {
  final config = jsonDecode(
    File('data/trails/courses.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  final mountains = {
    for (final m in (config['mountains'] as List).cast<Map<String, dynamic>>())
      m['id'] as String: m,
  };
  final outDir = Directory('data/trails/courses')..createSync(recursive: true);
  final graphs = <String, _Graph>{};
  final preview = <Map<String, Object?>>[];

  for (final course
      in (config['courses'] as List).cast<Map<String, dynamic>>()) {
    final mountain = mountains[course['mountain']]!;
    final area = mountain['area'] as String;
    final graph = graphs[area] ??= _Graph.fromFile(
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

class _LatLon {
  const _LatLon(this.lat, this.lon);
  final double lat;
  final double lon;
}

class _Edge {
  const _Edge(this.to, this.lengthM, this.feature);
  final int to;
  final double lengthM;
  final int feature;
}

class _PathStats {
  const _PathStats(this.distanceM, this.upMinutes, this.difficulty);
  final double distanceM;
  final double upMinutes;
  final String difficulty;
}

/// 등산로 구간들을 이은 길 그래프
class _Graph {
  _Graph._(this._features);

  factory _Graph.fromFile(String path) {
    final json = jsonDecode(File(path).readAsStringSync()) as Map;
    final features = (json['features'] as List).cast<Map<String, dynamic>>();
    final graph = _Graph._(features);
    for (var f = 0; f < features.length; f++) {
      final geometry = features[f]['geometry'] as Map;
      final lines = switch (geometry['type']) {
        'LineString' => [geometry['coordinates'] as List],
        'MultiLineString' => (geometry['coordinates'] as List).cast<List>(),
        _ => const <List>[],
      };
      for (final line in lines) {
        int? previous;
        for (final c in line.cast<List>()) {
          final node = graph._nodeAt(
            (c[1] as num).toDouble(),
            (c[0] as num).toDouble(),
          );
          if (previous != null && previous != node) {
            graph._connect(previous, node, f);
          }
          previous = node;
        }
      }
    }
    return graph;
  }

  final List<Map<String, dynamic>> _features;
  final nodes = <_LatLon>[];
  final _edges = <List<_Edge>>[];

  /// 약 5m 격자. 가까운 꼭짓점을 빨리 찾기 위해 쓴다.
  final _grid = <(int, int), List<int>>{};
  static const _cellDeg = 0.00005;

  (int, int) _cell(double lat, double lon) =>
      ((lat / _cellDeg).floor(), (lon / _cellDeg).floor());

  int _nodeAt(double lat, double lon) {
    final (cy, cx) = _cell(lat, lon);
    for (var dy = -1; dy <= 1; dy++) {
      for (var dx = -1; dx <= 1; dx++) {
        for (final n in _grid[(cy + dy, cx + dx)] ?? const <int>[]) {
          if (haversineMeters(lat, lon, nodes[n].lat, nodes[n].lon) <= _snapM) {
            return n;
          }
        }
      }
    }
    nodes.add(_LatLon(lat, lon));
    _edges.add([]);
    _grid.putIfAbsent((cy, cx), () => []).add(nodes.length - 1);
    return nodes.length - 1;
  }

  void _connect(int a, int b, int feature) {
    final d = haversineMeters(
      nodes[a].lat,
      nodes[a].lon,
      nodes[b].lat,
      nodes[b].lon,
    );
    _edges[a].add(_Edge(b, d, feature));
    _edges[b].add(_Edge(a, d, feature));
  }

  /// 가장 가까운 노드와 그 거리(m)
  (int, double) nearest(double lat, double lon) {
    var best = 0;
    var bestD = double.infinity;
    for (var i = 0; i < nodes.length; i++) {
      if (_edges[i].isEmpty) continue;
      final d = haversineMeters(lat, lon, nodes[i].lat, nodes[i].lon);
      if (d < bestD) {
        best = i;
        bestD = d;
      }
    }
    return (best, bestD);
  }

  /// 다익스트라: 가장 짧은 노드 경로. 이어지지 않으면 null.
  List<int>? shortestPath(int from, int to) {
    final dist = List.filled(nodes.length, double.infinity);
    final prev = List<int?>.filled(nodes.length, null);
    dist[from] = 0;
    final queue = SplayTreeSet<(double, int)>((a, b) {
      final c = a.$1.compareTo(b.$1);
      return c != 0 ? c : a.$2.compareTo(b.$2);
    })..add((0, from));
    while (queue.isNotEmpty) {
      final (d, n) = queue.first;
      queue.remove(queue.first);
      if (n == to) break;
      if (d > dist[n]) continue;
      for (final e in _edges[n]) {
        final nd = d + e.lengthM;
        if (nd < dist[e.to]) {
          queue.remove((dist[e.to], e.to));
          dist[e.to] = nd;
          prev[e.to] = n;
          queue.add((nd, e.to));
        }
      }
    }
    if (dist[to] == double.infinity) return null;
    final path = <int>[to];
    while (path.last != from) {
      path.add(prev[path.last]!);
    }
    return path.reversed.toList();
  }

  /// 경로 길이, 브이월드 구간 시간으로 계산한 오르막 시간, 난이도(지나는 구간 중 가장 어려운 것)
  _PathStats pathStats(List<int> path) {
    final perFeature = <int, double>{};
    var distance = 0.0;
    for (var i = 1; i < path.length; i++) {
      final edge = _edges[path[i - 1]].firstWhere((e) => e.to == path[i]);
      distance += edge.lengthM;
      perFeature[edge.feature] = (perFeature[edge.feature] ?? 0) + edge.lengthM;
    }

    var minutes = 0.0;
    var level = 0;
    const levels = {'하': 1, '중': 2, '상': 3};
    for (final MapEntry(key: f, value: walked) in perFeature.entries) {
      final p = _features[f]['properties'] as Map;
      final secLen = double.tryParse('${p['sec_len']}') ?? 0;
      // 구간의 오르막·내리막 시간 중 큰 값을 오르막 시간으로 보고, 지나간 길이만큼 나눠 더한다.
      final up = math.max(
        double.tryParse('${p['up_min']}') ?? 0,
        double.tryParse('${p['down_min']}') ?? 0,
      );
      if (secLen > 0) minutes += up * math.min(1, walked / secLen);
      level = math.max(level, levels['${p['cat_nam']}'] ?? 0);
    }
    final difficulty = switch (level) {
      3 => '상',
      2 => '중',
      1 => '하',
      _ => '',
    };
    return _PathStats(distance, minutes, difficulty);
  }
}
