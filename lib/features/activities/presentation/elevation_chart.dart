import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/design/design.dart';
import '../domain/activity_analysis.dart';

/// 고도 그래프 (가로: 걸은 거리, 세로: 고도). 한 줄짜리라 범례는 두지 않는다.
/// 손가락으로 누르거나 끌면 그 지점의 거리와 고도를 보여 준다.
class ElevationChart extends StatefulWidget {
  const ElevationChart({super.key, required this.samples, this.height = 180});

  final List<ElevationSample> samples;
  final double height;

  @override
  State<ElevationChart> createState() => _ElevationChartState();
}

class _ElevationChartState extends State<ElevationChart> {
  /// 손가락이 가리키는 점 (없으면 null)
  int? _active;

  void _pick(double dx, double width) {
    final s = widget.samples;
    final maxD = s.last.distanceM;
    if (maxD <= 0) return;
    final target = (dx / width).clamp(0.0, 1.0) * maxD;
    var best = 0;
    for (var i = 1; i < s.length; i++) {
      if ((s[i].distanceM - target).abs() <
          (s[best].distanceM - target).abs()) {
        best = i;
      }
    }
    setState(() => _active = best);
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.samples;
    if (s.length < 2) {
      return SizedBox(
        height: widget.height,
        child: const Center(
          child: Text('고도 정보가 없는 기록이에요', style: AppTypography.caption),
        ),
      );
    }
    final active = _active == null ? null : s[_active!];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 누른 지점의 값 (누르지 않았으면 최고 고도)
        Text(
          active == null
              ? '최고 ${s.map((e) => e.altitudeM).reduce(math.max).round()} m'
              : '${(active.distanceM / 1000).toStringAsFixed(2)} km · '
                    '${active.altitudeM.round()} m',
          style: AppTypography.body.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.sm),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            return GestureDetector(
              onTapDown: (d) => _pick(d.localPosition.dx, width),
              onHorizontalDragStart: (d) => _pick(d.localPosition.dx, width),
              onHorizontalDragUpdate: (d) => _pick(d.localPosition.dx, width),
              onHorizontalDragEnd: (_) => setState(() => _active = null),
              onTapUp: (_) => setState(() => _active = null),
              child: CustomPaint(
                size: Size(width, widget.height),
                painter: _ElevationPainter(s, _active),
              ),
            );
          },
        ),
        const SizedBox(height: AppSpacing.xs),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('0 km', style: AppTypography.caption),
            Text(
              '${(s.last.distanceM / 1000).toStringAsFixed(1)} km',
              style: AppTypography.caption,
            ),
          ],
        ),
      ],
    );
  }
}

class _ElevationPainter extends CustomPainter {
  _ElevationPainter(this.samples, this.active);

  final List<ElevationSample> samples;
  final int? active;

  @override
  void paint(Canvas canvas, Size size) {
    final alts = samples.map((e) => e.altitudeM);
    var minA = alts.reduce(math.min);
    var maxA = alts.reduce(math.max);
    // 높이 차가 작아도 그래프가 너무 출렁이지 않게 최소 50m 폭을 둔다.
    if (maxA - minA < 50) {
      final mid = (maxA + minA) / 2;
      minA = mid - 25;
      maxA = mid + 25;
    }
    final maxD = samples.last.distanceM;
    const top = 8.0;
    final h = size.height - top;

    Offset at(ElevationSample s) => Offset(
      maxD == 0 ? 0 : s.distanceM / maxD * size.width,
      top + (1 - (s.altitudeM - minA) / (maxA - minA)) * h,
    );

    // 흐린 가로 기준선 3개
    final grid = Paint()
      ..color = AppColors.divider
      ..strokeWidth = 1;
    for (var i = 0; i <= 2; i++) {
      final y = top + h * i / 2;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    final line = Path()..moveTo(at(samples.first).dx, at(samples.first).dy);
    for (final s in samples.skip(1)) {
      line.lineTo(at(s).dx, at(s).dy);
    }
    final area = Path.from(line)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(
      area,
      Paint()..color = AppColors.primary.withValues(alpha: 0.12),
    );
    canvas.drawPath(
      line,
      Paint()
        ..color = AppColors.primary
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round,
    );

    if (active case final i?) {
      final p = at(samples[i]);
      canvas.drawLine(
        Offset(p.dx, 0),
        Offset(p.dx, size.height),
        Paint()
          ..color = AppColors.textTertiary
          ..strokeWidth = 1,
      );
      // 점 둘레에 배경색 테두리를 둘러 선 위에서도 보이게 한다.
      canvas.drawCircle(p, 6, Paint()..color = AppColors.background);
      canvas.drawCircle(p, 4, Paint()..color = AppColors.primary);
    }
  }

  @override
  bool shouldRepaint(_ElevationPainter old) =>
      old.samples != samples || old.active != active;
}
