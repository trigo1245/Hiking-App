import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/design/design.dart';
import '../../../core/map/map_tiles.dart';
import '../../recording/domain/track_point.dart';
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
  });

  final MapController controller;
  final List<Course> courses;
  final String? selectedCourseId;
  final ValueChanged<Course> onCourseTap;
  final VoidCallback onMapTap;
  final LocationSample? myLocation;

  @override
  ConsumerState<CourseMap> createState() => _CourseMapState();
}

class _CourseMapState extends ConsumerState<CourseMap> {
  final _hitNotifier = LayerHitNotifier<String>(null);

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
    final summits = {for (final c in widget.courses) c.mountainName: c.summit};
    final me = widget.myLocation;

    return FlutterMap(
      mapController: widget.controller,
      options: MapOptions(
        initialCenter: busanCenter,
        initialZoom: 11,
        minZoom: 6,
        maxZoom: 18,
        onTap: (_, _) => widget.onMapTap(),
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
        MarkerLayer(
          markers: [
            for (final MapEntry(key: name, value: summit) in summits.entries)
              Marker(
                point: toLatLng(summit),
                width: 120,
                height: 48,
                alignment: Alignment.topCenter,
                child: _SummitLabel(name: name),
              ),
            for (final c in ordered)
              Marker(
                point: toLatLng(c.start),
                width: 28,
                height: 28,
                child: GestureDetector(
                  onTap: () => widget.onCourseTap(c),
                  child: _StartDot(selected: c.id == selected),
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
            markers: [
              Marker(
                point: LatLng(me.latitude, me.longitude),
                width: 22,
                height: 22,
                child: const _MyLocationDot(),
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

class _SummitLabel extends StatelessWidget {
  const _SummitLabel({required this.name});

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

class _StartDot extends StatelessWidget {
  const _StartDot({required this.selected});

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

class _MyLocationDot extends StatelessWidget {
  const _MyLocationDot();

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
