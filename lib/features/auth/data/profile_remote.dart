import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_setup.dart';
import '../domain/profile.dart';
import '../domain/profile_rules.dart';

/// 프로필 편집(공개)·개인정보(본인만)를 서버와 주고받는 창구. 테스트에서는 가짜로 바꿔 끼운다.
abstract interface class ProfileRemote {
  /// 닉네임·소개·주 활동 지역을 저장하고, 바뀐(또는 그대로인) 태그를 돌려준다.
  Future<String> updateMyProfile({
    required String nickname,
    String? bio,
    String? region,
  });

  /// 다른 사용자의 공개 프로필. 없으면 null.
  Future<PublicProfile?> fetchPublicProfile(String nickname, String tag);

  /// 내 개인정보. 아직 없으면 빈 값.
  Future<PrivateInfo> fetchPrivateInfo();

  Future<void> savePrivateInfo(PrivateInfo info);
}

class SupabaseProfileRemote implements ProfileRemote {
  SupabaseProfileRemote(this._client);

  final SupabaseClient _client;

  @override
  Future<String> updateMyProfile({
    required String nickname,
    String? bio,
    String? region,
  }) async {
    return await _client.rpc<String>(
      'update_my_profile',
      params: {'p_nickname': nickname, 'p_bio': bio, 'p_region': region},
    );
  }

  @override
  Future<PublicProfile?> fetchPublicProfile(String nickname, String tag) async {
    final rows = await _client.rpc<List<dynamic>>(
      'get_public_profile',
      params: {'p_nickname': nickname, 'p_tag': tag},
    );
    if (rows.isEmpty) return null;
    final r = rows.first as Map<String, dynamic>;
    return PublicProfile(
      nickname: r['nickname'] as String,
      nicknameTag: r['nickname_tag'] as String,
      avatarUrl: r['avatar_url'] as String?,
      bio: r['bio'] as String?,
      region: r['region'] as String?,
      isMe: r['is_me'] as bool? ?? false,
    );
  }

  @override
  Future<PrivateInfo> fetchPrivateInfo() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return const PrivateInfo();
    final row = await _client
        .from('private_profiles')
        .select()
        .eq('user_id', userId)
        .maybeSingle();
    if (row == null) return const PrivateInfo();
    return PrivateInfo(
      name: row['name'] as String?,
      phone: row['phone'] as String?,
      postcode: row['postcode'] as String?,
      address: row['address'] as String?,
      addressDetail: row['address_detail'] as String?,
    );
  }

  @override
  Future<void> savePrivateInfo(PrivateInfo info) async {
    String? blank(String? v) => (v ?? '').trim().isEmpty ? null : v!.trim();
    await _client.from('private_profiles').upsert({
      'user_id': _client.auth.currentUser!.id,
      'name': blank(info.name),
      'phone': blank(normalizePhone(info.phone ?? '')),
      'postcode': blank(info.postcode),
      'address': blank(info.address),
      'address_detail': blank(info.addressDetail),
    });
  }
}

final profileRemoteProvider = Provider<ProfileRemote>((ref) {
  return SupabaseProfileRemote(ref.watch(supabaseClientProvider));
});

/// 내 개인정보 (내 정보·개인정보 관리 화면)
final myPrivateInfoProvider = FutureProvider.autoDispose<PrivateInfo>(
  (ref) => ref.watch(profileRemoteProvider).fetchPrivateInfo(),
);

/// 다른 사용자의 공개 프로필
final publicProfileProvider = FutureProvider.autoDispose
    .family<PublicProfile?, (String, String)>(
      (ref, key) =>
          ref.watch(profileRemoteProvider).fetchPublicProfile(key.$1, key.$2),
    );
