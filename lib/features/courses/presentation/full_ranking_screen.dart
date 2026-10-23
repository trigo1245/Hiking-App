import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/design.dart';
import '../../../core/widgets/pressable.dart';
import '../../../core/widgets/segmented_tabs.dart';
import '../../../core/widgets/skeleton_box.dart';
import '../data/competition_remote.dart';
import '../domain/competition.dart';
import 'competition_providers.dart';
import 'course_detail_screen.dart';

/// 전체 순위를 30명씩 나눠 받는다. 조건(종류·기간·검색어)이 바뀌면 처음부터 다시 받는다.
class RankingPager extends ChangeNotifier {
  RankingPager(this._remote, this.courseId, this._season);

  static const pageSize = 30;

  final CompetitionRemote _remote;
  final String courseId;
  final Season _season;

  RankingKind kind = RankingKind.most;
  bool allTime = false;
  String query = '';

  final entries = <RankingEntry>[];
  int? total;
  bool loading = false;
  Object? error;

  /// 조건이 바뀔 때마다 1씩 늘린다. 늦게 도착한 예전 응답을 버리기 위해서다.
  int _generation = 0;

  bool get hasMore => total == null || entries.length < total!;

  Future<void> reset({RankingKind? kind, bool? allTime, String? query}) {
    this.kind = kind ?? this.kind;
    this.allTime = allTime ?? this.allTime;
    this.query = query ?? this.query;
    _generation++;
    entries.clear();
    total = null;
    error = null;
    loading = false;
    notifyListeners();
    return loadMore();
  }

  Future<void> loadMore() async {
    if (loading || !hasMore) return;
    final generation = _generation;
    loading = true;
    notifyListeners();
    try {
      final page = await _remote.fetchRankingPage(
        courseId,
        kind,
        season: allTime ? null : _season,
        offset: entries.length,
        limit: pageSize,
        query: query.isEmpty ? null : query,
      );
      if (generation != _generation) return;
      entries.addAll(page.entries);
      total = page.total;
    } catch (e) {
      if (generation != _generation) return;
      error = e;
    } finally {
      if (generation == _generation) {
        loading = false;
        notifyListeners();
      }
    }
  }

  /// 내 순위가 나올 때까지 이어서 받는다. 찾으면 true.
  Future<bool> loadUntilMe() async {
    while (!entries.any((e) => e.isMe) && hasMore && error == null) {
      final before = entries.length;
      await loadMore();
      if (entries.length == before) break;
    }
    return entries.any((e) => e.isMe);
  }
}

/// 코스 전체 순위 (프리미엄). 30명씩 스크롤하며 받고, 닉네임 검색·내 순위로 이동을 할 수 있다.
class FullRankingScreen extends ConsumerStatefulWidget {
  const FullRankingScreen({
    super.key,
    required this.courseId,
    this.initialKind = RankingKind.most,
    this.initialAllTime = false,
  });

  final String courseId;
  final RankingKind initialKind;
  final bool initialAllTime;

  @override
  ConsumerState<FullRankingScreen> createState() => _FullRankingScreenState();
}

class _FullRankingScreenState extends ConsumerState<FullRankingScreen> {
  late final RankingPager _pager = RankingPager(
    ref.read(competitionRemoteProvider),
    widget.courseId,
    ref.read(currentSeasonProvider),
  );
  final _scroll = ScrollController();
  final _search = TextEditingController();
  final _meKey = GlobalKey();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _pager.addListener(_onChanged);
    _scroll.addListener(_onScroll);
    _pager.reset(kind: widget.initialKind, allTime: widget.initialAllTime);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _pager
      ..removeListener(_onChanged)
      ..dispose();
    _scroll.dispose();
    _search.dispose();
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  /// 끝에 가까워지면 다음 30명을 받는다.
  void _onScroll() {
    if (_scroll.position.extentAfter < 400) _pager.loadMore();
  }

  void _onSearch(String text) {
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 400),
      () => _pager.reset(query: text.trim()),
    );
  }

  Future<void> _jumpToMe() async {
    if (_search.text.isNotEmpty) {
      _search.clear();
      await _pager.reset(query: '');
    }
    final found = await _pager.loadUntilMe();
    if (!mounted) return;
    if (!found) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('아직 이 랭킹에 내 기록이 없어요')));
      return;
    }
    // 목록이 그려진 다음 내 줄로 스크롤한다.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_meKey.currentContext case final c?) {
        Scrollable.ensureVisible(c, alignment: 0.3);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = _pager;
    return Scaffold(
      appBar: AppBar(title: const Text('전체 순위')),
      body: ListView(
        controller: _scroll,
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenHorizontal,
          AppSpacing.sm,
          AppSpacing.screenHorizontal,
          AppSpacing.xxl,
        ),
        children: [
          const SafetyNoticeCard(),
          const SizedBox(height: AppSpacing.lg),
          SegmentedTabs<bool>(
            options: const {false: '이번 시즌', true: '명예의 전당'},
            selected: p.allTime,
            onChanged: (v) => p.reset(allTime: v),
          ),
          const SizedBox(height: AppSpacing.sm),
          SegmentedTabs<RankingKind>(
            options: const {
              RankingKind.most: '최다완등',
              RankingKind.fastest: '최단시간',
            },
            selected: p.kind,
            onChanged: (v) => p.reset(kind: v),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _search,
                  onChanged: _onSearch,
                  style: AppTypography.body,
                  decoration: const InputDecoration(
                    hintText: '닉네임으로 찾기',
                    prefixIcon: Icon(Icons.search_rounded),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Pressable(
                onPressed: _jumpToMe,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.md,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.backgroundGrouped,
                    borderRadius: BorderRadius.circular(AppRadius.input),
                  ),
                  child: Text(
                    '내 순위',
                    style: AppTypography.body.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (p.total case final total?)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Text(
                p.query.isEmpty ? '$total명' : '"${p.query}" $total명',
                style: AppTypography.caption,
              ),
            ),
          for (final entry in p.entries)
            RankingRow(
              key: entry.isMe ? _meKey : null,
              entry: entry,
              kind: p.kind,
            ),
          if (p.loading)
            for (var i = 0; i < 3; i++) ...[
              const SkeletonBox(width: double.infinity, height: 48),
              const SizedBox(height: AppSpacing.sm),
            ]
          else if (p.error != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '인터넷에 연결되면 랭킹을 볼 수 있어요',
                  style: AppTypography.body.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                Pressable(
                  onPressed: () {
                    p.error = null;
                    p.loadMore();
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.sm,
                    ),
                    child: Text(
                      '다시 시도',
                      style: AppTypography.body.copyWith(
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ),
              ],
            )
          else if (p.entries.isEmpty)
            Text(
              p.query.isEmpty ? '아직 이 코스를 완주한 사람이 없어요' : '찾는 닉네임이 없어요',
              style: AppTypography.body.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
        ],
      ),
    );
  }
}
