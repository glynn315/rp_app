import 'package:flutter/material.dart';
import '../models/work_report_models.dart';
import '../theme/work_report_colors.dart';

class ShiftBar extends StatelessWidget {
  final ShiftAnchors? shift;

  const ShiftBar({super.key, required this.shift});

  @override
  Widget build(BuildContext context) {
    if (shift == null) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF6E6),
          border: Border.all(color: WorkReportColors.terracotta.withValues(alpha: 0.3)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: WorkReportColors.terracotta, size: 18),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'No biometric attendance for today. Submission disabled.',
                style: TextStyle(color: WorkReportColors.charcoal, fontSize: 13),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: WorkReportColors.mist,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(child: _Cell(label: 'Time In', time: shift!.timeIn, dotColor: WorkReportColors.steel)),
          const _Divider(),
          const Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: Text(
                  'Locked from biometric',
                  style: TextStyle(
                    fontSize: 11,
                    color: WorkReportColors.stone,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
          const _Divider(),
          Expanded(child: _Cell(label: 'Time Out', time: shift!.timeOut, dotColor: WorkReportColors.danger)),
        ],
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  final String label;
  final String time;
  final Color dotColor;
  const _Cell({required this.label, required this.time, required this.dotColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  color: WorkReportColors.stone,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            time,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: WorkReportColors.charcoal,
            ),
          ),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();
  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 40, color: Colors.white);
  }
}
