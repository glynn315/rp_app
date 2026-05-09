import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/work_report_provider.dart';
import '../theme/work_report_colors.dart';

class DetectScreen extends ConsumerStatefulWidget {
  const DetectScreen({super.key});

  @override
  ConsumerState<DetectScreen> createState() => _DetectScreenState();
}

class _DetectScreenState extends ConsumerState<DetectScreen> {
  bool _started = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (_started) return;
      _started = true;

      // Dashboard already detected and loaded today's snapshot — bypass the
      // animation entirely and route straight to the report.
      final pre = ref.read(workReportProvider);
      if (pre.todayLoaded && pre.detectStep == DetectStep.done) {
        if (mounted) context.go('/work-report/today');
        return;
      }

      final empId = ref.read(authProvider).user?.employeeId;
      if (empId == null || empId.isEmpty) {
        if (mounted) context.go('/home');
        return;
      }
      await ref.read(workReportProvider.notifier).runDetection(employeeId: empId);
      if (!mounted) return;
      final s = ref.read(workReportProvider);
      if (s.detectStep == DetectStep.done) {
        // Brief pause so the user can see the final tick before transition.
        await Future<void>.delayed(const Duration(milliseconds: 350));
        if (!mounted) return;
        context.go('/work-report/today');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(workReportProvider);

    final steps = const [
      ('Authenticating credentials',  DetectStep.authenticating),
      ('Fetching employee profile',   DetectStep.fetchingProfile),
      ('Detecting contract type',     DetectStep.detectingContract),
      ('Loading project assignments', DetectStep.loadingProjects),
      ('Checking attendance records', DetectStep.checkingAttendance),
    ];

    final orderIndex = {
      DetectStep.idle: -1,
      DetectStep.authenticating: 0,
      DetectStep.fetchingProfile: 1,
      DetectStep.detectingContract: 2,
      DetectStep.loadingProjects: 3,
      DetectStep.checkingAttendance: 4,
      DetectStep.done: 5,
      DetectStep.failed: -1,
    };
    final current = orderIndex[state.detectStep] ?? -1;

    return Scaffold(
      backgroundColor: WorkReportColors.cream,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: WorkReportColors.ember,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'RPV WORKFORCE',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.4,
                      color: WorkReportColors.charcoal,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              const Text(
                'Setting up your day',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: WorkReportColors.midnight,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Detecting contract type and loading data tied to your account.',
                style: TextStyle(fontSize: 13, color: WorkReportColors.stone),
              ),
              const SizedBox(height: 32),
              ...List.generate(steps.length, (i) {
                final label = steps[i].$1;
                final isDone = current > i || state.detectStep == DetectStep.done;
                final isActive = current == i;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: _StepRow(label: label, isDone: isDone, isActive: isActive),
                );
              }),
              const Spacer(),
              if (state.detectStep == DetectStep.failed) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: WorkReportColors.danger.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: WorkReportColors.danger),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          state.error ?? 'Setup failed.',
                          style: const TextStyle(color: WorkReportColors.danger),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => context.go('/home'),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton(
                        onPressed: () {
                          ref.read(workReportProvider.notifier).resetDetection();
                          setState(() => _started = false);
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            final empId = ref.read(authProvider).user?.employeeId;
                            if (empId != null && empId.isNotEmpty) {
                              _started = true;
                              ref
                                  .read(workReportProvider.notifier)
                                  .runDetection(employeeId: empId);
                            }
                          });
                        },
                        child: const Text('Retry'),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  final String label;
  final bool isDone;
  final bool isActive;
  const _StepRow({required this.label, required this.isDone, required this.isActive});

  @override
  Widget build(BuildContext context) {
    Widget icon;
    if (isDone) {
      icon = Container(
        width: 22,
        height: 22,
        decoration: const BoxDecoration(
          color: WorkReportColors.success,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.check, size: 14, color: Colors.white),
      );
    } else if (isActive) {
      icon = const SizedBox(
        width: 22,
        height: 22,
        child: CircularProgressIndicator(
          strokeWidth: 2.4,
          valueColor: AlwaysStoppedAnimation(WorkReportColors.terracotta),
        ),
      );
    } else {
      icon = Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: WorkReportColors.stone.withValues(alpha: 0.5), width: 1.4),
        ),
      );
    }

    return Row(
      children: [
        icon,
        const SizedBox(width: 12),
        Expanded(
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 180),
            style: TextStyle(
              fontSize: 14,
              fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
              color: isDone || isActive
                  ? WorkReportColors.charcoal
                  : WorkReportColors.stone,
            ),
            child: Text(label),
          ),
        ),
      ],
    );
  }
}
