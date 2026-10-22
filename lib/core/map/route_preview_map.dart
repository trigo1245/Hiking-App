import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../design/design.dart';
import 'map_tiles.dart';

/// 경로 하나를 화면에 꽉 차게 보여 주는 작은 지도 (기록 상세, 코스 상세에서 사용)
/// 경로 선과 표시(markers)는 기기에 있는 데이터라 인터넷이 없어도 보인다.
class RoutePreviewMap extends ConsumerWidget {
  const RoutePreviewMap({
    super.key,
    required this.points,
    this.markers = const [],
    this.attribution = '© OpenStreetMap contributors',
    this.height = 240,
    this.fitPadding = const EdgeInsets.all(AppSpacing.xxxl),
  });

  final List<LatLng> points;

  /// 출발점·도착점 등. 지도를 돌려도 바로 서 있도록 반대로 회전시킨다.
  final List<Marker> markers;
  final String attribution;
  final double height;

  /// 경로를 화면에 맞출 때 가장자리 여백. 큰 표시(이름표 등)가 잘리지 않게 넓힐 수 있다.
  final EdgeInsets fitPadding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: SizedBox(
        height: height,
        child: FlutterMap(
          options: MapOptions(
            initialCameraFit: CameraFit.coordinates(
              coordinates: points,
              padding: fitPadding,
            ),
          ),
          children: [
            if (ref.watch(mapTilesEnabledProvider))
              TileLayer(
                urlTemplate: osmTileUrl,
                userAgentPackageName: mapUserAgentPackageName,
              ),
            PolylineLayer(
              polylines: [
                Polyline(
                  points: points,
                  strokeWidth: 4,
                  color: AppColors.primary,
                  borderStrokeWidth: 2,
                  borderColor: AppColors.background,
                ),
              ],
            ),
            MarkerLayer(rotate: true, markers: markers),
            Align(
              alignment: Alignment.bottomLeft,
              child: Container(
                margin: const EdgeInsets.all(AppSpacing.xs),
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                color: AppColors.background.withValues(alpha: 0.8),
                child: Text(attribution, style: AppTypography.caption),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
