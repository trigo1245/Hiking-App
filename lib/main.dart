import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'core/map/map_tiles.dart';
import 'core/supabase/supabase_setup.dart';

Future<void> main() async {
  // runApp 전에 플러그인(Supabase 저장소 등)을 쓰려면 먼저 호출해야 한다.
  WidgetsFlutterBinding.ensureInitialized();
  await initSupabase();
  await initMapTileCache();

  // ProviderScope: Riverpod의 상태(provider)들이 저장되는 최상위 공간.
  runApp(const ProviderScope(child: HikingApp()));
}
