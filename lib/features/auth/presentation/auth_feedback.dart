import 'package:flutter/material.dart';

import '../domain/app_user.dart';
import '../domain/auth_failure.dart';

extension SocialProviderLabel on SocialProvider {
  String get label => switch (this) {
    SocialProvider.kakao => '카카오',
    SocialProvider.google => '구글',
  };
}

/// 사용자에게 보여 줄 문구. 취소는 안내하지 않으므로 null.
String? authFailureMessage(AuthFailure failure) => switch (failure.type) {
  AuthFailureType.cancelled => null,
  AuthFailureType.notConfigured => '로그인 설정이 아직 끝나지 않았어요. 개발팀에 알려 주세요.',
  AuthFailureType.network => '인터넷 연결을 확인하고 다시 시도해 주세요.',
  AuthFailureType.unknown => '로그인하지 못했어요. 잠시 후 다시 시도해 주세요.',
};

void showAuthFailure(BuildContext context, AuthFailure failure) {
  // 원인 파악용. 화면에는 짧은 문구만 보여 준다.
  debugPrint('[auth] $failure');
  final message = authFailureMessage(failure);
  if (message == null) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}
