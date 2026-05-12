import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_colors.dart';

/// RPV brand symbol — text wordmark `RPV·` per brand spec.
/// Inter 600, tight tracking, with an Ember-colored interpunct.
///
/// [color] sets the wordmark color (defaults to Midnight for light surfaces).
/// On dark surfaces, pass [AppColors.pureWhite] or use [AppLogo.onDark].
class AppLogo extends StatelessWidget {
  final double size;
  final Color? color;
  final EdgeInsetsGeometry? padding;

  const AppLogo({
    super.key,
    this.size = 28,
    this.color,
    this.padding,
  });

  /// Convenience constructor for use on dark surfaces (Midnight nav, splash).
  const AppLogo.onDark({super.key, this.size = 28, this.padding})
      : color = AppColors.pureWhite;

  @override
  Widget build(BuildContext context) {
    final wordmarkColor = color ?? AppColors.midnight;
    final baseStyle = GoogleFonts.inter(
      fontSize: size,
      fontWeight: FontWeight.w600,
      letterSpacing: -size * 0.012,
      height: 1.0,
    );

    return Padding(
      padding: padding ?? EdgeInsets.zero,
      child: RichText(
        text: TextSpan(
          style: baseStyle.copyWith(color: wordmarkColor),
          children: [
            const TextSpan(text: 'RPV'),
            TextSpan(
              text: '·',
              style: baseStyle.copyWith(color: AppColors.ember),
            ),
          ],
        ),
      ),
    );
  }
}
