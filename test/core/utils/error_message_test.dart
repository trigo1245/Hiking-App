import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hiking_app/core/utils/error_message.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('서버가 한국어로 거절한 이유는 그대로 보여 준다', () {
    expect(
      errorMessage(const PostgrestException(message: '인원이 가득 찼어요')),
      '인원이 가득 찼어요',
    );
  });

  test('연결 문제와 그 밖의 서버 오류를 나눠 안내한다', () {
    expect(
      errorMessage(
        const SocketException('Failed host lookup'),
        failed: '저장하지 못했어요',
      ),
      '저장하지 못했어요. 인터넷 연결을 확인해 주세요',
    );
    expect(isNetworkError(TimeoutException('느림')), isTrue);
    expect(
      errorMessage(const PostgrestException(message: 'permission denied')),
      '처리하지 못했어요. 잠시 후 다시 시도해 주세요',
    );
  });
}
