import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/design/design.dart';
import '../domain/achievements.dart';

/// 배지 하나를 그린다. 그림 파일 없이 테두리 모양을 직접 그리고 가운데에 아이콘을 얹는다.
/// [tier]가 null이면 아직 얻지 못한 배지(회색).
class BadgeMedal extends StatelessWidget {
  const BadgeMedal({
    super.key,
    required BadgeDef this.def,
    required this.tier,
    this.size = 56,
  }) : season = false;

  /// 시즌 정복 배지: 모두 같은 보석 모양, 백금 바탕에 프리즘 빛깔 (움직이지 않는다)
  const BadgeMedal.season({super.key, this.size = 56})
    : def = null,
      tier = null,
      season = true;

  final BadgeDef? def;
  final BadgeTier? tier;
  final double size;
  final bool season;

  @override
  Widget build(BuildContext context) {
    final shape = def?.shape;
    final locked = !season && tier == null;
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _MedalPainter(
          path: season ? _gem : _pathOf(shape!),
          color: season
              ? AppColors.badgePlatinum
              : locked
              ? AppColors.badgeLocked
              : tierColor(tier!),
          prism: season,
          shine: !locked,
        ),
        child: Align(
          alignment: switch (shape) {
            _ when season => const Alignment(0, -0.15),
            BadgeShape.pennant => const Alignment(0, -0.2),
            BadgeShape.crown => const Alignment(0, 0.35),
            BadgeShape.shield => const Alignment(0, -0.08),
            _ => Alignment.center,
          },
          child: Icon(
            season ? Icons.emoji_events_rounded : badgeIcon(def!),
            size: size * (shape == BadgeShape.star ? 0.32 : 0.42),
            color: season ? AppColors.textSecondary : AppColors.background,
          ),
        ),
      ),
    );
  }
}

Color tierColor(BadgeTier tier) => switch (tier) {
  BadgeTier.bronze => AppColors.badgeBronze,
  BadgeTier.silver => AppColors.badgeSilver,
  BadgeTier.gold => AppColors.badgeGold,
};

IconData badgeIcon(BadgeDef def) => switch (def.id) {
  'first_step' => Icons.directions_walk_rounded,
  'hikes' => Icons.terrain_rounded,
  'distance' => Icons.route_rounded,
  'elevation' => Icons.trending_up_rounded,
  'streak' => Icons.event_repeat_rounded,
  'dawn' => Icons.wb_twilight_rounded,
  'summits' => Icons.flag_rounded,
  'explorer' => Icons.explore_rounded,
  'regular' => Icons.favorite_rounded,
  'first_most' => Icons.military_tech_rounded,
  'first_fastest' => Icons.timer_rounded,
  'hold' => Icons.hourglass_bottom_rounded,
  'double_crown' => Icons.workspace_premium_rounded,
  'reviews' => Icons.rate_review_rounded,
  _ => Icons.star_rounded,
};

/// 모양 경로. 0~1 정사각형 좌표로 만들고 그릴 때 크기를 곱한다.
Path _pathOf(BadgeShape shape) => switch (shape) {
  BadgeShape.circle =>
    Path()..addOval(const Rect.fromLTWH(0.03, 0.03, 0.94, 0.94)),
  BadgeShape.hexagon => _polygon(6, -math.pi / 2),
  BadgeShape.roundedSquare =>
    Path()..addRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(0.06, 0.06, 0.88, 0.88),
        const Radius.circular(0.24),
      ),
    ),
  BadgeShape.pentagon => _polygon(5, -math.pi / 2),
  BadgeShape.octagon => _polygon(8, math.pi / 8),
  BadgeShape.sun => _star(12, 0.84),
  BadgeShape.shield =>
    Path()
      ..moveTo(0.5, 0.03)
      ..lineTo(0.9, 0.16)
      ..lineTo(0.9, 0.5)
      ..quadraticBezierTo(0.88, 0.82, 0.5, 0.97)
      ..quadraticBezierTo(0.12, 0.82, 0.1, 0.5)
      ..lineTo(0.1, 0.16)
      ..close(),
  BadgeShape.diamond => _polygon(4, -math.pi / 2),
  BadgeShape.seal => _star(16, 0.9),
  BadgeShape.heptagon => _polygon(7, -math.pi / 2),
  BadgeShape.star => _star(5, 0.55),
  BadgeShape.burst => _star(8, 0.74),
  BadgeShape.crown =>
    Path()
      ..moveTo(0.06, 0.26)
      ..lineTo(0.3, 0.48)
      ..lineTo(0.5, 0.12)
      ..lineTo(0.7, 0.48)
      ..lineTo(0.94, 0.26)
      ..lineTo(0.84, 0.88)
      ..lineTo(0.16, 0.88)
      ..close(),
  BadgeShape.pennant =>
    Path()
      ..moveTo(0.14, 0.04)
      ..lineTo(0.86, 0.04)
      ..lineTo(0.86, 0.96)
      ..lineTo(0.5, 0.76)
      ..lineTo(0.14, 0.96)
      ..close(),
};

