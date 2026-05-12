import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/work_report_models.dart';
import '../providers/work_report_provider.dart';
import '../theme/work_report_colors.dart';

class StatusSelector extends ConsumerWidget {
  const StatusSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(workReportProvider);
    final notifier = ref.read(workReportProvider.notifier);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'DAY STATUS',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: WorkReportColors.stone,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _Pill(
                  label: 'Completed',
                  selected: state.dayStatus == DayStatus.completed,
                  fill: WorkReportColors.success,
                  onTap: () => notifier.setDayStatus(DayStatus.completed),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _Pill(
                  label: 'In progress',
                  selected: state.dayStatus == DayStatus.inProgress,
                  fill: WorkReportColors.terracotta,
                  onTap: () => notifier.setDayStatus(DayStatus.inProgress),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _Pill(
                  label: 'Blocked',
                  selected: state.dayStatus == DayStatus.blocked,
                  fill: WorkReportColors.danger,
                  onTap: () => notifier.setDayStatus(DayStatus.blocked),
                ),
              ),
            ],
          ),
          if (state.dayStatus == DayStatus.blocked) ...[
            const SizedBox(height: 12),
            TextField(
              minLines: 2,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: 'Describe the blocker',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onChanged: notifier.setBlockerNote,
            ),
          ],
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final bool selected;
  final Color fill;
  final VoidCallback onTap;

  const _Pill({
    required this.label,
    required this.selected,
    required this.fill,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? fill : Colors.white,
          border: Border.all(color: fill, width: 1.4),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : fill,
          ),
        ),
      ),
    );
  }
}
