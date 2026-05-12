import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

enum BadgeType { pending, approved, rejected, inProgress, draft, info, low, medium, high, urgent }

/// Exact brand pill colors per RPV brand spec.
class _BadgePalette {
  final Color bg;
  final Color text;
  const _BadgePalette(this.bg, this.text);
}

const Map<BadgeType, _BadgePalette> _badgeColors = {
  BadgeType.approved:   _BadgePalette(Color(0xFFD4EDDF), Color(0xFF2D7A4F)),
  BadgeType.pending:    _BadgePalette(Color(0xFFF5E6D0), Color(0xFF8B5A1A)),
  BadgeType.rejected:   _BadgePalette(Color(0xFFF5D4D4), Color(0xFF8B2020)),
  BadgeType.draft:      _BadgePalette(Color(0xFFEEF2F5), Color(0xFF5A7080)),
  BadgeType.info:       _BadgePalette(Color(0xFFD4E5F5), Color(0xFF1C4A72)),
  BadgeType.inProgress: _BadgePalette(Color(0xFFD4E5F5), Color(0xFF1C4A72)),
  // Priority — mapped onto status palettes.
  BadgeType.low:        _BadgePalette(Color(0xFFD4EDDF), Color(0xFF2D7A4F)),
  BadgeType.medium:     _BadgePalette(Color(0xFFF5E6D0), Color(0xFF8B5A1A)),
  BadgeType.high:       _BadgePalette(Color(0xFFF5D4D4), Color(0xFF8B2020)),
  BadgeType.urgent:     _BadgePalette(Color(0xFFF5D4D4), Color(0xFF5C1414)),
};

class StatusBadge extends StatelessWidget {
  final BadgeType type;
  final String? label;

  const StatusBadge({super.key, required this.type, this.label});

  @override
  Widget build(BuildContext context) {
    final palette = _badgeColors[type]!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: palette.bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label ?? _defaultLabel,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: palette.text,
          letterSpacing: 0.06 * 11,
        ),
      ),
    );
  }

  String get _defaultLabel => switch (type) {
        BadgeType.pending => 'Pending',
        BadgeType.approved => 'Approved',
        BadgeType.rejected => 'Rejected',
        BadgeType.inProgress => 'In Progress',
        BadgeType.draft => 'Draft',
        BadgeType.info => 'Info',
        BadgeType.low => 'Low',
        BadgeType.medium => 'Medium',
        BadgeType.high => 'High',
        BadgeType.urgent => 'Urgent',
      };
}

class SectionLabel extends StatelessWidget {
  final String text;
  final Widget? trailing;

  const SectionLabel({super.key, required this.text, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            text.toUpperCase(),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: AppColors.stone,
              letterSpacing: 0.08 * 11,
            ),
          ),
        ),
        trailing ?? const SizedBox.shrink(),
      ],
    );
  }
}