/// 시즌 정복 배지 모양: 위가 평평한 보석
final _gem = Path()
  ..moveTo(0.26, 0.1)
  ..lineTo(0.74, 0.1)
  ..lineTo(0.96, 0.38)
  ..lineTo(0.5, 0.96)
  ..lineTo(0.04, 0.38)
  ..close();

Path _polygon(int sides, double rotation) {
  final path = Path();
  for (var i = 0; i < sides; i++) {
    final a = rotation + 2 * math.pi * i / sides;
    final p = Offset(0.5 + 0.47 * math.cos(a), 0.5 + 0.47 * math.sin(a));
    i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
  }
  return path..close();
}

Path _star(int points, double inner) {
  final path = Path();
  for (var i = 0; i < points * 2; i++) {
    final a = -math.pi / 2 + math.pi * i / points;
    final r = 0.48 * (i.isEven ? 1 : inner);
    final p = Offset(0.5 + r * math.cos(a), 0.5 + r * math.sin(a));
    i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
  }
  return path..close();
}

class _MedalPainter extends CustomPainter {
  _MedalPainter({
    required this.path,
    required this.color,
    required this.prism,
    required this.shine,
  });

  final Path path;
  final Color color;
  final bool prism;
  final bool shine;

  @override
  void paint(Canvas canvas, Size size) {
    final shape = path.transform(
      Matrix4.diagonal3Values(size.width, size.height, 1).storage,
    );
    final rect = Offset.zero & size;
    canvas.drawPath(shape, Paint()..color = color);

    if (prism) {
      // 무지갯빛 결: 가운데에서 도는 그라데이션 + 비스듬한 빛줄기. 움직이지 않는다.
      canvas.drawPath(
        shape,
        Paint()
          ..shader = const SweepGradient(
            colors: AppColors.badgePrism,
            transform: GradientRotation(math.pi / 5),
          ).createShader(rect),
      );
      canvas.drawPath(
        shape,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.background.withValues(alpha: 0),
              AppColors.background.withValues(alpha: 0.6),
              AppColors.background.withValues(alpha: 0),
              AppColors.background.withValues(alpha: 0.35),
              AppColors.background.withValues(alpha: 0),
            ],
            stops: const [0.2, 0.38, 0.5, 0.62, 0.78],
          ).createShader(rect),
      );
      // 보석 면 나눔선
      final facet = Paint()
        ..color = AppColors.background.withValues(alpha: 0.8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.02;
      Offset at(double x, double y) => Offset(x * size.width, y * size.height);
      canvas
        ..drawLine(at(0.04, 0.38), at(0.96, 0.38), facet)
        ..drawLine(at(0.26, 0.1), at(0.36, 0.38), facet)
        ..drawLine(at(0.74, 0.1), at(0.64, 0.38), facet)
        ..drawLine(at(0.36, 0.38), at(0.5, 0.96), facet)
        ..drawLine(at(0.64, 0.38), at(0.5, 0.96), facet);
    } else if (shine) {
      // 얻은 배지: 위쪽을 살짝 밝게
      canvas.drawPath(
        shape,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.background.withValues(alpha: 0.35),
              AppColors.background.withValues(alpha: 0),
            ],
          ).createShader(rect),
      );
    }

    canvas.drawPath(
      shape,
      Paint()
        // 시즌 배지는 밝은 바탕이라 은색 테두리로 모양을 드러낸다.
        ..color = prism
            ? AppColors.badgeSilver
            : AppColors.background.withValues(alpha: 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * (prism ? 0.025 : 0.03),
    );
  }

  @override
  bool shouldRepaint(_MedalPainter old) =>
      old.path != path ||
      old.color != color ||
      old.prism != prism ||
      old.shine != shine;
}
