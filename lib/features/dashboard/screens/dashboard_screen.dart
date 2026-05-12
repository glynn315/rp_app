import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/widgets/status_badge.dart';
import '../../auth/providers/auth_provider.dart';
import '../../home/home_screen.dart';
import '../../tasks/models/task_model.dart';
import '../../tasks/providers/task_provider.dart';
import '../../requests/models/request_model.dart';
import '../../requests/providers/requests_provider.dart';
import '../../daily_work_report/providers/work_report_provider.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final taskState = ref.watch(taskProvider);
    final requestState = ref.watch(requestsProvider);
    final now = DateTime.now();
    final greeting = _greeting(now.hour);

    final pendingTasks = taskState.tasks.where((t) => t.status == TaskStatus.pending).length;
    final inProgressTasks = taskState.tasks.where((t) => t.status == TaskStatus.inProgress).length;
    final pendingRequests = [
      ...requestState.leaveRequests,
      ...requestState.otRequests,
      ...requestState.timeLogs,
    ].where((r) => r.status == RequestStatus.pending).length;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 130,
            pinned: true,
            backgroundColor: AppColors.primary,
            iconTheme: const IconThemeData(color: AppColors.textOnPrimary),
            leading: IconButton(
              icon: const Icon(Icons.menu),
              tooltip: 'Open menu',
              onPressed: HomeScreen.openDrawer,
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                color: AppColors.primary,
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                alignment: Alignment.bottomLeft,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$greeting,',
                      style: TextStyle(
                        color: AppColors.textOnPrimary.withValues(alpha: 0.7),
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      user?.name ?? 'Employee',
                      style: const TextStyle(
                        color: AppColors.textOnPrimary,
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 12, top: 8),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      DateFormat('EEE, MMM d').format(now),
                      style: TextStyle(
                        color: AppColors.textOnPrimary.withValues(alpha: 0.9),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      DateFormat('yyyy').format(now),
                      style: TextStyle(
                        color: AppColors.textOnPrimary.withValues(alpha: 0.6),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(AppDimensions.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Quick stats
                  _StatsGrid(
                    pendingTasks: pendingTasks,
                    inProgressTasks: inProgressTasks,
                    leaveBalance: user?.leaveBalance ?? 0,
                    pendingRequests: pendingRequests,
                  ),
                  const SizedBox(height: AppDimensions.lg),

                  // Daily Work Report entry
                  _DailyWorkReportCta(),
                  const SizedBox(height: AppDimensions.sm),

                  // Log-Progress wizard entry — Attendance → BoQ → Photo → AI
                  const _LogProgressCta(),
                  const SizedBox(height: AppDimensions.lg),

                  // Quick actions
                  const _SectionHeader(title: 'QUICK ACTIONS'),
                  const SizedBox(height: AppDimensions.sm),
                  _QuickActions(),
                  const SizedBox(height: AppDimensions.lg),

                  // Recent tasks
                  _SectionHeader(
                    title: 'RECENT TASKS',
                    onSeeAll: () => context.go('/tasks'),
                  ),
                  const SizedBox(height: AppDimensions.sm),
                  _RecentTasks(tasks: taskState.tasks.take(3).toList()),
                  const SizedBox(height: AppDimensions.lg),

                  // Recent requests
                  _SectionHeader(
                    title: 'RECENT REQUESTS',
                    onSeeAll: () => context.go('/requests'),
                  ),
                  const SizedBox(height: AppDimensions.sm),
                  _RecentRequests(requestState: requestState),
                  const SizedBox(height: AppDimensions.xl),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _greeting(int hour) {
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }
}

class _StatsGrid extends StatelessWidget {
  final int pendingTasks;
  final int inProgressTasks;
  final double leaveBalance;
  final int pendingRequests;

  const _StatsGrid({
    required this.pendingTasks,
    required this.inProgressTasks,
    required this.leaveBalance,
    required this.pendingRequests,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: AppDimensions.sm,
      mainAxisSpacing: AppDimensions.sm,
      childAspectRatio: 1.6,
      children: [
        _StatCard(
          label: 'Pending Tasks',
          value: '$pendingTasks',
          icon: Icons.pending_actions,
          iconColor: AppColors.statusPending,
          iconBg: AppColors.warningLight,
        ),
        _StatCard(
          label: 'In Progress',
          value: '$inProgressTasks',
          icon: Icons.loop,
          iconColor: AppColors.statusInProgress,
          iconBg: AppColors.infoLight,
        ),
        _StatCard(
          label: 'Leave Balance',
          value: '${leaveBalance.toStringAsFixed(0)} days',
          icon: Icons.beach_access_outlined,
          iconColor: AppColors.statusApproved,
          iconBg: AppColors.successLight,
        ),
        _StatCard(
          label: 'Pending Requests',
          value: '$pendingRequests',
          icon: Icons.hourglass_empty,
          iconColor: AppColors.primary,
          iconBg: AppColors.surfaceVariant,
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color iconColor;
  final Color iconBg;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.iconColor,
    required this.iconBg,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        border: Border.all(color: AppColors.neutral100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: iconColor),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ActionButton(
            icon: Icons.add_task,
            label: 'New Task',
            color: AppColors.primary,
            onTap: () => context.push('/tasks/add'),
          ),
        ),
        const SizedBox(width: AppDimensions.sm),
        Expanded(
          child: _ActionButton(
            icon: Icons.event_available_outlined,
            label: 'File Leave',
            color: AppColors.success,
            onTap: () => context.push('/requests/leave'),
          ),
        ),
        const SizedBox(width: AppDimensions.sm),
        Expanded(
          child: _ActionButton(
            icon: Icons.more_time,
            label: 'File OT',
            color: AppColors.secondary,
            onTap: () => context.push('/requests/ot'),
          ),
        ),
        const SizedBox(width: AppDimensions.sm),
        Expanded(
          child: _ActionButton(
            icon: Icons.schedule,
            label: 'Time Log',
            color: AppColors.info,
            onTap: () => context.push('/requests/timelog'),
          ),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          border: Border.all(color: color.withValues(alpha: 0.15)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 22, color: color),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: color,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onSeeAll;

  const _SectionHeader({required this.title, this.onSeeAll});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textMuted,
              letterSpacing: 1.0,
            ),
          ),
        ),
        if (onSeeAll != null)
          GestureDetector(
            onTap: onSeeAll,
            child: const Text(
              'See all',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.secondary,
              ),
            ),
          ),
      ],
    );
  }
}

class _RecentTasks extends ConsumerWidget {
  final List<Task> tasks;

  const _RecentTasks({required this.tasks});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (tasks.isEmpty) {
      return _EmptyState(icon: Icons.task_alt, message: 'No tasks yet');
    }
    return Column(
      children: tasks
          .map(
            (t) => Padding(
              padding: const EdgeInsets.only(bottom: AppDimensions.xs),
              child: _RecentTaskTile(task: t),
            ),
          )
          .toList(),
    );
  }
}

