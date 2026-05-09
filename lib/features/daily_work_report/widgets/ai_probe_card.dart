import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/work_report_models.dart';
import '../providers/work_report_provider.dart';
import '../theme/work_report_colors.dart';

class AiProbeCard extends ConsumerStatefulWidget {
  const AiProbeCard({super.key});

  @override
  ConsumerState<AiProbeCard> createState() => _AiProbeCardState();
}

class _AiProbeCardState extends ConsumerState<AiProbeCard> {
  late final TextEditingController _ctl;

  @override
  void initState() {
    super.initState();
    _ctl = TextEditingController(text: ref.read(workReportProvider).aiCheck.answer);
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(workReportProvider);
    final ai = state.aiCheck;
    if (ai.question == null) return const SizedBox.shrink();

    if (ai.outcome == AiCheckOutcome.answered) {
      return _ConfirmationRow(
        bg: WorkReportColors.success.withValues(alpha: 0.12),
        fg: WorkReportColors.success,
        icon: Icons.check_circle_outline,
        text: 'AI check answered',
      );
    }
    if (ai.outcome == AiCheckOutcome.skipped) {
      return _ConfirmationRow(
        bg: WorkReportColors.terracotta.withValues(alpha: 0.12),
        fg: WorkReportColors.terracotta,
        icon: Icons.flag_outlined,
        text: 'AI check skipped — supervisor flagged',
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: WorkReportColors.midnight,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: WorkReportColors.ember,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  ai.question!.category.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 9,
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.7,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'AI random check',
                style: TextStyle(
                  fontSize: 11,
                  color: WorkReportColors.stone,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.6,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            ai.question!.question,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _ctl,
            minLines: 2,
            maxLines: 4,
            style: const TextStyle(color: Colors.white),
            onChanged: (v) => ref.read(workReportProvider.notifier).setAiAnswer(v),
            decoration: InputDecoration(
              hintText: 'Type your answer…',
              hintStyle: TextStyle(color: WorkReportColors.stone.withValues(alpha: 0.8)),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.08),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: WorkReportColors.ember, width: 2),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => ref.read(workReportProvider.notifier).skipAiAnswer(),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.white.withValues(alpha: 0.4)),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Skip'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  onPressed: state.aiCheck.answer.trim().isEmpty
                      ? null
                      : () => ref.read(workReportProvider.notifier).submitAiAnswer(),
                  style: FilledButton.styleFrom(
                    backgroundColor: WorkReportColors.ember,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Submit answer'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ConfirmationRow extends StatelessWidget {
  final Color bg, fg;
  final IconData icon;
  final String text;
  const _ConfirmationRow({required this.bg, required this.fg, required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
      child: Row(
        children: [
          Icon(icon, color: fg, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: TextStyle(color: fg, fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }
}
