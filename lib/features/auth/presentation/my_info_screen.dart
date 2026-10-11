import 'package:flutter/material.dart';

import '../../../core/widgets/empty_view.dart';

/// 내 정보 탭. 이후 닉네임, 로그아웃, 로그 파일 내보내기가 들어간다.
class MyInfoScreen extends StatelessWidget {
  const MyInfoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('내 정보')),
      body: const EmptyView(message: '내 정보 화면을 준비하고 있어요'),
    );
  }
}
