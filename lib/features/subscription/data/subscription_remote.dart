import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_setup.dart';
import '../domain/subscription.dart';

/// 구독 상태를 서버와 주고받는 창구. 구독 여부 판단은 서버(DB)가 한다.
abstract interface class SubscriptionRemote {
  /// 구독한 적이 없으면 null
  Future<Subscription?> fetchMine();

  /// 시연용 결제: 실제 결제 없이 지금부터 한 달 구독한다.
  Future<void> startDemo();

  /// 해지: 남은 기간과 상관없이 바로 끝난다. (시연 편의)
  Future<void> cancel();
}

class SupabaseSubscriptionRemote implements SubscriptionRemote {
  SupabaseSubscriptionRemote(this._client);

  final SupabaseClient _client;

  @override
  Future<Subscription?> fetchMine() async {
    final rows = await _client.rpc<List<dynamic>>('get_my_subscription');
    final r = rows.cast<Map<String, dynamic>>().firstOrNull;
    if (r == null) return null;
    return Subscription(
      startedAt: DateTime.parse(r['started_at'] as String),
      expiresAt: DateTime.parse(r['expires_at'] as String),
      isActive: r['is_active'] as bool,
    );
  }

  @override
  Future<void> startDemo() => _client.rpc<void>('start_demo_subscription');

  @override
  Future<void> cancel() => _client.rpc<void>('cancel_subscription');
}

final subscriptionRemoteProvider = Provider<SubscriptionRemote>((ref) {
  return SupabaseSubscriptionRemote(ref.watch(supabaseClientProvider));
});

/// 내 구독 상태. 결제·해지 후에는 이 provider를 새로 고친다.
final mySubscriptionProvider = FutureProvider<Subscription?>(
  (ref) => ref.watch(subscriptionRemoteProvider).fetchMine(),
  retry: (_, _) => null,
);

/// 지금 프리미엄인지. 모르거나(오프라인) 불러오는 중이면 일반 사용자로 본다.
final isPremiumProvider = Provider<bool>(
  (ref) => ref.watch(mySubscriptionProvider).value?.isActive ?? false,
);
