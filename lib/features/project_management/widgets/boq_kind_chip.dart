import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';

class BoqKindChip extends StatelessWidget {
  final String kind;

  const BoqKindChip({super.key, required this.kind});

  @override
  Widget build(BuildContext context) {
    final upper = kind.toUpperCase();
    final palette = switch (upper) {
      'LABOR' => (AppColors.info, AppColors.infoLight),
      'MISC' => (AppColors.warning, AppColors.warningLight),
      'LMC' => (AppColors.warning, AppColors.warningLight),
      _ => (AppColors.primary, AppColors.surfaceVariant),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: palette.$2,
        borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
      ),
      child: Text(
        upper.isEmpty ? 'BOM' : upper,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: palette.$1,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
