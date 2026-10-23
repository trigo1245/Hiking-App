import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/design/design.dart';
import '../../../core/map/map_tiles.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../recording/domain/track_point.dart';
import '../domain/competition.dart';
import '../domain/course.dart';

/// 처음 지도를 열었을 때의 위치 (부산)
const busanCenter = LatLng(35.17, 129.03);

LatLng toLatLng(GeoPoint p) => LatLng(p.lat, p.lon);
LatLng toLatLngFromSample(LocationSample s) => LatLng(s.latitude, s.longitude);

/// 코스 선, 들머리·정상 표시, 내 위치를 그리는 지도.
/// 코스 선과 내 위치는 기기에 있는 데이터라 인터넷이 없어도 보인다.
class CourseMap extends ConsumerStatefulWidget {
  const CourseMap({
    super.key,
    required this.controller,
    required this.courses,
    required this.selectedCourseId,
    required this.onCourseTap,
    required this.onMapTap,
    this.myLocation,
    this.conquerors = const {},
  });

  /// 코스 ID → 그 코스의 정복자 (지도에 프로필 사진으로 표시)
  final Map<String, Conqueror> conquerors;

  final MapController controller;
  final List<Course> courses;
  final String? selectedCourseId;
  final ValueChanged<Course> onCourseTap;
  final VoidCallback onMapTap;
  final LocationSample? myLocation;

  @override
  ConsumerState<CourseMap> createState() => _CourseMapState();
}

/// 코스 표시(정상 이름표, 들머리 점, 정복자 사진)를 보여 주는 확대 범위.
/// - 이보다 멀리(부산 전체 정도)서는 표시끼리 겹쳐서 선만 보여 준다.
/// - 이보다 가까이(한 코스를 크게 볼 때)는 표시가 길과 내 위치를 가려서 선만 보여 준다.
/// 선택한 코스는 확대 정도와 관계없이 표시한다.
const courseMarkerMinZoom = 12.5;
const courseMarkerMaxZoom = 15.0;

bool showCourseMarkersAt(double zoom) =>
    zoom >= courseMarkerMinZoom && zoom <= courseMarkerMaxZoom;

class _CourseMapState extends ConsumerState<CourseMap> {
  final _hitNotifier = LayerHitNotifier<String>(null);

  /// 지금 확대 정도에서 코스 표시를 보여 줄지 (지도를 움직일 때마다 갱신)
  bool _showMarkers = showCourseMarkersAt(11);

  void _onCameraChanged(MapCamera camera) {
    final show = showCourseMarkersAt(camera.zoom);
    if (show != _showMarkers) setState(() => _showMarkers = show);
  }

  @override
  void dispose() {
    _hitNotifier.dispose();
    super.dispose();
  }

  void _onLineTap() {
    final id = _hitNotifier.value?.hitValues.firstOrNull;
    if (id == null) return;
    final course = widget.courses.where((c) => c.id == id).firstOrNull;
    if (course != null) widget.onCourseTap(course);
  }

  @override
  Widget build(BuildContext context) {
    final selected = widget.selectedCourseId;
    // 선택한 코스를 맨 위에 그리도록 마지막에 둔다.
    final ordered = [
      ...widget.courses.where((c) => c.id != selected),
      ...widget.courses.where((c) => c.id == selected),
    ];
    // 표시를 그릴 코스: 알맞은 확대 범위면 전부, 아니면 선택한 코스만
    final marked = _showMarkers
        ? ordered
        : ordered.where((c) => c.id == selected).toList();
    final summits = {for (final c in marked) c.mountainName: c.summit};
    final me = widget.myLocation;

    return FlutterMap(
      mapController: widget.controller,
      options: MapOptions(
        initialCenter: busanCenter,
        initialZoom: 11,
        minZoom: 6,
        maxZoom: 18,
        onTap: (_, _) => widget.onMapTap(),
        onPositionChanged: (camera, _) => _onCameraChanged(camera),
      ),
      children: [
        if (ref.watch(mapTilesEnabledProvider))
          TileLayer(
            urlTemplate: osmTileUrl,
            userAgentPackageName: mapUserAgentPackageName,
          ),
        GestureDetector(
          onTap: _onLineTap,
          child: PolylineLayer<String>(
            hitNotifier: _hitNotifier,
            minimumHitbox: 16,
            polylines: [
              for (final c in ordered)
                Polyline<String>(
                  points: [for (final p in c.path) toLatLng(p)],
                  hitValue: c.id,
                  strokeWidth: c.id == selected ? 6 : 4,
                  color: c.id == selected
                      ? AppColors.primary
                      : AppColors.success,
                  borderStrokeWidth: 2,
                  borderColor: AppColors.background,
                ),
            ],
          ),
        ),
        // rotate: 지도를 돌려도 표시(이름표·사진·점)는 바로 서 있게 한다.
        MarkerLayer(
          rotate: true,
          markers: [
            for (final MapEntry(key: name, value: summit) in summits.entries)
              Marker(
                point: toLatLng(summit),
                width: 120,
                height: 48,
                alignment: Alignment.topCenter,
                child: SummitLabel(name: name),
              ),
            for (final c in marked)
              Marker(
                point: toLatLng(c.start),
                width: 28,
                height: 28,
                child: GestureDetector(
                  onTap: () => widget.onCourseTap(c),
                  child: StartDot(selected: c.id == selected),
                ),
              ),
            // 정복자 프로필 사진: 코스 선의 가운데에 둔다 (기획서 4.3)
            for (final c in marked)
              if (widget.conquerors[c.id] case final conqueror?)
                Marker(
                  point: toLatLng(c.path[c.path.length ~/ 2]),
                  width: 40,
                  height: 40,
                  child: GestureDetector(
                    onTap: () => widget.onCourseTap(c),
                    child: UserAvatar(
                      nickname: conqueror.nickname,
                      imageUrl: conqueror.avatarUrl,
                      size: 40,
                      borderColor: c.id == selected
                          ? AppColors.primary
                          : AppColors.background,
                    ),
                  ),
                ),
          ],
        ),
        if (me != null) ...[
          CircleLayer(
            circles: [
              CircleMarker(
                point: LatLng(me.latitude, me.longitude),
                radius: me.accuracy,
                useRadiusInMeter: true,
                color: AppColors.primary.withValues(alpha: 0.12),
              ),
            ],
          ),
          MarkerLayer(
            rotate: true,
            markers: [
              Marker(
                point: LatLng(me.latitude, me.longitude),
                width: 22,
                height: 22,
                child: const MyLocationDot(),
              ),
            ],
          ),
        ],
        // 출처 표시: 화면이 좁거나 글자가 커도 넘치지 않게 줄바꿈한다.
        Align(
          alignment: Alignment.bottomLeft,
          child: Container(
            margin: const EdgeInsets.all(AppSpacing.xs),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xs,
              vertical: 2,
            ),
            color: AppColors.background.withValues(alpha: 0.8),
            child: const Text(mapAttribution, style: AppTypography.caption),
          ),
        ),
      ],
    );
  }
}

class SummitLabel extends StatelessWidget {
  const SummitLabel({super.key, required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(AppSpacing.sm),
          ),
          child: Text(
            '▲ $name',
            style: AppTypography.caption.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class StartDot extends StatelessWidget {
  const StartDot({super.key, required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: selected ? 18 : 14,
        height: selected ? 18 : 14,
        decoration: BoxDecoration(
          color: AppColors.background,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.success,
            width: 4,
          ),
        ),
      ),
    );
  }
}

class MyLocationDot extends StatelessWidget {
  const MyLocationDot({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.primary,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.background, width: 3),
      ),
    );
  }
}
