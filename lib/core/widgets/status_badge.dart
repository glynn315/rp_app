import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

enum BadgeType { pending, approved, rejected, inProgress, low, medium, high, urgent }

class StatusBadge extends StatelessWidget {
  final BadgeType type;
  final String? label;

  const StatusBadge({super.key, required this.type, this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: _bgColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label ?? _defaultLabel,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: _textColor,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  Color get _bgColor => switch (type) {
        BadgeType.pending => AppColors.statusPending.withValues(alpha: 0.12),
        BadgeType.approved => AppColors.statusApproved.withValues(alpha: 0.12),
        BadgeType.rejected => AppColors.statusRejected.withValues(alpha: 0.12),
        BadgeType.inProgress => AppColors.statusInProgress.withValues(alpha: 0.12),
        BadgeType.low => AppColors.priorityLow.withValues(alpha: 0.12),
        BadgeType.medium => AppColors.priorityMedium.withValues(alpha: 0.12),
        BadgeType.high => AppColors.priorityHigh.withValues(alpha: 0.12),
        BadgeType.urgent => AppColors.priorityUrgent.withValues(alpha: 0.12),
      };

  Color get _textColor => switch (type) {
        BadgeType.pending => AppColors.statusPending,
        BadgeType.approved => AppColors.statusApproved,
        BadgeType.rejected => AppColors.statusRejected,
        BadgeType.inProgress => AppColors.statusInProgress,
        BadgeType.low => AppColors.priorityLow,
        BadgeType.medium => AppColors.priorityMedium,
        BadgeType.high => AppColors.priorityHigh,
        BadgeType.urgent => AppColors.priorityUrgent,
      };

  String get _defaultLabel => switch (type) {
        BadgeType.pending => 'Pending',
        BadgeType.approved => 'Approved',
        BadgeType.rejected => 'Rejected',
        BadgeType.inProgress => 'In Progress',
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
            text,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
              letterSpacing: 0.8,
            ),
          ),
        ),
        trailing ?? const SizedBox.shrink(),
      ],
    );
  }
}
