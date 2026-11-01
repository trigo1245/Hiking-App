import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../core/photos/photo_widgets.dart';
import '../../../core/supabase/supabase_setup.dart';

/// 산행 기록 사진을 담는 비공개 버킷. 경로: {user_id}/{activity_id}/{사진 id}.jpg
const activityPhotoBucket = 'activity-photos';

/// 산행 기록 사진 (본인만 보고, 프리미엄 구독자만 올린다. 권한은 서버가 검사한다)
abstract interface class ActivityPhotoRemote {
  /// 올린 순서대로. 화면에 그릴 주소는 1시간 동안만 쓸 수 있다.
  Future<List<PhotoItem>> fetch(String activityId);

  Future<void> add(String activityId, Uint8List jpeg);

  Future<void> delete(PhotoItem photo);
}

class SupabaseActivityPhotoRemote implements ActivityPhotoRemote {
  SupabaseActivityPhotoRemote(this._client);

  final SupabaseClient _client;

  @override
  Future<List<PhotoItem>> fetch(String activityId) async {
    final rows = await _client
        .from('activity_photos')
        .select('id, path')
        .eq('activity_id', activityId)
        .order('created_at');
    if (rows.isEmpty) return const [];
    final paths = [for (final r in rows) r['path'] as String];
    final signed = await _client.storage
        .from(activityPhotoBucket)
        .createSignedUrlsResult(paths, 3600);
    final urls = {
      for (final s in signed)
        if (s case SignedUrlSuccess(:final path, :final signedUrl))
          path: signedUrl,
    };
    return [
      for (final r in rows)
        PhotoItem(
          id: r['id'] as String,
          path: r['path'] as String,
          url: urls[r['path']] ?? '',
        ),
    ];
  }

  @override
  Future<void> add(String activityId, Uint8List jpeg) async {
    final userId = _client.auth.currentUser!.id;
    final id = const Uuid().v4();
    final path = '$userId/$activityId/$id.jpg';
    await _client.storage
        .from(activityPhotoBucket)
        .uploadBinary(
          path,
          jpeg,
          fileOptions: const FileOptions(contentType: 'image/jpeg'),
        );
    try {
      await _client.from('activity_photos').insert({
        'id': id,
        'activity_id': activityId,
        'user_id': userId,
        'path': path,
      });
    } catch (_) {
      // 행을 넣지 못하면(장수 제한 등) 올린 파일도 지운다.
      await _client.storage.from(activityPhotoBucket).remove([path]);
      rethrow;
    }
  }

  @override
  Future<void> delete(PhotoItem photo) async {
    await _client.from('activity_photos').delete().eq('id', photo.id);
    try {
      await _client.storage.from(activityPhotoBucket).remove([photo.path]);
    } catch (e) {
      debugPrint('[photo] 파일을 지우지 못했어요: $e');
    }
  }
}

final activityPhotoRemoteProvider = Provider<ActivityPhotoRemote>((ref) {
  return SupabaseActivityPhotoRemote(ref.watch(supabaseClientProvider));
});

/// 이 기록의 사진. 인터넷이 없으면 오류 상태가 된다.
final activityPhotosProvider = FutureProvider.autoDispose
    .family<List<PhotoItem>, String>(
      (ref, activityId) =>
          ref.watch(activityPhotoRemoteProvider).fetch(activityId),
    );
