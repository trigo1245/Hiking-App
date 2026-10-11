import 'package:flutter/material.dart';

import '../../../core/widgets/empty_view.dart';

/// 기록 탭. 이후 날짜 역순 기록 카드 목록과 업로드 상태가 들어간다.
class ActivitiesScreen extends StatelessWidget {
  const ActivitiesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('기록')),
      body: const EmptyView(message: '아직 등산 기록이 없어요'),
    );
  }
}
