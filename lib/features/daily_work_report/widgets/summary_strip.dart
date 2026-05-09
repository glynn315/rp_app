import 'package:flutter/material.dart';
import '../providers/work_report_provider.dart';
import '../theme/work_report_colors.dart';

class SummaryStrip extends StatelessWidget {
  final int blocks;
  final int allocatedMinutes;
  final int unallocatedMinutes;

  const SummaryStrip({
    super.key,
    required this.blocks,
    required this.allocatedMinutes,
    required this.unallocatedMinutes,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: _Stat(
              label: 'Blocks',
              value: blocks.toString(),
              valueColor: WorkReportColors.charcoal,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _Stat(
              label: 'Allocated',
              value: formatHours(allocatedMinutes),
              valueColor: WorkReportColors.charcoal,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _Stat(
              label: 'Unallocated',
              value: formatHours(unallocatedMinutes),
              valueColor: unallocatedMinutes > 0
                  ? WorkReportColors.terracotta
                  : WorkReportColors.success,
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;
  const _Stat({required this.label, required this.value, required this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: WorkReportColors.mist,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: WorkReportColors.stone,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}
