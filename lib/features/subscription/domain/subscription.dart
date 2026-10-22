/// 프리미엄 구독 상태
class Subscription {
  const Subscription({
    required this.startedAt,
    required this.expiresAt,
    required this.isActive,
  });

  final DateTime startedAt;
  final DateTime expiresAt;
  final bool isActive;
}

/// 표시용 가격. 기획서 7.4에서 요금이 확정되면 이 값만 바꾼다.
const premiumPriceLabel = '월 4,900원';

/// 구독하면 받는 혜택 (기획서 6.1·6.4 중 지금 구현된 것)
const premiumBenefits = [
  ('랭킹 전체 순위', '상위 10명 너머 모든 순위와 기록을 볼 수 있어요'),
  ('시간별 고도 그래프', '쉬어 간 구간(초록)과 급경사 위험 구간(빨강)을 한눈에 볼 수 있어요'),
  ('경사 보정 페이스', '경사를 보정해(Tobler 공식) 오르막·평지·내리막 페이스를 공정하게 비교해요'),
  ('km별 기록', '1km마다 걸린 시간과 오른 높이를 보여 줘요'),
  ('전반·후반 비교', '후반에 얼마나 지쳤는지 오르막 속도로 비교해요'),
  ('같은 코스 기록 비교', '같은 코스를 다시 갔을 때 회차별 기록을 비교해요'),
  ('종합 분석', '체력·피로도 추이, 휴식 패턴, 급경사 습관, 코스별 최고 기록을 모아 봐요'),
];
