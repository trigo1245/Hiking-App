import 'package:flutter_test/flutter_test.dart';
import 'package:hiking_app/features/auth/data/supabase_auth_repository.dart';
import 'package:hiking_app/features/auth/domain/auth_failure.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('mapAuthError', () {
    test('Supabase에서 로그인 방법이 꺼져 있으면 notConfigured (code 필드)', () {
      const error = AuthException(
        'Provider is not enabled',
        code: 'provider_disabled',
      );
      expect(mapAuthError(error).type, AuthFailureType.notConfigured);
    });

    test('브라우저 로그인 딥링크 오류는 statusCode 필드로 판단한다', () {
      const error = AuthException(
        'Provider is not enabled',
        statusCode: 'provider_disabled',
        code: 'server_error',
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
