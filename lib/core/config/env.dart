/// `--dart-define-from-file=env.json`으로 빌드 시점에 주입되는 값.
/// 비밀 값(Client Secret 등)은 여기에 두지 않는다. 앱에 들어간 값은 누구나 꺼내 볼 수 있다.
abstract final class Env {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabasePublishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
  );

  /// Google Cloud의 "웹 애플리케이션" 유형 OAuth 클라이언트 ID.
  static const googleWebClientId = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
  );

  /// 브라우저 로그인(카카오) 후 앱으로 돌아오는 딥링크.
  /// AndroidManifest.xml, Supabase Redirect URLs와 글자 하나까지 같아야 한다.
  static const authRedirectUrl = 'com.hikingapp.hikingapp://login-callback';
}
