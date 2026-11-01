import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_setup.dart';
import '../domain/mileage.dart';

/// 마일리지를 서버와 주고받는 창구. 적립은 서버 트리거가 하고, 앱은 배지만 알린다.
abstract interface class MileageRemote {
  Future<MileageSummary> fetchSummary();
  Future<List<MileageEntry>> fetchHistory({int offset, int limit});

  /// 교환권으로 바꾼다. 새로 끝나는 구독 시각.
  Future<DateTime> redeem(MileageReward reward);

  /// 얻은 배지를 알린다. 이번에 새로 받은 마일리지 합계.
  Future<int> claimBadges(List<BadgeClaim> claims);

  /// 내 마일리지가 바뀌면 신호를 보낸다 (내용은 [fetchSummary]로 다시 받는다).
  Stream<void> watchMine();
}

class SupabaseMileageRemote implements MileageRemote {
  SupabaseMileageRemote(this._client);

  final SupabaseClient _client;

  @override
  Future<MileageSummary> fetchSummary() async {
    final rows = await _client.rpc<List<dynamic>>('get_my_mileage');
    if (rows.isEmpty) return const MileageSummary(balance: 0);
    final r = rows.first as Map<String, dynamic>;
    return MileageSummary(
      balance: (r['balance'] as int?) ?? 0,
      earnedToday: (r['earned_today'] as int?) ?? 0,
      dailyCap: (r['daily_cap'] as int?) ?? mileageDailyCap,
      premium: (r['premium'] as bool?) ?? false,
    );
  }

  @override
  Future<List<MileageEntry>> fetchHistory({
    int offset = 0,
    int limit = 30,
  }) async {
    final rows = await _client.rpc<List<dynamic>>(
      'get_my_mileage_history',
      params: {'p_offset': offset, 'p_limit': limit},
    );
    return [
      for (final r in rows.cast<Map<String, dynamic>>())
        MileageEntry(
          id: r['id'] as int,
          amount: r['amount'] as int,
          reason: r['reason'] as String,
          label: r['label'] as String,
          createdAt: DateTime.parse(r['created_at'] as String).toLocal(),
        ),
    ];
  }

  @override
  Future<DateTime> redeem(MileageReward reward) async {
    final expires = await _client.rpc<String>(
      'redeem_mileage',
      params: {'p_item': reward.id},
    );
    return DateTime.parse(expires).toLocal();
  }

  @override
  Future<int> claimBadges(List<BadgeClaim> claims) async {
    if (claims.isEmpty) return 0;
    final total = await _client.rpc<int>(
      'claim_badge_mileage',
      params: {
        'p_claims': [for (final c in claims) c.toJson()],
      },
    );
    return total;
  }

  @override
  Stream<void> watchMine() {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return const Stream.empty();
    late final RealtimeChannel channel;
    final controller = StreamController<void>(
      onCancel: () => _client.removeChannel(channel),
    );
    channel = _client
        .channel('mileage-$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'mileage_ledger',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (_) => controller.add(null),
        )
        .subscribe();
    return controller.stream;
  }
}

final mileageRemoteProvider = Provider<MileageRemote>((ref) {
  return SupabaseMileageRemote(ref.watch(supabaseClientProvider));
});

// 화면에서 쓰는 값. 실패하면 자동으로 다시 시도하지 않고 오류를 보여 준다.
final mileageSummaryProvider = FutureProvider.autoDispose<MileageSummary>(
  (ref) => ref.watch(mileageRemoteProvider).fetchSummary(),
  retry: (_, _) => null,
);

/// 최근 내역 50개
final mileageHistoryProvider = FutureProvider.autoDispose<List<MileageEntry>>(
  (ref) => ref.watch(mileageRemoteProvider).fetchHistory(limit: 50),
  retry: (_, _) => null,
);