class _RecentTaskTile extends StatelessWidget {
  final Task task;

  const _RecentTaskTile({required this.task});

  @override
  Widget build(BuildContext context) {
    final badgeType = switch (task.priority) {
      TaskPriority.low => BadgeType.low,
      TaskPriority.medium => BadgeType.medium,
      TaskPriority.high => BadgeType.high,
      TaskPriority.urgent => BadgeType.urgent,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        border: Border.all(color: AppColors.neutral100),
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 40,
            decoration: BoxDecoration(
              color: _priorityColor(task.priority),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  task.category.label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          StatusBadge(type: badgeType),
        ],
      ),
    );
  }

  Color _priorityColor(TaskPriority p) => switch (p) {
        TaskPriority.low => AppColors.priorityLow,
        TaskPriority.medium => AppColors.priorityMedium,
        TaskPriority.high => AppColors.priorityHigh,
        TaskPriority.urgent => AppColors.priorityUrgent,
      };
}

class _RecentRequests extends StatelessWidget {
  final RequestsState requestState;

  const _RecentRequests({required this.requestState});

  @override
  Widget build(BuildContext context) {
    final all = [
      ...requestState.leaveRequests.map((r) => (label: 'Leave — ${r.type.label}', status: r.status, date: r.createdAt)),
      ...requestState.otRequests.map((r) => (label: 'Overtime Request', status: r.status, date: r.createdAt)),
      ...requestState.timeLogs.map((r) => (label: 'Time Log', status: r.status, date: r.createdAt)),
    ]..sort((a, b) => b.date.compareTo(a.date));

    if (all.isEmpty) {
      return _EmptyState(icon: Icons.assignment_outlined, message: 'No requests yet');
    }

    return Column(
      children: all
          .take(3)
          .map(
            (r) => Padding(
              padding: const EdgeInsets.only(bottom: AppDimensions.xs),
              child: _RequestTile(label: r.label, status: r.status, date: r.date),
            ),
          )
          .toList(),
    );
  }
}

class _RequestTile extends StatelessWidget {
  final String label;
  final RequestStatus status;
  final DateTime date;

  const _RequestTile({
    required this.label,
    required this.status,
    required this.date,
  });

  @override
  Widget build(BuildContext context) {
    final badgeType = switch (status) {
      RequestStatus.pending => BadgeType.pending,
      RequestStatus.approved => BadgeType.approved,
      RequestStatus.rejected => BadgeType.rejected,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        border: Border.all(color: AppColors.neutral100),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  DateFormat('MMM d, yyyy').format(date),
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          StatusBadge(type: badgeType),
        ],
      ),
    );
  }
}

