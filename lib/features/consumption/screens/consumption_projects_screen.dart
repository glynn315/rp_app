import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/widgets/app_drawer.dart';
import '../models/consumption_models.dart';
import '../providers/consumption_provider.dart';

class ConsumptionProjectsScreen extends ConsumerStatefulWidget {
  const ConsumptionProjectsScreen({super.key});

  @override
  ConsumerState<ConsumptionProjectsScreen> createState() =>
      _ConsumptionProjectsScreenState();
}

class _ConsumptionProjectsScreenState
    extends ConsumerState<ConsumptionProjectsScreen> {
  final _searchController = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _searchController.text = ref.read(consumptionSearchProvider);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      ref.read(consumptionSearchProvider.notifier).state = value.trim();
    });
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(consumptionProjectsProvider);
    final items = async.value ?? const <ConsumptionProject>[];

    return Scaffold(
      backgroundColor: AppColors.background,
      drawer: const AppDrawer(),
      appBar: AppBar(
        leading: Builder(
          builder: (innerContext) => IconButton(
            icon: const Icon(Icons.menu),
            tooltip: 'Open menu',
            onPressed: () => Scaffold.of(innerContext).openDrawer(),
          ),
        ),
        title: const Text('Consumption'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppDimensions.md,
              AppDimensions.md,
              AppDimensions.md,
              AppDimensions.sm,
            ),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Search project…',
                prefixIcon: const Icon(Icons.search, size: 20),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                  borderSide: const BorderSide(color: AppColors.neutral100),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                  borderSide: const BorderSide(color: AppColors.neutral100),
                ),
              ),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(consumptionProjectsProvider);
                await ref.read(consumptionProjectsProvider.future);
              },
              child: _buildBody(async, items),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(
    AsyncValue<List<ConsumptionProject>> async,
    List<ConsumptionProject> items,
  ) {
    if (async.isLoading && items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (async.hasError && items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 80),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppDimensions.lg),
              child: Column(
                children: [
                  const Icon(Icons.error_outline,
                      size: 40, color: AppColors.error),
                  const SizedBox(height: AppDimensions.sm),
                  Text(
                    async.error.toString(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }
    if (items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 80),
          Center(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: AppDimensions.lg),
              child: Column(
                children: [
                  Icon(Icons.inventory_2_outlined,
                      size: 40, color: AppColors.textMuted),
                  SizedBox(height: AppDimensions.sm),
                  Text(
                    'No projects available for consumption.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        AppDimensions.md,
        AppDimensions.sm,
        AppDimensions.md,
        AppDimensions.lg,
      ),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppDimensions.sm),
      itemBuilder: (context, i) => _ProjectCard(project: items[i]),
    );
  }
}

class _ProjectCard extends StatelessWidget {
  final ConsumptionProject project;
  const _ProjectCard({required this.project});

  @override
  Widget build(BuildContext context) {
    final pct = (project.consumptionPct.clamp(0, 100)) / 100.0;

    return InkWell(
      onTap: () => context.push('/consumption/load/${project.projectId}'),
      borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
      child: Container(
        padding: const EdgeInsets.all(AppDimensions.md),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          border: Border.all(color: AppColors.neutral100),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    project.projectName.isEmpty ? '—' : project.projectName,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                if (project.draftCount > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.warningLight,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '${project.draftCount} draft${project.draftCount > 1 ? 's' : ''}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.warning,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                _Pill(
                  label: project.projectStatus ?? '—',
                  color: project.projectStatus == 'COMMENCED'
                      ? AppColors.success
                      : AppColors.info,
                ),
                if (project.categoryName != null) ...[
                  const SizedBox(width: 6),
                  _Pill(
                    label: project.categoryName!,
                    color: AppColors.steel,
                  ),
                ],
              ],
            ),
            const SizedBox(height: AppDimensions.sm),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: pct,
                minHeight: 6,
                backgroundColor: AppColors.neutral100,
                valueColor: AlwaysStoppedAnimation(
                  pct >= 0.95 ? AppColors.success : AppColors.terracotta,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${project.consumptionPct.toStringAsFixed(1)}% consumed',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                if (project.lastActivity != null)
                  Text(
                    'Last: ${DateFormat('MMM d, y').format(project.lastActivity!)}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final Color color;
  const _Pill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
