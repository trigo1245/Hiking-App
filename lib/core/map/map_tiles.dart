import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

/// OpenStreetMap 기본 타일 (개발·시연용. CLAUDE.md 3장)
const osmTileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

/// OSM 이용 정책: 타일 요청에 앱 식별자를 넣는다.
const mapUserAgentPackageName = 'com.hikingapp.hiking_app';

/// 지도 출처 표시 문구 (항상 보여야 한다)
const mapAttribution = '© OpenStreetMap contributors · 등산로: 산림청(브이월드)';

/// 한 번 본 지도 타일을 기기에 저장해 두는 캐시를 준비한다. 앱 시작 시 한 번 호출한다.
/// - 저장 위치: 앱 전용 폴더 (운영체제가 임의로 지우는 임시 폴더가 아님)
/// - 30일 동안은 서버에 다시 묻지 않고 저장본을 쓴다. 인터넷이 없는 산에서도 보이게 하기 위해서다.
///   (OSM 이용 정책의 "최소 7일 캐시"보다 길어 서버 부담도 줄어든다)
Future<void> initMapTileCache() async {
  final dir = await getApplicationSupportDirectory();
  BuiltInMapCachingProvider.getOrCreateInstance(
    cacheDirectory: '${dir.path}/map_tiles',
    maxCacheSize: 300 * 1024 * 1024,
    overrideFreshAge: const Duration(days: 30),
  );
}

/// 지도 타일을 받을지. 위젯 테스트에서는 인터넷 요청을 막기 위해 끈다.
final mapTilesEnabledProvider = Provider<bool>((ref) => true);
