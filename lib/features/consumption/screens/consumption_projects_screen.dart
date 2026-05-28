import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/widgets/app_back_button.dart';
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
    final categories =
        ref.watch(consumptionCategoriesProvider).value ?? const [];
    final activeCategory = ref.watch(consumptionCategoryFilterProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      drawer: const AppDrawer(),
      appBar: AppBar(
        leading: const AppBackButton(),
        title: const Text('Consumption'),
        actions: [
          // Drawer remains reachable via swipe-from-edge; we surface it as
          // an explicit action too so users on platforms without that
          // gesture can still switch sections from this top-level page.
          Builder(
            builder: (innerContext) => IconButton(
              tooltip: 'Open menu',
              icon: const Icon(Icons.menu),
              onPressed: () => Scaffold.of(innerContext).openDrawer(),
            ),
          ),
          IconButton(
            tooltip: 'Browse sessions',
            icon: const Icon(Icons.history),
            onPressed: () => context.push('/consumption/sessions'),
          ),
        ],
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
          if (categories.isNotEmpty)
            _CategoryChipsRow(
              categories: categories,
              active: activeCategory,
              onChanged: (name) => ref
                  .read(consumptionCategoryFilterProvider.notifier)
                  .state = name,
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

/// Horizontal scrollable chip row for category filtering. First chip is
/// always "All" (null filter); the rest map to backend category names.
class _CategoryChipsRow extends StatelessWidget {
  final List<ConsumptionCategory> categories;
  final String? active;
  final ValueChanged<String?> onChanged;

  const _CategoryChipsRow({
    required this.categories,
    required this.active,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(
          AppDimensions.md,
          0,
          AppDimensions.md,
          AppDimensions.sm,
        ),
        itemCount: categories.length + 1,
        separatorBuilder: (_, _) => const SizedBox(width: 6),
        itemBuilder: (context, i) {
          if (i == 0) {
            return _Chip(
              label: 'All',
              selected: active == null,
              onTap: () => onChanged(null),
            );
          }
          final c = categories[i - 1];
          return _Chip(
            label: c.name,
            selected: active == c.name,
            onTap: () => onChanged(c.name),
          );
        },
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.neutral200,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? AppColors.textOnPrimary : AppColors.textSecondary,
          ),
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
