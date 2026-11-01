import 'package:flutter/foundation.dart';
import 'package:hiking_app/core/photos/photo_item.dart';
import 'package:hiking_app/core/photos/photo_picker.dart';
import 'package:hiking_app/core/photos/photo_spec.dart';
import 'package:hiking_app/features/activities/data/activity_photo_remote.dart';
import 'package:hiking_app/features/auth/data/avatar_remote.dart';

/// 1×1 PNG (화면에 그릴 수 있는 가장 작은 사진)
final tinyPhoto = Uint8List.fromList(const [
  137, 80, 78, 71, 13, 10, 26, 10, 0, 0, 0, 13, 73, 72, 68, 82, 0, 0, 0, 1, //
  0, 0, 0, 1, 8, 6, 0, 0, 0, 31, 21, 196, 137, 0, 0, 0, 13, 73, 68, 65, 84,
  120, 156, 99, 248, 15, 4, 0, 9, 251, 3, 253, 227, 85, 242, 156, 0, 0, 0, 0,
  73, 69, 78, 68, 174, 66, 96, 130,
]);

/// 앨범·카메라 대신 정해 둔 장수만큼 사진을 돌려주는 가짜
class FakePhotoPicker implements PhotoPicker {
  FakePhotoPicker({this.count = 2});

  /// 한 번 고를 때 돌려줄 장수 (limit보다 많으면 limit만큼)
  int count;
  final requests = <(PhotoSource, PhotoSpec, int)>[];

  @override
  Future<List<Uint8List>> pick(
    PhotoSource source,
    PhotoSpec spec, {
    int limit = 1,
  }) async {
    requests.add((source, spec, limit));
    return List.filled(count < limit ? count : limit, tinyPhoto);
  }
}

/// 서버 대신 산행 기록 사진을 기억하는 가짜
class FakeActivityPhotoRemote implements ActivityPhotoRemote {
  final photos = <String, List<PhotoItem>>{};
  var _next = 0;

  @override
  Future<List<PhotoItem>> fetch(String activityId) async => [
    ...?photos[activityId],
  ];

  @override
  Future<void> add(String activityId, Uint8List jpeg) async {
    _next++;
    (photos[activityId] ??= []).add(
      PhotoItem(
        id: 'p$_next',
        path: 'u1/$activityId/p$_next.jpg',
        url: 'https://example.com/p$_next.jpg',
      ),
    );
  }

  @override
  Future<void> delete(PhotoItem photo) async {
    for (final list in photos.values) {
      list.removeWhere((p) => p.id == photo.id);
    }
  }
}

/// 서버 대신 프로필 사진 바꾸기를 기억하는 가짜
class FakeAvatarRemote implements AvatarRemote {
  int uploads = 0;
  int resets = 0;

  @override
  Future<void> upload(Uint8List jpeg) async => uploads++;

  @override
  Future<void> reset() async => resets++;
}
