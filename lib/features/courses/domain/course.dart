/// 위도·경도 한 점
class GeoPoint {
  const GeoPoint(this.lat, this.lon);

  final double lat;
  final double lon;
}

/// 등산 코스 하나 (들머리 → 정상). 지도·검색·코스 매칭에서 쓴다.
class Course {
  const Course({
    required this.id,
    required this.mountainName,
    required this.name,
    required this.startName,
    required this.endName,
    required this.distanceM,
    required this.path,
    required this.summit,
    this.officialTimeMin,
    this.officialDifficulty,
    this.updatedAt,
  });

  final String id;
  final String mountainName;
  final String name;
  final String startName;
  final String endName;
  final double distanceM;

  /// 공식 오르막 소요시간(분). 브이월드 구간 시간의 합이라 참고용이다.
  final int? officialTimeMin;

  /// 상·중·하
  final String? officialDifficulty;

  /// 들머리 → 정상 순서의 좌표
  final List<GeoPoint> path;
  final GeoPoint summit;

  /// 서버에서 마지막으로 고친 시각 (바뀌었을 때만 내려받기에 쓴다)
  final DateTime? updatedAt;

  GeoPoint get start => path.first;

  /// "승학산 동아대 코스"
  String get fullName => '$mountainName $name';
}

/// 산 이름이나 코스 이름에 [query]가 들어간 코스. 띄어쓰기와 대소문자는 무시한다.
List<Course> searchCourses(List<Course> courses, String query) {
  String normalize(String s) => s.replaceAll(' ', '').toLowerCase();
  final q = normalize(query);
  if (q.isEmpty) return const [];
  return [
    for (final c in courses)
      if (normalize('${c.mountainName}${c.name}${c.startName}').contains(q)) c,
  ];
}

/// 코스 목록의 "버전": 코스 수와 마지막 수정 시각.
/// 서버와 기기의 버전이 같으면 코스를 다시 내려받지 않는다.
class CatalogVersion {
  const CatalogVersion({required this.count, this.latestUpdate});

  final int count;
  final DateTime? latestUpdate;

  bool sameAs(CatalogVersion other) {
    if (count != other.count) return false;
    final a = latestUpdate;
    final b = other.latestUpdate;
    if (a == null || b == null) return a == b;
    return a.isAtSameMomentAs(b);
  }

  @override
  String toString() => 'CatalogVersion($count, $latestUpdate)';
}
