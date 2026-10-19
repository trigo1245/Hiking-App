import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/design/design.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/bottom_action_bar.dart';
import '../../../core/widgets/confirm_sheet.dart';
import '../../../core/widgets/pressable.dart';
import '../../../core/widgets/segmented_tabs.dart';
import '../../courses/data/course_repository.dart';
import '../../courses/domain/competition.dart';
import '../../courses/domain/course.dart';
import '../../courses/presentation/competition_providers.dart';
import '../../courses/presentation/course_map.dart';
import '../../recording/data/location_service.dart';
import '../../recording/domain/track_point.dart';
import '../../recording/presentation/recording_controller.dart';
import '../../recording/presentation/start_recording.dart';

/// 홈 탭 = 지도 화면. 위에는 산·코스 검색창, 아래에는 "등산 기록 시작" 버튼.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _map = MapController();
  final _search = TextEditingController();
  final _searchFocus = FocusNode();
  StreamSubscription<LocationSample>? _locationSub;
  LocationSample? _myLocation;
  bool _centerOnNextFix = false;
  String? _selectedId;
  bool _busy = false;
  RankingKind _conquerorKind = RankingKind.most;

  @override
  void initState() {
    super.initState();
    _search.addListener(() => setState(() {}));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkUnfinished();
      _showMyLocationIfAllowed();
    });
  }

  @override
  void dispose() {
    _locationSub?.cancel();
    _search.dispose();
    _searchFocus.dispose();
    _map.dispose();
    super.dispose();
  }

  /// 앱이 기록 중에 꺼졌다면 이어서 기록할지, 끝낼지 묻는다.
  Future<void> _checkUnfinished() async {
    final controller = ref.read(recordingControllerProvider.notifier);
    final unfinished = await controller.findUnfinished();
    if (unfinished == null || !mounted) return;

    final resume = await showConfirmSheet(
      context,
      title: '끝나지 않은 기록이 있어요',
      message:
          '${formatDateTime(unfinished.session.startedAt)}에 시작한 기록이 멈춰 있어요.\n'
          '이어서 기록할까요?',
      confirmLabel: '이어서 기록하기',
      cancelLabel: '여기까지 저장하기',
    );
    // 바깥을 눌러 닫으면 다음에 앱을 켤 때 다시 묻는다.
    if (resume == null || !mounted) return;

    controller.restore(unfinished);
    if (resume) {
      await controller.resume();
      if (mounted) context.go(AppRoutes.recording);
    } else {
      final id = await controller.finish();
      if (id != null && mounted) context.go(AppRoutes.recordingDone(id));
    }
  }

  /// 이미 위치 권한이 있으면 바로 내 위치를 보여 준다. (처음 켰을 때 권한을 묻지는 않는다)
  Future<void> _showMyLocationIfAllowed() async {
    if (await ref.read(locationServiceProvider).hasPreciseAccess()) {
      _listenLocation();
    }
  }

  void _listenLocation() {
    _locationSub ??= ref
        .read(locationServiceProvider)
        .watchMapPosition()
        .listen((sample) {
          if (!mounted) return;
          setState(() => _myLocation = sample);
          if (_centerOnNextFix) {
            _centerOnNextFix = false;
            _moveTo(sample);
          }
        }, onError: (Object e) => debugPrint('[map] 위치 받기 실패: $e'));
  }

  /// 내 위치 버튼: 권한이 없으면 묻고, 있으면 내 위치로 지도를 옮긴다.
  Future<void> _onMyLocation() async {
    final me = _myLocation;
    if (me != null) return _moveTo(me);

    final access = await ref.read(locationServiceProvider).requestAccess();
    if (!mounted) return;
    if (access != LocationAccess.granted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('내 위치를 보려면 정확한 위치 권한이 필요해요')),
      );
      return;
    }
    _centerOnNextFix = true;
    _listenLocation();
  }

  void _moveTo(LocationSample p) => _map.move(
    toLatLngFromSample(p),
    _map.camera.zoom < 14 ? 15 : _map.camera.zoom,
  );

  /// 코스를 누르거나 검색에서 고르면: 지도를 그 코스로 옮기고 코스 상세를 연다.
  /// 상세에서 뒤로 오면 그 코스가 강조된 지도가 보인다.
  void _selectCourse(Course course) {
    _searchFocus.unfocus();
    _search.clear();
    setState(() => _selectedId = course.id);
    _map.fitCamera(
      CameraFit.coordinates(
        coordinates: [for (final p in course.path) toLatLng(p)],
        padding: const EdgeInsets.fromLTRB(48, 200, 48, 120),
      ),
    );
    context.push(AppRoutes.course(course.id));
  }

  Future<void> _start() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await startRecording(context, ref);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final courses = ref.watch(coursesProvider).value ?? const <Course>[];
    final results = searchCourses(courses, _search.text);
    final conquerors = {
      for (final c
          in ref.watch(conquerorsProvider).value ?? const <Conqueror>[])
        if (c.kind == _conquerorKind) c.courseId: c,
    };

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: CourseMap(
              controller: _map,
              courses: courses,
              selectedCourseId: _selectedId,
              myLocation: _myLocation,
              conquerors: conquerors,
              onCourseTap: _selectCourse,
              onMapTap: () {
                _searchFocus.unfocus();
                setState(() => _selectedId = null);
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenHorizontal,
                AppSpacing.md,
                AppSpacing.screenHorizontal,
                0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SearchField(controller: _search, focusNode: _searchFocus),
                  if (_search.text.trim().isNotEmpty)
                    _SearchResults(results: results, onTap: _selectCourse)
                  else ...[
                    const SizedBox(height: AppSpacing.sm),
                    // 지도에 보일 정복자 기준 (기본값: 참여 폭이 넓은 최다완등)
                    SizedBox(
                      width: 220,
                      child: SegmentedTabs<RankingKind>(
                        options: const {
                          RankingKind.most: '최다완등',
                          RankingKind.fastest: '최단시간',
                        },
                        selected: _conquerorKind,
                        onChanged: (v) => setState(() => _conquerorKind = v),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          Positioned(
            right: AppSpacing.screenHorizontal,
            bottom: AppSpacing.lg,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _RoundButton(
                  icon: Icons.my_location_rounded,
                  semanticLabel: '내 위치',
                  onPressed: _onMyLocation,
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomActionBar(
        child: AppButton(label: '등산 기록 시작', onPressed: _busy ? null : _start),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.focusNode});

  final TextEditingController controller;
  final FocusNode focusNode;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      style: AppTypography.body,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: '산, 코스 이름으로 검색',
        hintStyle: AppTypography.body.copyWith(color: AppColors.textTertiary),
        prefixIcon: const Icon(
          Icons.search_rounded,
          color: AppColors.textTertiary,
        ),
        fillColor: AppColors.background,
        // 지도 위에서도 검색창이 구분되도록 얇은 테두리를 둔다.
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.input),
          borderSide: const BorderSide(color: AppColors.divider),
        ),
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(
                icon: const Icon(Icons.close_rounded),
                color: AppColors.textTertiary,
                onPressed: controller.clear,
              ),
      ),
    );
  }
}

class _SearchResults extends StatelessWidget {
  const _SearchResults({required this.results, required this.onTap});

  final List<Course> results;
  final ValueChanged<Course> onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: AppSpacing.sm),
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(AppRadius.input),
        border: Border.all(color: AppColors.divider),
      ),
      child: results.isEmpty
          ? const Padding(
              padding: EdgeInsets.all(AppSpacing.lg),
              child: Text('찾는 코스가 없어요', style: AppTypography.caption),
            )
          : Column(
              children: [
                for (final c in results)
                  Pressable(
                    onPressed: () => onTap(c),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                        vertical: AppSpacing.md,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(c.fullName, style: AppTypography.body),
                                Text(
                                  '${c.startName} → ${c.endName}',
                                  style: AppTypography.caption,
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '${formatKm(c.distanceM)} km',
                            style: AppTypography.caption,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.icon,
    required this.semanticLabel,
    required this.onPressed,
  });

  final IconData icon;
  final String semanticLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onPressed: onPressed,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: AppColors.background,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.divider),
        ),
        child: Icon(
          icon,
          color: AppColors.textPrimary,
          semanticLabel: semanticLabel,
        ),
      ),
    );
  }
}
