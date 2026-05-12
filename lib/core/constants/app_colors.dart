import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // ── RPV Primary Palette (Foundation) ─────────────────────────────────
  static const Color midnight = Color(0xFF0D1B2A);
  static const Color slate = Color(0xFF1C3A52);
  static const Color steel = Color(0xFF2E5F80);
  static const Color horizon = Color(0xFF4A90B8);

  // ── RPV Accent Palette (Human Warmth) ────────────────────────────────
  static const Color terracotta = Color(0xFFC4622D);
  static const Color terracottaHover = Color(0xFFA8521F);
  static const Color ember = Color(0xFFE07B45);
  static const Color sand = Color(0xFFF0C89A);

  // ── RPV Neutral Palette (Canvas) ─────────────────────────────────────
  static const Color cream = Color(0xFFFAF7F2);
  static const Color mist = Color(0xFFEEF2F5);
  static const Color stone = Color(0xFF8FA3B1);
  static const Color charcoalText = Color(0xFF2C3E4A);
  static const Color pureWhite = Color(0xFFFFFFFF);

  // ── Semantic Aliases (kept for backward compatibility) ───────────────
  // Brand mappings — primary action is Terracotta, anchor is Midnight.
  static const Color primary = midnight;
  static const Color primaryDark = Color(0xFF081320);
  static const Color secondary = terracotta;
  static const Color charcoal = charcoalText;

  // ── Backgrounds ──────────────────────────────────────────────────────
  static const Color background = cream;
  static const Color surface = pureWhite;
  static const Color surfaceVariant = mist;

  // ── Neutrals (mapped to brand tones) ─────────────────────────────────
  static const Color neutral100 = mist;
  static const Color neutral200 = Color(0xFFD0DBE3);
  static const Color neutral300 = stone;
  static const Color neutral400 = Color(0xFFE3EAEF);

  // ── Text ─────────────────────────────────────────────────────────────
  static const Color textPrimary = charcoalText;
  static const Color textSecondary = Color(0xFF5A7080);
  static const Color textMuted = stone;
  static const Color textOnPrimary = pureWhite;
  static const Color textOnSecondary = pureWhite;

  // ── Semantic / Functional ────────────────────────────────────────────
  static const Color success = Color(0xFF2D7A4F);
  static const Color successLight = Color(0xFFD4EDDF);
  static const Color warning = Color(0xFFB87333);
  static const Color warningLight = Color(0xFFF5E6D0);
  static const Color error = Color(0xFFB83232);
  static const Color errorLight = Color(0xFFF5D4D4);
  static const Color info = steel;
  static const Color infoLight = Color(0xFFD4E5F5);

  // ── Priority (mapped to brand semantic tones) ────────────────────────
  static const Color priorityLow = success;
  static const Color priorityMedium = warning;
  static const Color priorityHigh = error;
  static const Color priorityUrgent = Color(0xFF8B2020);

  // ── Status ───────────────────────────────────────────────────────────
  static const Color statusPending = warning;
  static const Color statusApproved = success;
  static const Color statusRejected = error;
  static const Color statusInProgress = info;

  // ── Borders / Lines ──────────────────────────────────────────────────
  static const Color border = Color(0x1F2C3E4A); // rgba(44,62,74,0.12)
}
