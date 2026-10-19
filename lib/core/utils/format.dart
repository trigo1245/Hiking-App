/// 기록 시간 표시. 예: 0:05:09, 1:23:45
String formatClock(Duration d) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${d.inHours}:${two(d.inMinutes % 60)}:${two(d.inSeconds % 60)}';
}

/// km 단위, 소수점 둘째 자리. 예: 3.42
String formatKm(double meters) => (meters / 1000).toStringAsFixed(2);

/// m 단위 정수. 값이 없으면 "-"
String formatMeters(double? meters) =>
    meters == null ? '-' : meters.round().toString();

/// 긴 시간 합계. 예: 12시간 5분, 45분
String formatHoursMinutes(Duration d) {
  final hours = d.inHours;
  final minutes = d.inMinutes % 60;
  return hours == 0 ? '$minutes분' : '$hours시간 $minutes분';
}

/// 날짜와 시각. 예: 10월 13일 오전 9:05
String formatDateTime(DateTime t) {
  final period = t.hour < 12 ? '오전' : '오후';
  final hour = t.hour % 12 == 0 ? 12 : t.hour % 12;
  final minute = t.minute.toString().padLeft(2, '0');
  return '${t.month}월 ${t.day}일 $period $hour:$minute';
}
