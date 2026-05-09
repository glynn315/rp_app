import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/work_report_models.dart';
import '../providers/work_report_provider.dart';
import '../theme/work_report_colors.dart';

class CalendarGrid extends ConsumerWidget {
  final String employeeId;
  const CalendarGrid({super.key, required this.employeeId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(calendarProvider);
    final notifier = ref.read(calendarProvider.notifier);

    final monthLabel = DateFormat('MMMM yyyy').format(state.month);
    final byDate = <String, CalendarDay>{
      for (final d in state.days)
        '${d.date.year.toString().padLeft(4, '0')}-${d.date.month.toString().padLeft(2, '0')}-${d.date.day.toString().padLeft(2, '0')}':
            d,
    };

    final firstOfMonth = DateTime(state.month.year, state.month.month, 1);
    final daysInMonth = DateTime(state.month.year, state.month.month + 1, 0).day;
    final leadingBlanks = firstOfMonth.weekday % 7; // make Sunday-first

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: state.loading
                    ? null
                    : () => notifier.shiftMonth(-1, employeeId),
                icon: const Icon(Icons.chevron_left, color: WorkReportColors.charcoal),
              ),
              Expanded(
                child: Center(
                  child: Text(
                    monthLabel,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: WorkReportColors.charcoal,
                    ),
                  ),
                ),
              ),
              IconButton(
                onPressed: state.loading
                    ? null
                    : () => notifier.shiftMonth(1, employeeId),
                icon: const Icon(Icons.chevron_right, color: WorkReportColors.charcoal),
              ),
            ],
          ),
          const SizedBox(height: 4),
          // Weekday headers
          Row(
            children: const ['S', 'M', 'T', 'W', 'T', 'F', 'S']
                .map((h) => Expanded(
                      child: Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 4),
                          child: Text(
                            h,
                            style: TextStyle(
                              fontSize: 11,
                              color: WorkReportColors.stone,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ))
                .toList(),
          ),
          // Day grid (7 columns)
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: leadingBlanks + daysInMonth,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 4,
              crossAxisSpacing: 4,
              childAspectRatio: 1,
            ),
            itemBuilder: (context, idx) {
              if (idx < leadingBlanks) return const SizedBox.shrink();
              final day = idx - leadingBlanks + 1;
              final date = DateTime(state.month.year, state.month.month, day);
              final key =
                  '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
              final cell = byDate[key];
              return _DayCell(day: day, cell: cell);
            },
          ),
          const SizedBox(height: 12),
          const _Legend(),
        ],
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  final int day;
  final CalendarDay? cell;
  const _DayCell({required this.day, required this.cell});

  @override
  Widget build(BuildContext context) {
    final state = cell?.state ?? 'inactive';
    Color bg;
    Color fg;
    BoxBorder? border;

    switch (state) {
      case 'matched':
        bg = WorkReportColors.success;
        fg = Colors.white;
        break;
      case 'unmatched':
        bg = Colors.transparent;
        fg = WorkReportColors.terracotta;
        border = Border.all(color: WorkReportColors.terracotta, width: 1.4);
        break;
      case 'today':
        bg = WorkReportColors.terracotta;
        fg = Colors.white;
        break;
      default:
        bg = WorkReportColors.mist;
        fg = WorkReportColors.stone;
        break;
    }

    return Container(
      decoration: BoxDecoration(
        color: bg,
        border: border,
        borderRadius: BorderRadius.circular(8),
      ),
      alignment: Alignment.center,
      child: Text(
        day.toString(),
        style: TextStyle(
          color: fg,
          fontWeight: state == 'inactive' ? FontWeight.w400 : FontWeight.w700,
          fontSize: 13,
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend();
  @override
  Widget build(BuildContext context) {
    Widget chip(Color color, String label, {bool outlined = false}) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: outlined ? Colors.transparent : color,
                border: outlined ? Border.all(color: color, width: 1.4) : null,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(fontSize: 11, color: WorkReportColors.stone)),
          ],
        );
    return Wrap(
      spacing: 16,
      runSpacing: 8,
      children: [
        chip(WorkReportColors.success, 'Matched'),
        chip(WorkReportColors.terracotta, 'Unmatched', outlined: true),
        chip(WorkReportColors.terracotta, 'Today'),
        chip(WorkReportColors.mist, 'Inactive'),
      ],
    );
  }
}
