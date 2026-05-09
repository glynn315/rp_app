import 'package:flutter/material.dart';
import '../theme/work_report_colors.dart';

class GapWarning extends StatelessWidget {
  final String from;
  final String to;
  final int minutes;

  const GapWarning({
    super.key,
    required this.from,
    required this.to,
    required this.minutes,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(
          color: WorkReportColors.terracotta.withValues(alpha: 0.6),
          style: BorderStyle.solid,
          width: 1,
        ),
        color: WorkReportColors.terracotta.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, size: 16, color: WorkReportColors.terracotta),
          const SizedBox(width: 8),
          Text(
            'Gap $from → $to',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: WorkReportColors.charcoal,
            ),
          ),
          const Spacer(),
          Text(
            '$minutes min',
            style: const TextStyle(
              fontSize: 11,
              color: WorkReportColors.stone,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
