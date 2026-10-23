import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/design/design.dart';
import '../../../core/map/map_tiles.dart';
import '../../../core/widgets/pressable.dart';
import '../../courses/data/course_repository.dart';
import '../../courses/domain/course.dart';
import '../../courses/presentation/course_map.dart';
import '../domain/track_point.dart';

/// 기록 중 지도: 내 위치, 지금까지 걸은 경로, 등록된 코스 선.
/// 코스와 경로는 기기에 있는 데이터라 인터넷이 없어도 보인다(배경 지도는 한 번 본 곳만).
/// 처음에는 내 위치를 따라가고, 손으로 지도를 움직이면 따라가기를 멈춘다.
class RecordingMap extends ConsumerStatefulWidget {
  const RecordingMap({super.key, required this.track, this.position});

  final List<LatLng> track;
  final LocationSample? position;

  @override
  ConsumerState<RecordingMap> createState() => _RecordingMapState();
}

class _RecordingMapState extends ConsumerState<RecordingMap> {
  /// 기록 중에 보기 좋은 확대 정도 (길과 주변 지형이 함께 보인다)
  static const _followZoom = 16.0;

  final _controller = MapController();
  bool _follow = true;
  bool _ready = false;

  LatLng? get _me => switch (widget.position) {
    final p? => LatLng(p.latitude, p.longitude),
    null => widget.track.lastOrNull,
  };

  @override
  void didUpdateWidget(RecordingMap old) {
    super.didUpdateWidget(old);
    final me = _me;
    if (_follow && _ready && me != null && widget.position != old.position) {
      _controller.move(me, _controller.camera.zoom);
    }
  }

  void _followMe() {
    setState(() => _follow = true);
    if (_me case final me?) _controller.move(me, _followZoom);
  }

  @override
  Widget build(BuildContext context) {
    final courses = ref.watch(coursesProvider).value ?? const <Course>[];
    final me = _me;
    final accuracy = widget.position?.accuracy;

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: Stack(
        children: [
          FlutterMap(
            mapController: _controller,
            options: MapOptions(
              initialCenter: me ?? busanCenter,
              initialZoom: me == null ? 11 : _followZoom,
              minZoom: 6,
              maxZoom: 18,
              onMapReady: () => _ready = true,
              onPositionChanged: (_, hasGesture) {
                // 손으로 움직이면 따라가기를 멈춘다. (내 위치 버튼으로 다시 켠다)
                if (hasGesture && _follow) setState(() => _follow = false);
              },
            ),
            children: [
              if (ref.watch(mapTilesEnabledProvider))
                TileLayer(
                  urlTemplate: osmTileUrl,
                  userAgentPackageName: mapUserAgentPackageName,
                ),
              PolylineLayer(
                polylines: [
                  for (final c in courses)
                    Polyline(
                      points: [for (final p in c.path) toLatLng(p)],
                      strokeWidth: 4,
                      color: AppColors.success.withValues(alpha: 0.7),
                    ),
                  if (widget.track.length >= 2)
                    Polyline(
                      points: widget.track,
                      strokeWidth: 5,
                      color: AppColors.primary,
                      borderStrokeWidth: 2,
                      borderColor: AppColors.background,
                    ),
                ],
              ),
              if (me != null) ...[
                if (accuracy != null)
                  CircleLayer(
                    circles: [
                      CircleMarker(
                        point: me,
                        radius: accuracy,
                        useRadiusInMeter: true,
                        color: AppColors.primary.withValues(alpha: 0.12),
                      ),
                    ],
                  ),
                MarkerLayer(
                  rotate: true,
                  markers: [
                    Marker(
                      point: me,
                      width: 22,
                      height: 22,
                      child: const MyLocationDot(),
                    ),
                  ],
                ),
              ],
              Align(
                alignment: Alignment.bottomLeft,
                child: Container(
                  margin: const EdgeInsets.all(AppSpacing.xs),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xs,
                    vertical: 2,
                  ),
                  color: AppColors.background.withValues(alpha: 0.8),
                  child: const Text(
                    mapAttribution,
                    style: AppTypography.caption,
                  ),
                ),
              ),
            ],
          ),
          if (!_follow && me != null)
            Positioned(
              right: AppSpacing.md,
              top: AppSpacing.md,
              child: Pressable(
                onPressed: _followMe,
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: const BoxDecoration(
                    color: AppColors.background,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.my_location_rounded,
                    color: AppColors.primary,
                    semanticLabel: '내 위치 따라가기',
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
