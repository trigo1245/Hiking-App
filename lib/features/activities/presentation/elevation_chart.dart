import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/design/design.dart';
import '../domain/activity_analysis.dart';

/// "1:05"처럼 시:분으로 보여 준다.
String formatHourMinute(Duration d) =>
    '${d.inHours}:${(d.inMinutes % 60).toString().padLeft(2, '0')}';

/// 고도 그래프 (가로: 지난 시간, 세로: 고도).
/// 휴식 구간은 초록, 위험 구간(급경사)은 빨강으로 선과 선 아래 채색을 함께 바꾼다.
/// 손가락으로 누르거나 끌면 그 시각의 고도와 구간 종류를 보여 준다.
class ElevationChart extends StatefulWidget {
  const ElevationChart({
    super.key,
    required this.samples,
    required this.total,
    this.rests = const [],
    this.dangers = const [],
    this.height = 180,
  });

  final List<ElevationSample> samples;

  /// 가로축 전체 길이 (기록 시작 ~ 끝)
  final Duration total;
  final List<TimeRange> rests;
  final List<TimeRange> dangers;
  final double height;

  @override
  State<ElevationChart> createState() => _ElevationChartState();
}

class _ElevationChartState extends State<ElevationChart> {
  /// 손가락이 가리키는 점 (없으면 null)
  int? _active;

  void _pick(double dx, double width) {
    final s = widget.samples;
    final total = widget.total.inMilliseconds;
    if (total <= 0) return;
    final target = (dx / width).clamp(0.0, 1.0) * total;
    var best = 0;
    for (var i = 1; i < s.length; i++) {
      if ((s[i].elapsed.inMilliseconds - target).abs() <
          (s[best].elapsed.inMilliseconds - target).abs()) {
        best = i;
      }
    }
    setState(() => _active = best);
  }

  String _tag(Duration t) {
    if (widget.rests.any((r) => r.contains(t))) return ' · 휴식';
    if (widget.dangers.any((r) => r.contains(t))) return ' · 위험 구간';
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.samples;
    if (s.length < 2 || widget.total <= Duration.zero) {
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
              : '${formatHourMinute(active.elapsed)} · '
                    '${active.altitudeM.round()} m${_tag(active.elapsed)}',
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
                painter: _ElevationPainter(
                  samples: s,
                  total: widget.total,
                  rests: widget.rests,
                  dangers: widget.dangers,
                  active: _active,
                ),
              ),
            );
          },
        ),
        const SizedBox(height: AppSpacing.xs),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('0:00', style: AppTypography.caption),
            Text(formatHourMinute(widget.total), style: AppTypography.caption),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        // 범례: 색만으로 구분하지 않도록 이름을 함께 쓴다.
        Wrap(
          spacing: AppSpacing.lg,
          children: [
            _LegendItem(
              color: AppColors.success,
              label: '휴식 ${widget.rests.length}번',
            ),
            _LegendItem(
              color: AppColors.danger,
              label: '위험 구간 ${widget.dangers.length}곳',
            ),
          ],
        ),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: AppSpacing.md,
          height: AppSpacing.md,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        Text(label, style: AppTypography.caption),
      ],
    );
  }
}

class _ElevationPainter extends CustomPainter {
  _ElevationPainter({
    required this.samples,
    required this.total,
    required this.rests,
    required this.dangers,
    required this.active,
  });

  final List<ElevationSample> samples;
  final Duration total;
  final List<TimeRange> rests;
  final List<TimeRange> dangers;
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
    const top = 8.0;
    final h = size.height - top;
    double xOf(Duration t) =>
        t.inMilliseconds / total.inMilliseconds * size.width;

    Offset at(ElevationSample s) => Offset(
      xOf(s.elapsed),
      top + (1 - (s.altitudeM - minA) / (maxA - minA)) * h,
    );

    final line = Path()..moveTo(at(samples.first).dx, at(samples.first).dy);
    for (final s in samples.skip(1)) {
      line.lineTo(at(s).dx, at(s).dy);
    }
    final area = Path.from(line)
      ..lineTo(at(samples.last).dx, size.height)
      ..lineTo(at(samples.first).dx, size.height)
      ..close();
    Paint stroke(Color color) => Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeJoin = StrokeJoin.round;

    // 구간별 색: 위험(빨강) 위에 휴식(초록)을 칠해, 겹치면 휴식이 보이게 한다.
    final sections = [
      for (final d in dangers) (d, AppColors.danger),
      for (final r in rests) (r, AppColors.success),
    ];
    Rect clipOf(TimeRange r) => Rect.fromLTRB(
      xOf(r.start),
      0,
      math.max(xOf(r.end), xOf(r.start) + 3),
      size.height,
    );

    // 1) 선 아래 반투명 채색: 기본은 파랑, 구간은 그 구간 색
    canvas.drawPath(area, Paint()..color = _fill(AppColors.primary));
    for (final (range, color) in sections) {
      canvas
        ..save()
        ..clipRect(clipOf(range))
        // 파란 채색을 지우고 구간 색으로 다시 칠한다.
        ..drawPath(area, Paint()..color = AppColors.background)
        ..drawPath(area, Paint()..color = _fill(color))
        ..restore();
    }

    // 2) 흐린 가로 기준선 3개
    final grid = Paint()
      ..color = AppColors.divider
      ..strokeWidth = 1;
    for (var i = 0; i <= 2; i++) {
      final y = top + h * i / 2;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    // 3) 선: 기본은 파랑, 구간은 그 시간 범위만 잘라 구간 색으로 덧그린다.
    canvas.drawPath(line, stroke(AppColors.primary));
    for (final (range, color) in sections) {
      canvas
        ..save()
        ..clipRect(clipOf(range))
        ..drawPath(line, stroke(color)..strokeWidth = 3)
        ..restore();
    }

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
      canvas.drawCircle(p, 4, Paint()..color = _colorAt(samples[i].elapsed));
    }
  }

  /// 선 아래 반투명 채색
  static Color _fill(Color color) => color.withValues(alpha: 0.14);

  /// 그 시각이 속한 구간의 색 (휴식 > 위험 > 기본)
  Color _colorAt(Duration t) {
    if (rests.any((r) => r.contains(t))) return AppColors.success;
    if (dangers.any((r) => r.contains(t))) return AppColors.danger;
    return AppColors.primary;
  }

  @override
  bool shouldRepaint(_ElevationPainter old) =>
      old.samples != samples || old.active != active;
}
