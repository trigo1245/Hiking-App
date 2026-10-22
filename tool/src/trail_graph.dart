// 등산로 구간들을 이은 길 그래프. tool/build_courses.dart와 tool/auto_courses.dart가 함께 쓴다.
//
// 구간의 모든 꼭짓점을 노드로 보고, 5m 이내 꼭짓점은 같은 노드로 합친다(구간끼리 연결).
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:hiking_app/core/utils/geo.dart';

const _snapM = 5.0;

class LatLon {
  const LatLon(this.lat, this.lon);
  final double lat;
  final double lon;
}

class Edge {
  const Edge(this.to, this.lengthM, this.feature);
  final int to;
  final double lengthM;

  /// 이 간선이 속한 브이월드 구간(feature) 번호
  final int feature;
}

class PathStats {
  const PathStats(this.distanceM, this.upMinutes, this.difficulty);
  final double distanceM;
  final double upMinutes;
  final String difficulty;
}

/// 한 출발점에서 모든 노드까지의 최단 거리 (다익스트라 결과)
class ShortestPaths {
  ShortestPaths(this.from, this.distance, this._prev);

  final int from;
  final List<double> distance;
  final List<int?> _prev;

  /// [to]에서 출발점까지 거슬러 올라간 노드 경로 (출발점 → [to] 순서). 이어지지 않으면 null.
  List<int>? pathTo(int to) {
    if (distance[to] == double.infinity) return null;
    final path = <int>[to];
    while (path.last != from) {
      path.add(_prev[path.last]!);
    }
    return path.reversed.toList();
  }
}

class TrailGraph {
  TrailGraph._(this.features);

  factory TrailGraph.fromFile(String path) {
    final json = jsonDecode(File(path).readAsStringSync()) as Map;
    return TrailGraph.fromFeatures(
      (json['features'] as List).cast<Map<String, dynamic>>(),
    );
  }

  factory TrailGraph.fromFeatures(List<Map<String, dynamic>> features) {
    final graph = TrailGraph._(features);
    for (var f = 0; f < features.length; f++) {
      for (final line in linesOf(features[f])) {
        int? previous;
        for (final c in line) {
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

  /// 구간의 선들 (LineString이면 1개, MultiLineString이면 여러 개)
  static List<List<List>> linesOf(Map<String, dynamic> feature) {
    final geometry = feature['geometry'] as Map;
    return switch (geometry['type']) {
      'LineString' => [(geometry['coordinates'] as List).cast<List>()],
      'MultiLineString' => [
        for (final l in (geometry['coordinates'] as List).cast<List>())
          l.cast<List>(),
      ],
      _ => const [],
    };
  }

  final List<Map<String, dynamic>> features;
  final nodes = <LatLon>[];
  final edges = <List<Edge>>[];

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
    nodes.add(LatLon(lat, lon));
    edges.add([]);
    _grid.putIfAbsent((cy, cx), () => []).add(nodes.length - 1);
    return nodes.length - 1;
  }

  void _connect(int a, int b, int feature) {
    final d = distance(a, b);
    edges[a].add(Edge(b, d, feature));
    edges[b].add(Edge(a, d, feature));
  }

  double distance(int a, int b) =>
      haversineMeters(nodes[a].lat, nodes[a].lon, nodes[b].lat, nodes[b].lon);

  double distanceTo(int node, double lat, double lon) =>
      haversineMeters(nodes[node].lat, nodes[node].lon, lat, lon);

  /// 이어진 다른 노드 수 (1이면 길이 더 이어지지 않는 끝점)
  int degree(int node) => {for (final e in edges[node]) e.to}.length;

  /// 가장 가까운 노드와 그 거리(m). [where]로 후보를 좁힐 수 있다.
  (int, double) nearest(double lat, double lon, {bool Function(int)? where}) {
    var best = -1;
    var bestD = double.infinity;
    for (var i = 0; i < nodes.length; i++) {
      if (edges[i].isEmpty) continue;
      if (where != null && !where(i)) continue;
      final d = distanceTo(i, lat, lon);
      if (d < bestD) {
        best = i;
        bestD = d;
      }
    }
    return (best, bestD);
  }

  /// 다익스트라: [from]에서 [maxM] 이내 모든 노드까지의 최단 거리
  ShortestPaths shortestFrom(int from, {double maxM = double.infinity}) {
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
      if (d > dist[n] || d > maxM) continue;
      for (final e in edges[n]) {
        final nd = d + e.lengthM;
        if (nd < dist[e.to]) {
          queue.remove((dist[e.to], e.to));
          dist[e.to] = nd;
          prev[e.to] = n;
          queue.add((nd, e.to));
        }
      }
    }
    return ShortestPaths(from, dist, prev);
  }

  /// [from] → [to] 최단 노드 경로. 이어지지 않으면 null.
  List<int>? shortestPath(int from, int to) => shortestFrom(from).pathTo(to);

  /// 경로가 지나는 구간별 길이
  Map<int, double> featureLengths(List<int> path) {
    final out = <int, double>{};
    for (var i = 1; i < path.length; i++) {
      final edge = edges[path[i - 1]].firstWhere((e) => e.to == path[i]);
      out[edge.feature] = (out[edge.feature] ?? 0) + edge.lengthM;
    }
    return out;
  }

  /// 경로 길이, 브이월드 구간 시간으로 계산한 오르막 시간, 난이도(지나는 구간 중 가장 어려운 것)
  PathStats pathStats(List<int> path) {
    final perFeature = featureLengths(path);
    final distance = perFeature.values.fold(0.0, (s, v) => s + v);

    var minutes = 0.0;
    var level = 0;
    const levels = {'하': 1, '중': 2, '상': 3};
    for (final MapEntry(key: f, value: walked) in perFeature.entries) {
      final p = features[f]['properties'] as Map;
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
    return PathStats(distance, minutes, difficulty);
  }
}
