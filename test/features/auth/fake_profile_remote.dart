import 'package:hiking_app/features/auth/data/profile_remote.dart';
import 'package:hiking_app/features/auth/domain/profile.dart';
import 'package:hiking_app/features/auth/domain/profile_rules.dart';

/// 서버 대신 프로필·개인정보를 기억하는 가짜
class FakeProfileRemote implements ProfileRemote {
  /// 닉네임#태그 → 공개 프로필
  final publicProfiles = <String, PublicProfile>{};
  PrivateInfo privateInfo = const PrivateInfo();
  final updates = <(String, String?, String?)>[];
  int privateSaves = 0;

  /// 저장할 때 돌려줄 태그 (같은 닉네임이 있어 태그가 바뀌는 경우를 흉내 낸다)
  String tag = '0369';

  @override
  Future<String> updateMyProfile({
    required String nickname,
    String? bio,
    String? region,
  }) async {
    updates.add((nickname, bio, region));
    return tag;
  }

  @override
  Future<PublicProfile?> fetchPublicProfile(
    String nickname,
    String tag,
  ) async => publicProfiles['$nickname#$tag'];

  /// true면 인터넷이 없거나 서버 준비가 안 된 것처럼 실패한다.
  bool failPrivate = false;

  @override
  Future<PrivateInfo> fetchPrivateInfo() async {
    if (failPrivate) throw Exception('offline');
    return privateInfo;
  }

  @override
  Future<void> savePrivateInfo(PrivateInfo info) async {
    privateSaves++;
    privateInfo = info;
  }
}
