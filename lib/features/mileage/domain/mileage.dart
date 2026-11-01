/// 마일리지: 참여(산행·완주·리뷰·배지)로 쌓고 프리미엄 교환권으로만 쓴다.
/// 적립 계산은 서버가 하고(CLAUDE.md 6-2장 "마일리지"), 여기는 화면에 보여 줄 값과 규칙 문구만 둔다.
library;

import '../../achievements/domain/achievements.dart';

/// 프리미엄 구독 중 적립 배율
const mileagePremiumRate = 1.5;

/// 하루(한국 시간) 적립 한도. 프리미엄은 1.5배. 배지는 한도와 별도.
const mileageDailyCap = 200;

class MileageSummary {
  const MileageSummary({
    required this.balance,
    this.earnedToday = 0,
    this.dailyCap = mileageDailyCap,
    this.premium = false,
  });

  final int balance;
  final int earnedToday;
  final int dailyCap;

  /// 프리미엄 구독 중 (1.5배 적립)
  final bool premium;
}

class MileageEntry {
  const MileageEntry({
    required this.id,
    required this.amount,
    required this.reason,
    required this.label,
    required this.createdAt,
  });

  final int id;

  /// 적립은 +, 사용은 -
  final int amount;
  final String reason;
  final String label;
  final DateTime createdAt;
}

/// 프리미엄 교환권
enum MileageReward {
  week('7d', '프리미엄 7일 교환권', 500, 7),
  month('30d', '프리미엄 30일 교환권', 1800, 30);

  const MileageReward(this.id, this.label, this.cost, this.days);

  /// 서버 redeem_mileage에 보내는 값
  final String id;
  final String label;
  final int cost;
  final int days;
}

/// 적립 방법 안내 (서버 트리거·claim_badge_mileage와 같은 값)
class MileageRule {
  const MileageRule(this.title, this.amount, this.note);

  final String title;

  /// 일반 사용자 기준
  final int amount;
  final String note;

  /// 프리미엄이면 1.5배(올림)
  int amountFor({required bool premium}) =>
      premium ? (amount * mileagePremiumRate).ceil() : amount;

  static const all = [
    MileageRule('산행 기록', 10, '1km 이상, 하루 2번까지'),
    MileageRule('코스 완주', 30, '같은 코스는 하루 1번'),
    MileageRule('코스 리뷰', 20, '코스마다 처음 1번'),
    MileageRule('상품 리뷰', 20, '상품마다 처음 1번, 사진을 붙이면 10 더'),
    MileageRule('업적 배지', 30, '배지 단계마다 처음 1번 · 동 30 · 은 50 · 금 100 · 하루 한도와 별도'),
  ];
}

/// 배지 단계 색에 따른 적립 (서버와 같다)
int badgeMileage(BadgeTier tier) => switch (tier) {
  BadgeTier.bronze => 30,
  BadgeTier.silver => 50,
  BadgeTier.gold => 100,
};

/// 서버에 알릴 배지 한 단계
class BadgeClaim {
  const BadgeClaim({
    required this.id,
    required this.level,
    required this.tier,
    required this.name,
  });

  final String id;
  final int level;
  final BadgeTier tier;
  final String name;

  Map<String, Object> toJson() => {
    'id': id,
    'level': level,
    'tier': tier.name,
    'name': name,
  };
}

/// 지금 얻은 배지의 모든 단계 (서버가 이미 준 것은 걸러 낸다). 시즌 정복 기록은 넣지 않는다.
List<BadgeClaim> badgeClaimsOf(Achievements achievements) => [
  for (final b in achievements.badges)
    for (var level = 1; level <= b.level; level++)
      BadgeClaim(
        id: b.def.id,
        level: level,
        tier: b.def.tierOf(level),
        name: b.def.name,
      ),
];

/// 1800 → "1,800"
String formatMileage(int value) {
  final negative = value < 0;
  final digits = value.abs().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return '${negative ? '-' : ''}$buffer';
}
