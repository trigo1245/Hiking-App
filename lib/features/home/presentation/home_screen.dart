import 'package:flutter/material.dart';

import '../../../core/widgets/empty_view.dart';

/// 홈 탭. 이후 이번 달 요약, 최근 기록, "등산 기록 시작" 버튼이 들어간다.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('홈')),
      body: const EmptyView(message: '홈 화면을 준비하고 있어요'),
    );
  }
}
