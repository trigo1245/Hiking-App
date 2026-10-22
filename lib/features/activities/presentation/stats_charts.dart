import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/design/design.dart';
import '../domain/hiking_stats.dart';

/// 최근 6개월 월별 등산 횟수. 한 가지 색 막대, 막대 위에 횟수.
class MonthlyBarChart extends StatelessWidget {
  const MonthlyBarChart({super.key, required this.months, this.height = 120});

  final List<MonthCount> months;
  final double height;

  @override
  Widget build(BuildContext context) {
    final most = math.max(1, months.map((m) => m.count).reduce(math.max));
    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final m in months)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      '${m.count}',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    // 0회도 바닥선이 보이도록 최소 2px
                    Container(
                      height: math.max(2, (height - 48) * m.count / most),
                      decoration: BoxDecoration(
                        color: m.count == 0
                            ? AppColors.divider
                            : AppColors.primary,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(4),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text('${m.month}월', style: AppTypography.caption),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 산행마다 값이 어떻게 바뀌었는지 보여 주는 꺾은선 (예: 표준 대비 내 속도).
/// [reference] 높이에 흐린 점선(예: 표준 100%)을 긋는다. 누르면 그 산행의 날짜와 값을 보여 준다.
class TrendLineChart extends StatefulWidget {
  const TrendLineChart({
    super.key,
    required this.points,
    required this.format,
    this.reference,
    this.referenceLabel,
    this.height = 140,
  });

  final List<({DateTime date, double value})> points;
  final String Function(double value) format;
  final double? reference;
  final String? referenceLabel;
  final double height;

  @override
  State<TrendLineChart> createState() => _TrendLineChartState();
}

class _TrendLineChartState extends State<TrendLineChart> {
  int? _active;

  void _pick(double dx, double width) {
    final n = widget.points.length;
    if (n == 0) return;
    final i = n == 1 ? 0 : (dx / width * (n - 1)).round().clamp(0, n - 1);
    setState(() => _active = i);
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.points;
    final shown = _active == null ? p.last : p[_active!];
    String date(DateTime d) => '${d.month}월 ${d.day}일';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${_active == null ? '최근 · ' : ''}${date(shown.date)} · '
          '${widget.format(shown.value)}',
          style: AppTypography.body.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.sm),
        LayoutBuilder(
          builder: (context, c) => GestureDetector(
            onTapDown: (d) => _pick(d.localPosition.dx, c.maxWidth),
            onHorizontalDragStart: (d) => _pick(d.localPosition.dx, c.maxWidth),
            onHorizontalDragUpdate: (d) =>
                _pick(d.localPosition.dx, c.maxWidth),
            onHorizontalDragEnd: (_) => setState(() => _active = null),
            onTapUp: (_) => setState(() => _active = null),
            child: CustomPaint(
              size: Size(c.maxWidth, widget.height),
              painter: _TrendPainter(p, widget.reference, _active),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(date(p.first.date), style: AppTypography.caption),
            if (widget.referenceLabel case final label?)
              Text('점선 = $label', style: AppTypography.caption),
            Text(date(p.last.date), style: AppTypography.caption),
          ],
        ),
      ],
    );
  }
}

class _TrendPainter extends CustomPainter {
  _TrendPainter(this.points, this.reference, this.active);

  final List<({DateTime date, double value})> points;
  final double? reference;
  final int? active;

  @override
  void paint(Canvas canvas, Size size) {
    final values = [...points.map((p) => p.value), ?reference];
    var lo = values.reduce(math.min);
    var hi = values.reduce(math.max);
    final pad = math.max((hi - lo) * 0.15, 0.05);
    lo -= pad;
    hi += pad;
    const inset = 8.0; // 양 끝 점이 잘리지 않게
    final w = size.width - inset * 2;
    double y(double v) => (1 - (v - lo) / (hi - lo)) * size.height;
    Offset at(int i) => Offset(
      inset + (points.length == 1 ? w / 2 : w * i / (points.length - 1)),
      y(points[i].value),
    );

    if (reference case final r?) {
      final paint = Paint()
        ..color = AppColors.textTertiary
        ..strokeWidth = 1;
      for (var x = 0.0; x < size.width; x += 8) {
        canvas.drawLine(
          Offset(x, y(r)),
          Offset(math.min(x + 4, size.width), y(r)),
          paint,
        );
      }
    }

    final line = Path()..moveTo(at(0).dx, at(0).dy);
    for (var i = 1; i < points.length; i++) {
      line.lineTo(at(i).dx, at(i).dy);
    }
    canvas.drawPath(
      line,
      Paint()
        ..color = AppColors.primary
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round,
    );
    for (var i = 0; i < points.length; i++) {
      final selected =
          i == active || (active == null && i == points.length - 1);
      // 2px 배경 테두리로 선 위에서도 점이 보이게 한다.
      canvas.drawCircle(
        at(i),
        selected ? 7 : 6,
        Paint()..color = AppColors.background,
      );
      canvas.drawCircle(
        at(i),
        selected ? 5 : 4,
        Paint()..color = AppColors.primary,
      );
    }
  }

  @override
  bool shouldRepaint(_TrendPainter old) =>
      old.points != points || old.active != active;
}
