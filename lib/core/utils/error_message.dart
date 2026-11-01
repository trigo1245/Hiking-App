import 'dart:async';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

/// 실패했을 때 보여 줄 문구. 원인을 나눠서 안내한다.
/// - 서버가 이유를 한국어로 알려 준 거절(예: "인원이 가득 찼어요") → 그 문구 그대로
/// - 인터넷 연결 문제 → "[failed]. 인터넷 연결을 확인해 주세요"
/// - 그 밖의 서버 오류 → "[failed]. 잠시 후 다시 시도해 주세요"
String errorMessage(Object error, {String failed = '처리하지 못했어요'}) {
  if (error is PostgrestException && RegExp(r'[가-힣]').hasMatch(error.message)) {
    return error.message;
  }
  if (isNetworkError(error)) return '$failed. 인터넷 연결을 확인해 주세요';
  return '$failed. 잠시 후 다시 시도해 주세요';
}

/// 인터넷이 끊겼거나 서버에 닿지 못한 오류인지.
bool isNetworkError(Object error) {
  if (error is SocketException || error is TimeoutException) return true;
  if (error is AuthRetryableFetchException) return true;
  final text = error.toString();
  return text.contains('SocketException') ||
      text.contains('ClientException') ||
      text.contains('Failed host lookup') ||
      text.contains('Connection closed') ||
      text.contains('Connection refused') ||
      text.contains('Network is unreachable');
}
