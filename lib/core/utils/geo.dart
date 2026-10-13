import 'dart:math' as math;

const _earthRadiusM = 6371008.8;

/// 하버사인 공식으로 두 좌표 사이의 지표면 거리(m)를 구한다.
double haversineMeters(double lat1, double lon1, double lat2, double lon2) {
  double toRad(double deg) => deg * math.pi / 180;
  final dLat = toRad(lat2 - lat1);
  final dLon = toRad(lon2 - lon1);
  final a =
      math.pow(math.sin(dLat / 2), 2) +
      math.cos(toRad(lat1)) *
          math.cos(toRad(lat2)) *
          math.pow(math.sin(dLon / 2), 2);
  return 2 * _earthRadiusM * math.asin(math.sqrt(a));
}
