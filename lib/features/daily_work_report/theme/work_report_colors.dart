import 'package:flutter/material.dart';

/// RPV brand tokens for the Daily Work Report feature.
/// Defined separately from `AppColors` because the screen spec calls for the
/// Vespera (RPV) palette, which is distinct from the broader RPV Workforce app.
class WorkReportColors {
  WorkReportColors._();

  static const Color midnight   = Color(0xFF0D1B2A);
  static const Color terracotta = Color(0xFFC4622D);
  static const Color ember      = Color(0xFFE07B45);
  static const Color cream      = Color(0xFFFAF7F2);
  static const Color mist       = Color(0xFFEEF2F5);
  static const Color stone      = Color(0xFF8FA3B1);
  static const Color charcoal   = Color(0xFF2C3E4A);
  static const Color steel      = Color(0xFF2E5F80);
  static const Color danger     = Color(0xFFB83232);
  static const Color success    = Color(0xFF2D7A4F);

  // Contract banner
  static const Color fieldContract = steel;
  static const Color adminContract = success;
}
