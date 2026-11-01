import 'dart:async';

import 'package:hiking_app/features/mileage/data/mileage_remote.dart';
import 'package:hiking_app/features/mileage/domain/mileage.dart';

/// 서버 대신 마일리지 장부를 기억하는 가짜. 배지 중복 걸러 내기와 교환을 흉내 낸다.
class FakeMileageRemote implements MileageRemote {
  FakeMileageRemote({int balance = 0}) {
    if (balance > 0) earn(balance, '시작 잔액');
  }

  final entries = <MileageEntry>[];
  final claimedKeys = <String>{};
  final redeemed = <MileageReward>[];
  final _signals = StreamController<void>.broadcast();
  var _next = 0;

  int get balance => entries.fold(0, (sum, e) => sum + e.amount);

  /// 서버 트리거가 적립한 것처럼 넣고 Realtime 신호를 보낸다.
  void earn(int amount, String label) {
    entries.insert(
      0,
      MileageEntry(
        id: ++_next,
        amount: amount,
        reason: 'test',
        label: label,
        createdAt: DateTime(2026, 11, 2, 9),
      ),
    );
    _signals.add(null);
  }

  @override
  Future<MileageSummary> fetchSummary() async =>
      MileageSummary(balance: balance);

  @override
  Future<List<MileageEntry>> fetchHistory({
    int offset = 0,
    int limit = 30,
  }) async => entries.skip(offset).take(limit).toList();

  @override
  Future<DateTime> redeem(MileageReward reward) async {
    if (balance < reward.cost) throw Exception('모자라요');
    redeemed.add(reward);
    earn(-reward.cost, reward.label);
    return DateTime(2026, 11, 2).add(Duration(days: reward.days));
  }

  @override
  Future<int> claimBadges(List<BadgeClaim> claims) async {
    var total = 0;
    for (final c in claims) {
      if (claimedKeys.add('${c.id}:${c.level}')) {
        total += badgeMileage(c.tier);
        entries.insert(
          0,
          MileageEntry(
            id: ++_next,
            amount: badgeMileage(c.tier),
            reason: 'badge',
            label: '배지 · ${c.name}',
            createdAt: DateTime(2026, 11, 2, 9),
          ),
        );
      }
    }
    return total;
  }

  @override
  Stream<void> watchMine() => _signals.stream;
}
