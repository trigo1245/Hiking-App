import 'package:flutter/widgets.dart';

import '../../../core/design/design.dart';

/// 동호회 채팅 아이콘: 왼쪽 아래 꼬리가 달린 둥근 말풍선과 점 3개.
/// 그림 파일 없이 코드로 그린다 (배지와 같은 방식).
class ChatBubbleIcon extends StatelessWidget {
  const ChatBubbleIcon({super.key, this.size = 30});

  final double size;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size.square(size), painter: const _ChatBubblePainter());
}

class _ChatBubblePainter extends CustomPainter {
  const _ChatBubblePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    // 원본 그림(1200×1200) 비율 그대로: 타원 중심 (600, 600), 반지름 525×437
    final oval = Rect.fromCenter(
      center: Offset(s * 0.5, s * 0.5),
      width: s * 0.875,
      height: s * 0.73,
    );
    final tail = Path()
      ..moveTo(s * 0.175, s * 0.74)
      ..lineTo(s * 0.13, s * 0.85)
      ..quadraticBezierTo(s * 0.12, s * 0.9, s * 0.16, s * 0.885)
      ..lineTo(s * 0.33, s * 0.83)
      ..close();
    final bubble = Path.combine(
      PathOperation.union,
      Path()..addOval(oval),
      tail,
    );
    canvas.drawPath(
      bubble,
      Paint()
        ..shader = const RadialGradient(
          colors: [
            AppColors.chatBubbleCenter,
            AppColors.chatBubbleCenter,
            AppColors.chatBubbleEdge,
          ],
          stops: [0, 0.55, 1],
        ).createShader(oval),
    );

    final r = s * 0.042;
    final dots = Rect.fromLTRB(0, s * 0.5 - r, s, s * 0.5 + r);
    final dotPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [AppColors.chatDotTop, AppColors.chatDotBottom],
      ).createShader(dots);
    for (final x in [0.333, 0.5, 0.667]) {
      canvas.drawCircle(Offset(s * x, s * 0.5), r, dotPaint);
    }
  }

  @override
  bool shouldRepaint(_ChatBubblePainter oldDelegate) => false;
}
