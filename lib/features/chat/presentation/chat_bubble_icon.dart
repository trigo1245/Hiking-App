import 'package:flutter/widgets.dart';

import '../../../core/design/design.dart';

/// 동호회 채팅 아이콘: 왼쪽 아래 꼬리가 달린 둥근 말풍선 테두리와 그 안의 점 3개.
/// 상단 줄의 다른 아이콘과 같은 색·굵기의 선 아이콘으로, 그림 파일 없이 코드로 그린다.
class ChatBubbleIcon extends StatelessWidget {
  const ChatBubbleIcon({super.key, this.size = 24});

  final double size;

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: Size.square(size),
    painter: _ChatBubblePainter(
      IconTheme.of(context).color ?? AppColors.textPrimary,
    ),
  );
}

class _ChatBubblePainter extends CustomPainter {
  const _ChatBubblePainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    // 둥근 말풍선: 가로로 조금 긴 타원 + 왼쪽 아래 꼬리
    final oval = Rect.fromCenter(
      center: Offset(s * 0.5, s * 0.46),
      width: s * 0.84,
      height: s * 0.7,
    );
    final tail = Path()
      ..moveTo(s * 0.2, s * 0.68)
      ..lineTo(s * 0.13, s * 0.88)
      ..lineTo(s * 0.38, s * 0.79)
      ..close();
    final bubble = Path.combine(
      PathOperation.union,
      Path()..addOval(oval),
      tail,
    );
    canvas.drawPath(
      bubble,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.08
        ..strokeJoin = StrokeJoin.round,
    );

    final dot = Paint()..color = color;
    for (final x in [0.32, 0.5, 0.68]) {
      canvas.drawCircle(Offset(s * x, s * 0.46), s * 0.055, dot);
    }
  }

  @override
  bool shouldRepaint(_ChatBubblePainter oldDelegate) =>
      oldDelegate.color != color;
}
