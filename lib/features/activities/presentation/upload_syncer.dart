import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'activities_providers.dart';

/// 올리지 못한 기록을 다시 올리는 시점을 정한다.
/// - 로그인 후 하단 탭 화면이 처음 뜰 때
/// - 앱이 다른 앱이나 잠금 화면에서 돌아올 때 (산에서 내려와 앱을 다시 여는 경우)
class UploadSyncer extends ConsumerStatefulWidget {
  const UploadSyncer({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<UploadSyncer> createState() => _UploadSyncerState();
}

class _UploadSyncerState extends ConsumerState<UploadSyncer>
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

  void _sync() => unawaited(ref.read(uploadActionsProvider).uploadPending());

  @override
  Widget build(BuildContext context) => widget.child;
}
