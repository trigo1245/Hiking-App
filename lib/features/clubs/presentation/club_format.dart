/// 일정 날짜·시간 표시. 예: 11월 8일 (토) 오전 8:00
String formatEventTime(DateTime t) {
  final l = t.toLocal();
  const days = ['월', '화', '수', '목', '금', '토', '일'];
  final period = l.hour < 12 ? '오전' : '오후';
  final hour = l.hour % 12 == 0 ? 12 : l.hour % 12;
  final minute = l.minute.toString().padLeft(2, '0');
  return '${l.month}월 ${l.day}일 (${days[l.weekday - 1]}) $period $hour:$minute';
}

/// 공지 날짜. 예: 11월 3일
String formatShortDate(DateTime t) {
  final l = t.toLocal();
  return '${l.month}월 ${l.day}일';
}
