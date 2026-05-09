import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/work_report_provider.dart';
import '../theme/work_report_colors.dart';
import 'block_form_fields.dart';

class AddBlockSection extends ConsumerStatefulWidget {
  final String contractType;

  const AddBlockSection({super.key, required this.contractType});

  @override
  ConsumerState<AddBlockSection> createState() => _AddBlockSectionState();
}

class _AddBlockSectionState extends ConsumerState<AddBlockSection> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    if (!_open) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
        ),
        child: InkWell(
          onTap: () => setState(() => _open = true),
          borderRadius: BorderRadius.circular(12),
          child: DottedBorderBox(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.add, color: WorkReportColors.terracotta),
                    SizedBox(width: 6),
                    Text(
                      '+ Add work block',
                      style: TextStyle(
                        color: WorkReportColors.terracotta,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    final suggest = ref.read(workReportProvider.notifier).suggestTimes();

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: WorkReportColors.terracotta.withValues(alpha: 0.4), width: 1.4),
      ),
      child: BlockFormFields(
        contractType: widget.contractType,
        defaultTimeIn: suggest.timeIn,
        defaultTimeOut: suggest.timeOut,
        submitLabel: 'Add block',
        onCancel: () => setState(() => _open = false),
        onSubmit: (block) {
          ref.read(workReportProvider.notifier).addBlock(block);
          setState(() => _open = false);
        },
      ),
    );
  }
}

/// Simple dashed border container used for the "Add block" CTA.
class DottedBorderBox extends StatelessWidget {
  final Widget child;
  const DottedBorderBox({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedBorderPainter(),
      child: child,
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = WorkReportColors.terracotta.withValues(alpha: 0.55)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(12),
    );

    final path = Path()..addRRect(rrect);
    final dashed = _dashPath(path, dashWidth: 6, dashSpace: 4);
    canvas.drawPath(dashed, paint);
  }

  Path _dashPath(Path source, {required double dashWidth, required double dashSpace}) {
    final dest = Path();
    for (final metric in source.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        final to = (distance + dashWidth).clamp(0, metric.length).toDouble();
        dest.addPath(metric.extractPath(distance, to), Offset.zero);
        distance += dashWidth + dashSpace;
      }
    }
    return dest;
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
