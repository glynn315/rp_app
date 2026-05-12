import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/work_report_models.dart';
import '../providers/work_report_provider.dart';
import '../theme/work_report_colors.dart';
import '../widgets/add_block_form.dart';
import '../widgets/ai_probe_card.dart';
import '../widgets/calendar_grid.dart';
import '../widgets/contract_banner.dart';
import '../widgets/gap_warning.dart';
import '../widgets/shift_bar.dart';
import '../widgets/status_selector.dart';
import '../widgets/summary_strip.dart';
import '../widgets/timeline_block.dart';
import '../widgets/unmatched_list.dart';

class DailyWorkReportScreen extends ConsumerStatefulWidget {
  /// 'calendar' | 'unmatched' | 'today'
  final String initialTab;

  const DailyWorkReportScreen({super.key, this.initialTab = 'today'});

  @override
  ConsumerState<DailyWorkReportScreen> createState() => _DailyWorkReportScreenState();
}

class _DailyWorkReportScreenState extends ConsumerState<DailyWorkReportScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  static const _tabIndex = {'calendar': 0, 'unmatched': 1, 'today': 2};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: _tabIndex[widget.initialTab] ?? 2,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // If detection wasn't completed (deep link / direct nav), bounce to detect.
      final s = ref.read(workReportProvider);
      if (s.detectStep != DetectStep.done) {
        context.go('/work-report');
        return;
      }
      final empId = ref.read(authProvider).user?.employeeId;
      if (empId != null) {
        ref.read(calendarProvider.notifier).load(empId);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(workReportProvider);
    final profile = s.profile;

    if (profile == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final empId = ref.watch(authProvider).user?.employeeId ?? profile.employeeId;

    return Scaffold(
      backgroundColor: WorkReportColors.cream,
      body: SafeArea(
        child: Column(
          children: [
            ContractBanner(
              contractType: profile.contractType,
              employeeName: profile.name,
              employeeId: profile.employeeId,
            ),
            _TabRow(controller: _tabController, unmatchedCount: ref.watch(calendarProvider).unmatchedDates.length),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  CalendarGrid(employeeId: empId),
                  UnmatchedList(employeeId: empId, contractType: profile.contractType),
                  _TodayReportTab(profile: profile),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TabRow extends StatelessWidget {
  final TabController controller;
  final int unmatchedCount;

  const _TabRow({required this.controller, required this.unmatchedCount});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: WorkReportColors.midnight,
      child: TabBar(
        controller: controller,
        labelColor: Colors.white,
        unselectedLabelColor: WorkReportColors.stone,
        indicatorColor: WorkReportColors.terracotta,
        indicatorWeight: 3,
        labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        tabs: [
          const Tab(text: 'Calendar'),
          Tab(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Unmatched'),
                if (unmatchedCount > 0) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: WorkReportColors.terracotta,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      unmatchedCount.toString(),
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600),
                    ),
                  ),
                ]
              ],
            ),
          ),
          const Tab(text: "Today's report"),
        ],
      ),
    );
  }
}

class _TodayReportTab extends ConsumerWidget {
  final WorkProfile profile;
  const _TodayReportTab({required this.profile});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(workReportProvider);

    if (s.submitted) {
      return _SubmittedView();
    }

    final shift = profile.shift;
    final gaps = s.gaps;
    final blocks = s.sortedBlocks;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ShiftBar(shift: shift),
          SummaryStrip(
            blocks: blocks.length,
            allocatedMinutes: s.allocatedMinutes,
            unallocatedMinutes: s.unallocatedMinutes,
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ...blocks.asMap().entries.expand((entry) {
                  final i = entry.key;
                  final b = entry.value;
                  final widgets = <Widget>[
                    TimelineBlockCard(index: i, block: b, contractType: profile.contractType),
                  ];
                  if (i < gaps.length) {
                    final shift = profile.shift;
                    if (shift != null) {
                      // Render gap row before each block whose preceding gap is real.
                      final gap = gaps[i];
                      widgets.insert(0, GapWarning(from: gap.from, to: gap.to, minutes: gap.minutes));
                    }
                  }
                  return widgets;
                }),
                if (shift != null) AddBlockSection(contractType: profile.contractType),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const AiProbeCard(),
          const StatusSelector(),
          if (s.error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: WorkReportColors.danger.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: WorkReportColors.danger, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(s.error!, style: const TextStyle(color: WorkReportColors.danger)),
                    ),
                  ],
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: WorkReportColors.midnight,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(52),
              ),
              onPressed: !s.canSubmit || s.submitting
                  ? null
                  : () async {
                      final ok = await ref.read(workReportProvider.notifier).submit();
                      if (!ok || !context.mounted) return;
                    },
              child: s.submitting
                  ? const SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text(
                      'Submit daily report',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SubmittedView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: WorkReportColors.success,
              borderRadius: BorderRadius.circular(36),
            ),
            child: const Icon(Icons.check, color: Colors.white, size: 40),
          ),
          const SizedBox(height: 16),
          const Text(
            'Report submitted!',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: WorkReportColors.midnight,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Supervisor notified.',
            style: TextStyle(color: WorkReportColors.stone),
          ),
        ],
      ),
    );
  }
}
