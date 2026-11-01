import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../core/supabase/supabase_setup.dart';

/// 프로필 사진을 담는 공개 버킷. 경로: {user_id}/{사진 id}.jpg
/// (동호회 프로필 사진도 이후 같은 방식으로 붙인다)
const avatarBucket = 'avatars';

/// 프로필 사진 바꾸기·되돌리기. 테스트에서는 가짜로 바꿔 끼운다.
abstract interface class AvatarRemote {
  /// 직접 고른 사진으로 바꾼다. 이전에 올린 사진 파일은 지운다.
  Future<void> upload(Uint8List jpeg);

  /// 카카오·구글 프로필 사진으로 되돌린다.
  Future<void> reset();
}

class SupabaseAvatarRemote implements AvatarRemote {
  SupabaseAvatarRemote(this._client);

  final SupabaseClient _client;

  @override
  Future<void> upload(Uint8List jpeg) async {
    final userId = _client.auth.currentUser!.id;
    final path = '$userId/${const Uuid().v4()}.jpg';
    final bucket = _client.storage.from(avatarBucket);
    await bucket.uploadBinary(
      path,
      jpeg,
      fileOptions: const FileOptions(contentType: 'image/jpeg'),
    );
    final String? old;
    try {
      old = await _client.rpc<String?>(
        'set_my_avatar',
        params: {'p_path': path, 'p_url': bucket.getPublicUrl(path)},
      );
    } catch (_) {
      await bucket.remove([path]);
      rethrow;
    }
    await _removeOld(old);
  }

  @override
  Future<void> reset() async {
    await _removeOld(await _client.rpc<String?>('reset_my_avatar'));
  }

  Future<void> _removeOld(String? path) async {
    if (path == null) return;
    try {
      await _client.storage.from(avatarBucket).remove([path]);
    } catch (e) {
      debugPrint('[avatar] 이전 사진을 지우지 못했어요: $e');
    }
  }
}

final avatarRemoteProvider = Provider<AvatarRemote>((ref) {
  return SupabaseAvatarRemote(ref.watch(supabaseClientProvider));
});
