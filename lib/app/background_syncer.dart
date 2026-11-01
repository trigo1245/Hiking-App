import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/activities/presentation/activities_providers.dart';
import '../features/chat/data/chat_remote.dart';
import '../features/clubs/data/club_remote.dart';
import '../features/courses/data/course_repository.dart';
import '../features/courses/presentation/competition_providers.dart';
import '../features/subscription/data/subscription_remote.dart';

/// 동호회 화면(가입 신청·공지·일정·회원)을 다시 받는 간격.
/// 동호회는 Realtime을 쓰지 않아서, 앱이 화면에 떠 있는 동안 이 간격으로 다시 받는다.
const clubRefreshInterval = Duration(seconds: 20);

/// 서버와 주고받는 작업을 하는 시점을 정한다.
/// - 올리지 못한 기록 다시 올리기
/// - 다른 기기에서 올린 내 기록 받기 (기기를 바꾸거나 다시 설치해도 기록·통계가 이어지게)
/// - 최신 코스 받아 기기에 저장하기 (오프라인 지도용)
/// - 다른 사람이 바꾼 것 다시 받기: 채팅은 Realtime 신호를 받자마자, 동호회는 [clubRefreshInterval]마다
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
  StreamSubscription<void>? _chatSignals;
  Timer? _chatDebounce;
  Timer? _clubTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _sync();
    _startLive();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopLive();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _sync();
      _refreshChats();
      _refreshClubs();
      _startLive();
    } else if (state == AppLifecycleState.paused) {
      // 화면이 꺼져 있는 동안은 받지 않는다 (전송량 절약). 돌아오면 한 번에 다시 받는다.
      _stopLive();
    }
  }

  void _sync() {
    final records = ref.read(uploadActionsProvider);
    // 이 기기의 기록을 먼저 올린 뒤, 다른 기기에서 올린 기록을 받는다.
    unawaited(records.uploadPending().then((_) => records.downloadMissing()));
    unawaited(ref.read(courseRepositoryProvider).sync());
    // 다른 사람이 정복자를 바꿨을 수 있으니 다시 받는다.
    ref.invalidate(conquerorsProvider);
    // 구독 상태도 서버 기준으로 다시 확인한다.
    ref.invalidate(mySubscriptionProvider);
  }

  void _startLive() {
    _chatSignals ??= ref.read(chatRemoteProvider).watchMine().listen((_) {
      // 메시지가 몰려 와도 한 번만 다시 받는다.
      _chatDebounce?.cancel();
      _chatDebounce = Timer(const Duration(milliseconds: 300), _refreshChats);
    }, onError: (Object e) => debugPrint('[live] chat: $e'));
    _clubTimer ??= Timer.periodic(clubRefreshInterval, (_) => _refreshClubs());
  }

  void _stopLive() {
    _chatSignals?.cancel();
    _chatSignals = null;
    _chatDebounce?.cancel();
    _clubTimer?.cancel();
    _clubTimer = null;
  }

  void _refreshChats() {
    if (mounted) refreshSharedData(ref, chats: true);
  }

  void _refreshClubs() {
    if (mounted) refreshSharedData(ref, clubs: true, chats: true);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// 다른 사람이 바꿨을 수 있는 값을 다시 받는다. 지금 화면에 없는 값은 받지 않는다(autoDispose).
/// - [chats]: 안 읽은 수, 1:1 메시지 목록, 동호회 채팅 미리보기
/// - [clubs]: 내 소속·가입 신청 상태, 동호회 상세, 가입 신청 목록, 공지, 일정·참석, 회원 목록
void refreshSharedData(
  WidgetRef ref, {
  bool chats = false,
  bool clubs = false,
}) {
  if (chats) {
    ref
      ..invalidate(chatBadgesProvider)
      ..invalidate(directChatsProvider)
      ..invalidate(chatPreviewProvider);
  }
  if (clubs) {
    ref
      ..invalidate(myClubStatusProvider)
      ..invalidate(clubDetailProvider)
      ..invalidate(clubJoinRequestsProvider)
      ..invalidate(clubNoticesProvider)
      ..invalidate(clubEventsProvider)
      ..invalidate(clubMembersProvider);
  }
}
