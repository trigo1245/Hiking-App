import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:hiking_app/features/auth/data/supabase_auth_repository.dart';
import 'package:hiking_app/features/auth/domain/auth_failure.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('mapAuthError', () {
    test('구글 로그인 창을 닫으면 cancelled', () {
      const error = GoogleSignInException(
        code: GoogleSignInExceptionCode.canceled,
      );
      expect(mapAuthError(error).type, AuthFailureType.cancelled);
    });

    test('구글 콘솔 설정 오류는 notConfigured', () {
      const error = GoogleSignInException(
        code: GoogleSignInExceptionCode.clientConfigurationError,
      );
      expect(mapAuthError(error).type, AuthFailureType.notConfigured);
    });

    test('API 응답의 identity_already_exists (code 필드)', () {
      const error = AuthException(
        'Identity is already linked to another user',
        code: 'identity_already_exists',
      );
      expect(mapAuthError(error).type, AuthFailureType.identityAlreadyExists);
    });

    test('브라우저 로그인 딥링크의 identity_already_exists (statusCode 필드)', () {
      const error = AuthException(
        'Identity is already linked to another user',
        statusCode: 'identity_already_exists',
        code: 'server_error',
      );
      expect(mapAuthError(error).type, AuthFailureType.identityAlreadyExists);
    });

    test('수동 연결이 꺼져 있으면 notConfigured', () {
      const error = AuthException(
        'Manual linking is disabled',
        code: 'manual_linking_disabled',
      );
      expect(mapAuthError(error).type, AuthFailureType.notConfigured);
    });

    test('네트워크 오류는 network', () {
      final error = AuthRetryableFetchException(message: 'timeout');
      expect(mapAuthError(error).type, AuthFailureType.network);
    });

    test('모르는 오류는 unknown', () {
      expect(mapAuthError(StateError('?')).type, AuthFailureType.unknown);
    });
  });
}
