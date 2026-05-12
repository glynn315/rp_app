import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

/// RPV brand tokens for the Daily Work Report feature.
/// Re-exports from [AppColors] so the whole app shares one source of truth.
class WorkReportColors {
  WorkReportColors._();

  static const Color midnight   = AppColors.midnight;
  static const Color terracotta = AppColors.terracotta;
  static const Color ember      = AppColors.ember;
  static const Color cream      = AppColors.cream;
  static const Color mist       = AppColors.mist;
  static const Color stone      = AppColors.stone;
  static const Color charcoal   = AppColors.charcoalText;
  static const Color steel      = AppColors.steel;
  static const Color danger     = AppColors.error;
  static const Color success    = AppColors.success;

  // Contract banner
  static const Color fieldContract = steel;
  static const Color adminContract = success;
}
