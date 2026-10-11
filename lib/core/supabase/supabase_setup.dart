import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// `--dart-define-from-file=env.json`으로 빌드 시점에 주입되는 값.
const _supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const _supabasePublishableKey = String.fromEnvironment(
  'SUPABASE_PUBLISHABLE_KEY',
);

/// 앱 시작 시 한 번 호출한다.
Future<void> initSupabase() async {
  if (_supabaseUrl.isEmpty || _supabasePublishableKey.isEmpty) {
    throw StateError(
      'Supabase 설정이 없어요. env.example.json을 복사해 env.json을 만들고 '
      '--dart-define-from-file=env.json 옵션으로 실행해 주세요.',
    );
  }

  await Supabase.initialize(
    url: _supabaseUrl,
    publishableKey: _supabasePublishableKey,
  );
}

/// 화면·repository에서는 `Supabase.instance` 대신 이 provider로 클라이언트를 받는다.
/// (테스트에서 가짜 클라이언트로 바꿔 끼우기 쉽다)
final supabaseClientProvider = Provider<SupabaseClient>(
  (ref) => Supabase.instance.client,
);
