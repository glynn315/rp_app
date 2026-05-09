import 'package:flutter/material.dart';

/// Single source of truth for the brand logos across the app.
///
/// Renders the RP icon and Vespera logo side-by-side. [size] is the height
/// (and width) of *each* logo — the widget's total width is
/// `size * 2 + gap` plus any [padding].
class AppLogo extends StatelessWidget {
  final double size;
  final EdgeInsetsGeometry? padding;
  final BoxFit fit;
  final double gap;

  const AppLogo({
    super.key,
    this.size = 48,
    this.padding,
    this.fit = BoxFit.contain,
    this.gap = 8,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding ?? EdgeInsets.zero,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: Image.asset('assets/icon.png', fit: fit),
          ),
          SizedBox(width: gap),
          SizedBox(
            width: size,
            height: size,
            child: Image.asset('assets/vespera-logo.png', fit: fit),
          ),
        ],
      ),
    );
  }
}
