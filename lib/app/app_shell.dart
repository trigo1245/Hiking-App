import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/chat/data/chat_remote.dart';
import '../core/design/design.dart';
import 'background_syncer.dart';

/// 하단 탭(쇼핑 / 동호회 / 홈 / 기록 / 내 정보)을 가진 바깥 틀.
/// 각 탭의 화면 상태는 [StatefulNavigationShell]이 따로 보관한다.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  // 탭 순서 (router.dart의 branches와 같다): 쇼핑 / 동호회 / 홈 / 기록 / 내 정보
  static const _clubsTab = 1;
  static const _myInfoTab = 4;

  void _onTap(WidgetRef ref, int index) {
    HapticFeedback.selectionClick();
    // 동호회·내 정보 탭으로 오면 다른 사람이 바꾼 것(가입 신청·메시지 등)을 바로 다시 받는다.
    refreshSharedData(
      ref,
      clubs: index == _clubsTab,
      chats: index == _clubsTab || index == _myInfoTab,
    );
    navigationShell.goBranch(
      index,
      // 이미 선택된 탭을 다시 누르면 그 탭의 첫 화면으로 돌아간다.
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 안 읽은 메시지가 있으면 탭 아이콘에 빨간 점: 동호회 채팅은 동호회 탭, 1:1 메시지·요청은 내 정보 탭
    final badges = ref.watch(chatBadgesProvider).value;
    final clubUnread = (badges?.clubUnread ?? 0) > 0;
    final directUnread =
        (badges?.directUnread ?? 0) + (badges?.pendingRequests ?? 0) > 0;
    return Scaffold(
      // 하단 탭 화면이 떠 있는 동안 기록 업로드·코스 받기를 한다.
      body: BackgroundSyncer(child: navigationShell),
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.divider)),
        ),
        child: BottomNavigationBar(
          currentIndex: navigationShell.currentIndex,
          onTap: (i) => _onTap(ref, i),
          items: [
            const BottomNavigationBarItem(
              icon: Icon(Icons.shopping_bag_outlined),
              activeIcon: Icon(Icons.shopping_bag_rounded),
              label: '쇼핑',
            ),
            BottomNavigationBarItem(
              icon: _Dot(
                visible: clubUnread,
                child: const Icon(Icons.groups_outlined),
              ),
              activeIcon: _Dot(
                visible: clubUnread,
                child: const Icon(Icons.groups_rounded),
              ),
              label: '동호회',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home_rounded),
              label: '홈',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.list_alt_outlined),
              activeIcon: Icon(Icons.list_alt_rounded),
              label: '기록',
            ),
            BottomNavigationBarItem(
              icon: _Dot(
                visible: directUnread,
                child: const Icon(Icons.person_outline_rounded),
              ),
              activeIcon: _Dot(
                visible: directUnread,
                child: const Icon(Icons.person_rounded),
              ),
              label: '내 정보',
            ),
          ],
        ),
      ),
    );
  }
}

/// 탭 아이콘 오른쪽 위의 작은 빨간 점
class _Dot extends StatelessWidget {
  const _Dot({required this.visible, required this.child});

  final bool visible;
  final Widget child;

  @override
  Widget build(BuildContext context) => Badge(
    isLabelVisible: visible,
    smallSize: 8,
    backgroundColor: AppColors.danger,
    child: child,
  );
}
