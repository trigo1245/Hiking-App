import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/activities/presentation/activities_providers.dart';
import '../features/courses/data/course_repository.dart';
import '../features/courses/presentation/competition_providers.dart';

/// 서버와 주고받는 작업을 하는 시점을 정한다.
/// - 올리지 못한 기록 다시 올리기
/// - 최신 코스 받아 기기에 저장하기 (오프라인 지도용)
///
/// 시점: 로그인 후 하단 탭 화면이 처음 뜰 때, 앱이 다른 앱이나 잠금 화면에서 돌아올 때
/// (산에서 내려와 앱을 다시 여는 경우). 인터넷이 없으면 조용히 다음 기회를 기다린다.
class BackgroundSyncer extends ConsumerStatefulWidget {
  const BackgroundSyncer({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<BackgroundSyncer> createState() => _BackgroundSyncerState();
}

class _BackgroundSyncerState extends ConsumerState<BackgroundSyncer>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _sync();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _sync();
  }

  void _sync() {
    unawaited(ref.read(uploadActionsProvider).uploadPending());
    unawaited(ref.read(courseRepositoryProvider).sync());
    // 다른 사람이 정복자를 바꿨을 수 있으니 다시 받는다.
    ref.invalidate(conquerorsProvider);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
