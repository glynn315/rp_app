import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/work_report_models.dart';
import '../providers/work_report_provider.dart';
import '../theme/work_report_colors.dart';
import 'block_form_fields.dart';

class TimelineBlockCard extends ConsumerStatefulWidget {
  final int index;
  final WorkBlock block;
  final String contractType;

  const TimelineBlockCard({
    super.key,
    required this.index,
    required this.block,
    required this.contractType,
  });

  @override
  ConsumerState<TimelineBlockCard> createState() => _TimelineBlockCardState();
}

class _TimelineBlockCardState extends ConsumerState<TimelineBlockCard> {
  bool _editing = false;

  String _duration() {
    final mins = hhmmToMinutes(widget.block.timeOut) - hhmmToMinutes(widget.block.timeIn);
    final h = mins ~/ 60;
    final m = mins % 60;
    if (h == 0) return '${m}m';
    if (m == 0) return '${h}h';
    return '${h}h ${m}m';
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.block;
    final pillColor = (b.tagType == TagType.project || b.tagType == TagType.adminProject)
        ? WorkReportColors.steel
        : WorkReportColors.ember;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _editing ? WorkReportColors.steel : WorkReportColors.mist,
          width: _editing ? 2 : 1,
        ),
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => setState(() => _editing = !_editing),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: WorkReportColors.terracotta,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      (widget.index + 1).toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: pillColor,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                TagType.labelFor(b.tagType),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.6,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                b.tagLabel,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: WorkReportColors.charcoal,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(
                              '${b.timeIn} – ${b.timeOut}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: WorkReportColors.stone,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              width: 4,
                              height: 4,
                              decoration: const BoxDecoration(
                                color: WorkReportColors.stone,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _duration(),
                              style: const TextStyle(
                                fontSize: 12,
                                color: WorkReportColors.stone,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        if (!_editing && b.tasks.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            b.tasks,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              color: WorkReportColors.charcoal,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: WorkReportColors.danger),
                    onPressed: () => ref.read(workReportProvider.notifier).removeBlock(b.localId),
                  ),
                  Icon(_editing ? Icons.expand_less : Icons.expand_more, color: WorkReportColors.stone),
                ],
              ),
            ),
          ),
          if (_editing)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: BlockFormFields(
                contractType: widget.contractType,
                initial: b,
                lockTagType: true,
                submitLabel: 'Save changes',
                onCancel: () => setState(() => _editing = false),
                onSubmit: (updated) {
                  ref.read(workReportProvider.notifier).updateBlock(b.localId, updated);
                  setState(() => _editing = false);
                },
              ),
            ),
        ],
      ),
    );
  }
}
