import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../core/design/design.dart';

/// 하단 탭(홈 / 기록 / 내 정보)을 가진 바깥 틀.
/// 각 탭의 화면 상태는 [StatefulNavigationShell]이 따로 보관한다.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  void _onTap(int index) {
    HapticFeedback.selectionClick();
    navigationShell.goBranch(
      index,
      // 이미 선택된 탭을 다시 누르면 그 탭의 첫 화면으로 돌아간다.
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.divider)),
        ),
        child: BottomNavigationBar(
          currentIndex: navigationShell.currentIndex,
          onTap: _onTap,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home_rounded),
              label: '홈',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.list_alt_outlined),
              activeIcon: Icon(Icons.list_alt_rounded),
              label: '기록',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline_rounded),
              activeIcon: Icon(Icons.person_rounded),
              label: '내 정보',
            ),
          ],
        ),
      ),
    );
  }
}