/// Entry point for the guided 4-step Log-Progress wizard
/// (Attendance → BoQ → Photo → AI evaluation). Renders as a secondary CTA
/// directly under the day's report card so it's always one tap away.
class _LogProgressCta extends StatelessWidget {
  const _LogProgressCta();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => context.push('/log-progress'),
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        child: Container(
          padding: const EdgeInsets.all(AppDimensions.md),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
            border: Border.all(color: AppColors.secondary.withValues(alpha: 0.4)),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.secondary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.add_a_photo_outlined,
                    color: AppColors.secondary, size: 22),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Log progress with photo',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Attendance → BoQ → Photo → AI evaluation',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward,
                  color: AppColors.secondary, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

/// Daily Work Report status card.
///
/// Auto-detects the worker's contract + today's report state on mount, then
/// shows one of: loading, no-attendance, ready-to-submit, or submitted.
class _DailyWorkReportCta extends ConsumerStatefulWidget {
  @override
  ConsumerState<_DailyWorkReportCta> createState() => _DailyWorkReportCtaState();
}

class _DailyWorkReportCtaState extends ConsumerState<_DailyWorkReportCta> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final empId = ref.read(authProvider).user?.employeeId;
      if (empId != null && empId.isNotEmpty) {
        ref.read(workReportProvider.notifier).loadToday(employeeId: empId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(workReportProvider);

    // ─── Loading ────────────────────────────────────────────────────────
    if (!s.todayLoaded && s.detectStep != DetectStep.failed) {
      return const _CtaShell(
        bg: AppColors.primary,
        leadingIcon: Icons.assignment_outlined,
        title: "Today's work report",
        subtitle: 'Checking your contract and attendance…',
        trailing: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation(Colors.white),
          ),
        ),
      );
    }

    // ─── Failed to detect ───────────────────────────────────────────────
    if (s.detectStep == DetectStep.failed) {
      return _CtaShell(
        bg: AppColors.error,
        leadingIcon: Icons.error_outline,
        title: 'Could not load work report',
        subtitle: s.error ?? 'Tap to retry.',
        trailing: const Icon(Icons.refresh, color: Colors.white, size: 20),
        onTap: () {
          final empId = ref.read(authProvider).user?.employeeId;
          if (empId != null && empId.isNotEmpty) {
            ref.read(workReportProvider.notifier).loadToday(employeeId: empId, force: true);
          }
        },
      );
    }

    // ─── No biometric attendance for today ──────────────────────────────
    final hasShift = s.profile?.shift != null && s.profile!.hasAttendanceToday;
    if (!hasShift) {
      return const _CtaShell(
        bg: AppColors.warning,
        leadingIcon: Icons.warning_amber_rounded,
        title: 'No attendance recorded today',
        subtitle: 'Daily report is unavailable until biometric time-in is logged.',
        trailing: Icon(Icons.info_outline, color: Colors.white, size: 20),
      );
    }

    // ─── Already submitted ──────────────────────────────────────────────
    if (s.submitted) {
      final shift = s.profile!.shift!;
      return _CtaShell(
        bg: AppColors.success,
        leadingIcon: Icons.check_circle,
        title: "Today's report submitted",
        subtitle: 'Shift ${shift.timeIn} – ${shift.timeOut} · supervisor notified.',
        trailing: const Icon(Icons.arrow_forward, color: Colors.white, size: 20),
        onTap: () => context.go('/work-report/today'),
      );
    }

    // ─── Needs report ───────────────────────────────────────────────────
    final shift = s.profile!.shift!;
    final isField = s.profile!.contractType == 'field';
    return _CtaShell(
      bg: AppColors.primary,
      accentBg: AppColors.secondary,
      leadingIcon: Icons.assignment_outlined,
      title: 'Submit your daily report',
      subtitle: '${isField ? "Field" : "Admin"} contract · shift ${shift.timeIn}–${shift.timeOut}',
      trailing: const Icon(Icons.arrow_forward, color: Colors.white, size: 20),
      onTap: () => context.go('/work-report/today'),
    );
  }
}

/// Shared shell for the various dashboard CTA states. Keeps padding,
/// shadow, leading-icon, and tap-feedback consistent.
class _CtaShell extends StatelessWidget {
  final Color bg;
  final Color? accentBg;
  final IconData leadingIcon;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _CtaShell({
    required this.bg,
    required this.leadingIcon,
    required this.title,
    required this.subtitle,
    this.accentBg,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        child: Container(
          padding: const EdgeInsets.all(AppDimensions.md),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
            boxShadow: [
              BoxShadow(
                color: bg.withValues(alpha: 0.18),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: accentBg ?? Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(leadingIcon, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.78),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 8),
                trailing!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;

  const _EmptyState({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        border: Border.all(color: AppColors.neutral100),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 18, color: AppColors.textMuted),
          const SizedBox(width: 8),
          Text(
            message,
            style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}
