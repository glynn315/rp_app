import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/widgets/status_badge.dart';
import '../../home/home_screen.dart';
import '../models/request_model.dart';
import '../providers/requests_provider.dart';

class RequestsScreen extends ConsumerStatefulWidget {
  const RequestsScreen({super.key});

  @override
  ConsumerState<RequestsScreen> createState() => _RequestsScreenState();
}

class _RequestsScreenState extends ConsumerState<RequestsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  static const _tabs = ['All', 'Leave', 'Overtime', 'Time Logs'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(requestsProvider);

    final allSorted = [
      ...state.leaveRequests.map((r) => _RequestItem(
            id: r.id,
            label: r.type.label,
            subtitle: '${DateFormat('MMM d').format(r.fromDate)} – ${DateFormat('MMM d, yyyy').format(r.toDate)} · ${r.days} day(s)',
            type: 'Leave',
            status: r.status,
            date: r.createdAt,
            icon: Icons.event_available_outlined,
          )),
      ...state.otRequests.map((r) => _RequestItem(
            id: r.id,
            label: 'Overtime Request',
            subtitle: '${DateFormat('MMM d, yyyy').format(r.date)} · ${r.hours.toStringAsFixed(1)} hrs',
            type: 'OT',
            status: r.status,
            date: r.createdAt,
            icon: Icons.more_time,
          )),
      ...state.timeLogs.map((r) => _RequestItem(
            id: r.id,
            label: 'Manual Time Log',
            subtitle: DateFormat('MMM d, yyyy').format(r.date),
            type: 'Time Log',
            status: r.status,
            date: r.createdAt,
            icon: Icons.schedule,
          )),
    ]..sort((a, b) => b.date.compareTo(a.date));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.menu),
          tooltip: 'Open menu',
          onPressed: HomeScreen.openDrawer,
        ),
        title: const Text('My Requests'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(44),
          child: Container(
            color: AppColors.primary,
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelColor: AppColors.secondary,
              unselectedLabelColor: AppColors.textOnPrimary.withValues(alpha: 0.6),
              indicatorColor: AppColors.secondary,
              indicatorWeight: 2.5,
              labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              tabs: _tabs.map((t) => Tab(text: t)).toList(),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          // Action cards
          Container(
            color: AppColors.surface,
            padding: const EdgeInsets.fromLTRB(
              AppDimensions.md,
              AppDimensions.md,
              AppDimensions.md,
              AppDimensions.sm,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'FILE A REQUEST',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textMuted,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: AppDimensions.sm),
                Row(
                  children: [
                    Expanded(
                      child: _ActionCard(
                        icon: Icons.event_available_outlined,
                        label: 'Leave\nRequest',
                        color: AppColors.success,
                        onTap: () => context.push('/requests/leave'),
                      ),
                    ),
                    const SizedBox(width: AppDimensions.sm),
                    Expanded(
                      child: _ActionCard(
                        icon: Icons.more_time,
                        label: 'Overtime\nRequest',
                        color: AppColors.secondary,
                        onTap: () => context.push('/requests/ot'),
                      ),
                    ),
                    const SizedBox(width: AppDimensions.sm),
                    Expanded(
                      child: _ActionCard(
                        icon: Icons.schedule,
                        label: 'Manual\nTime Log',
                        color: AppColors.info,
                        onTap: () => context.push('/requests/timelog'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // List
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _RequestList(items: allSorted),
                _RequestList(items: allSorted.where((r) => r.type == 'Leave').toList()),
                _RequestList(items: allSorted.where((r) => r.type == 'OT').toList()),
                _RequestList(items: allSorted.where((r) => r.type == 'Time Log').toList()),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RequestItem {
  final String id;
  final String label;
  final String subtitle;
  final String type;
  final RequestStatus status;
  final DateTime date;
  final IconData icon;

  const _RequestItem({
    required this.id,
    required this.label,
    required this.subtitle,
    required this.type,
    required this.status,
    required this.date,
    required this.icon,
  });
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionCard({
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
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 26, color: color),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RequestList extends StatelessWidget {
  final List<_RequestItem> items;

  const _RequestList({required this.items});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined, size: 56, color: AppColors.neutral300),
            const SizedBox(height: AppDimensions.md),
            const Text(
              'No requests yet',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(AppDimensions.md),
      itemCount: items.length,
      separatorBuilder: (_, idx) => const SizedBox(height: AppDimensions.sm),
      itemBuilder: (context, index) {
        final item = items[index];
        final badgeType = switch (item.status) {
          RequestStatus.pending => BadgeType.pending,
          RequestStatus.approved => BadgeType.approved,
          RequestStatus.rejected => BadgeType.rejected,
        };

        return Container(
          padding: const EdgeInsets.all(AppDimensions.md),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
            border: Border.all(color: AppColors.neutral100),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                ),
                child: Icon(item.icon, size: 20, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.label,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.subtitle,
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
      },
    );
  }
}
