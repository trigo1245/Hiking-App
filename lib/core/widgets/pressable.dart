import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../design/design.dart';

/// 누르는 동안 살짝 작아지고(scale 0.97), 손을 떼면 가벼운 햅틱을 주는 터치 영역.
/// 물결(ripple) 효과 대신 이 위젯을 쓴다.
class Pressable extends StatefulWidget {
  const Pressable({super.key, required this.onPressed, required this.child});

  /// null이면 눌리지 않는다.
  final VoidCallback? onPressed;
  final Widget child;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    return Semantics(
      button: true,
      enabled: enabled,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: enabled ? (_) => _setPressed(true) : null,
        onTapCancel: enabled ? () => _setPressed(false) : null,
        onTapUp: enabled ? (_) => _setPressed(false) : null,
        onTap: enabled
            ? () {
                HapticFeedback.lightImpact();
                widget.onPressed!();
              }
            : null,
        child: AnimatedScale(
          scale: _pressed ? AppSizes.pressedScale : 1,
          duration: const Duration(milliseconds: 100),
          child: widget.child,
        ),
      ),
    );
  }
}
