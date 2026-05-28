import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';

/// DR (Draft) / PR (Posted) pill for IPR documents.
class IprStatusPill extends StatelessWidget {
  final String status;
  const IprStatusPill({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final posted = status == 'PR';
    final label = posted ? 'POSTED' : 'DRAFT';
    final fg = posted ? AppColors.success : AppColors.warning;
    final bg = posted ? AppColors.successLight : AppColors.warningLight;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: fg,
          letterSpacing: 1.0,
        ),
      ),
    );
  }
}
