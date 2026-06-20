import 'package:flutter/material.dart';

/// Kichik ikonka, lekin bosish maydoni kattaroq — vizual o‘lcham o‘zgarmaydi.
class QuickTap extends StatelessWidget {
  const QuickTap({
    super.key,
    required this.onTap,
    required this.child,
    this.enabled = true,
    this.minSize = 44,
    this.splashColor,
    this.highlightColor,
  });

  final VoidCallback? onTap;
  final Widget child;
  final bool enabled;
  final double minSize;
  final Color? splashColor;
  final Color? highlightColor;

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(10),
        splashColor: splashColor ?? Colors.black.withValues(alpha: 0.06),
        highlightColor: highlightColor ?? Colors.black.withValues(alpha: 0.04),
        child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: minSize, minHeight: minSize),
          child: Center(child: child),
        ),
      ),
    );
  }
}
