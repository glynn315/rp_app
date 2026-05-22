import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../models/project_management_models.dart';
import '../providers/project_management_provider.dart';

/// Per-screen filter controls. Each screen declares which controls apply
/// (BOQ has no date range; WIP has a status pill and a date range; LMC has
/// a docstatus pill and a date range).
class ProjectFilterBar extends ConsumerWidget {
  final StateNotifierProvider<ProjectListFilterController,
      ProjectListFilter> filterProvider;
  final List<FilterOption>? statusOptions;
  final bool showDateRange;
  final bool showProjectPicker;
  final String searchHint;

  const ProjectFilterBar({
    super.key,
    required this.filterProvider,
    this.statusOptions,
    this.showDateRange = true,
    this.showProjectPicker = true,
    this.searchHint = 'Search…',
  });

  static const boqStatusOptions = <FilterOption>[
    FilterOption('BUDGETING', 'Budgeting'),
    FilterOption('COMMENCED', 'Commenced'),
    FilterOption('FORCLOSURE', 'Foreclosure'),
  ];

  static const wipStatusOptions = <FilterOption>[
    FilterOption('COMMENCED', 'Commenced'),
    FilterOption('BUDGETING', 'Budgeting'),
    FilterOption('FORCLOSURE', 'Foreclosure'),
  ];

  static const lmcDocstatusOptions = <FilterOption>[
    FilterOption('DR', 'Draft'),
    FilterOption('PR', 'Processed'),
    FilterOption('VO', 'Voided'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(filterProvider);
    final notifier = ref.read(filterProvider.notifier);

    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppDimensions.md,
        AppDimensions.sm,
        AppDimensions.md,
        AppDimensions.sm,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(
          bottom: BorderSide(color: AppColors.neutral100),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _SearchField(
                  hint: searchHint,
                  filterProvider: filterProvider,
                ),
              ),
              const SizedBox(width: AppDimensions.sm),
              _FiltersButton(
                activeCount: _countActive(filter, includeSearch: false),
                onPressed: () => _openSheet(context, ref),
              ),
            ],
          ),
          if (filter.isActive) ...[
            const SizedBox(height: AppDimensions.xs),
            _ActiveChips(
              filter: filter,
              statusOptions: statusOptions,
              notifier: notifier,
              ref: ref,
            ),
          ],
        ],
      ),
    );
  }

  int _countActive(ProjectListFilter f, {required bool includeSearch}) {
    var n = 0;
    if (includeSearch && f.search.isNotEmpty) n++;
    if (f.projectId != null) n++;
    if ((f.status ?? '').isNotEmpty) n++;
    if (f.dateFrom != null) n++;
    if (f.dateTo != null) n++;
    return n;
  }

  Future<void> _openSheet(BuildContext context, WidgetRef ref) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppDimensions.radiusLg),
        ),
      ),
      builder: (sheetCtx) {
        return _FilterSheet(
          filterProvider: filterProvider,
          statusOptions: statusOptions,
          showDateRange: showDateRange,
          showProjectPicker: showProjectPicker,
        );
      },
    );
  }
}

/// Self-contained search field. Owns its own controller and debounces user
/// input by 300ms before pushing to the filter notifier — the previous design
/// re-synced the controller from `widget.initial` on every parent rebuild,
/// which raced with fast typing and could clobber characters or jump the
/// cursor mid-type. Now external resets (chip clear, sheet reset) flow back
/// in via `ref.listen`, only updating the controller when the values truly
/// diverge.
class _SearchField extends ConsumerStatefulWidget {
  final String hint;
  final StateNotifierProvider<ProjectListFilterController, ProjectListFilter>
      filterProvider;

  const _SearchField({
    required this.hint,
    required this.filterProvider,
  });

  @override
  ConsumerState<_SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends ConsumerState<_SearchField> {
  late final TextEditingController _ctrl;
  Timer? _debounce;

  static const _debounceWindow = Duration(milliseconds: 300);

  @override
  void initState() {
    super.initState();
    final initial = ref.read(widget.filterProvider).search;
    _ctrl = TextEditingController(text: initial);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  void _onLocalChange(String v) {
    // Refresh the suffix-icon visibility synchronously, but defer the
    // provider mutation so a burst of keystrokes only fires one fetch.
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(_debounceWindow, () {
      if (!mounted) return;
      ref.read(widget.filterProvider.notifier).setSearch(_ctrl.text);
    });
  }

  void _clear() {
    _debounce?.cancel();
    _ctrl.clear();
    ref.read(widget.filterProvider.notifier).setSearch('');
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    // Sync external resets (e.g. the "Clear" button on active filter chips,
    // or the sheet's Reset+Apply path) back into the controller — only when
    // they actually differ, to avoid trampling the user's in-progress text.
    ref.listen<ProjectListFilter>(widget.filterProvider, (_, next) {
      if (next.search != _ctrl.text) {
        _ctrl.value = TextEditingValue(
          text: next.search,
          selection: TextSelection.collapsed(offset: next.search.length),
        );
      }
    });

    return TextField(
      controller: _ctrl,
      onChanged: _onLocalChange,
      textInputAction: TextInputAction.search,
      style: const TextStyle(fontSize: 14),
      decoration: InputDecoration(
        prefixIcon: const Icon(Icons.search, size: 18),
        hintText: widget.hint,
        hintStyle: const TextStyle(fontSize: 13, color: AppColors.textMuted),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 10),
        filled: true,
        fillColor: AppColors.background,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
          borderSide: BorderSide.none,
        ),
        suffixIcon: _ctrl.text.isEmpty
            ? null
            : IconButton(
                icon: const Icon(Icons.close, size: 16),
                onPressed: _clear,
              ),
      ),
    );
  }
}

class _FiltersButton extends StatelessWidget {
  final int activeCount;
  final VoidCallback onPressed;

  const _FiltersButton({required this.activeCount, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
      onTap: onPressed,
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: activeCount > 0 ? AppColors.primary : AppColors.background,
          borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
          border: Border.all(color: AppColors.neutral100),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.tune,
              size: 16,
              color: activeCount > 0
                  ? AppColors.textOnPrimary
                  : AppColors.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              activeCount > 0 ? 'Filters · $activeCount' : 'Filters',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: activeCount > 0
                    ? AppColors.textOnPrimary
                    : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActiveChips extends StatelessWidget {
  final ProjectListFilter filter;
  final List<FilterOption>? statusOptions;
  final ProjectListFilterController notifier;
  final WidgetRef ref;

  const _ActiveChips({
    required this.filter,
    required this.statusOptions,
    required this.notifier,
    required this.ref,
  });

  @override
  Widget build(BuildContext context) {
    final n = notifier;
    final fmt = DateFormat('MMM d');
    final chips = <Widget>[];

    if (filter.projectId != null) {
      final proj = ref
          .watch(projectLookupProvider)
          .value
          ?.firstWhere(
            (p) => p.projectId == filter.projectId,
            orElse: () => ProjectLookup(
              projectId: filter.projectId,
              projectName: 'Project ${filter.projectId}',
              projectDocumentNo: '',
              projectStatus: '',
            ),
          );
      chips.add(_chip(
        label: proj?.projectName.isNotEmpty == true
            ? proj!.projectName
            : 'Project ${filter.projectId}',
        onClear: () => n.setProjectId(null),
      ));
    }
    if ((filter.status ?? '').isNotEmpty) {
      final opts = statusOptions ?? const <FilterOption>[];
      final m = opts.firstWhere(
        (o) => o.value == filter.status,
        orElse: () => FilterOption(filter.status!, filter.status!),
      );
      chips.add(_chip(label: m.label, onClear: () => n.setStatus(null)));
    }
    if (filter.dateFrom != null) {
      chips.add(_chip(
        label: 'From ${fmt.format(filter.dateFrom!)}',
        onClear: () => n.setDateFrom(null),
      ));
    }
    if (filter.dateTo != null) {
      chips.add(_chip(
        label: 'To ${fmt.format(filter.dateTo!)}',
        onClear: () => n.setDateTo(null),
      ));
    }
    if (chips.isEmpty) return const SizedBox.shrink();

    chips.add(
      TextButton.icon(
        onPressed: () => n.reset(),
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          visualDensity: VisualDensity.compact,
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        icon: const Icon(Icons.clear_all, size: 14),
        label: const Text('Clear', style: TextStyle(fontSize: 12)),
      ),
    );

    return Wrap(spacing: 6, runSpacing: 6, children: chips);
  }

  Widget _chip({required String label, required VoidCallback onClear}) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 4, 4, 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 2),
          InkWell(
            onTap: onClear,
            borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
            child: const Padding(
              padding: EdgeInsets.all(2),
              child: Icon(Icons.close, size: 12, color: AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterSheet extends ConsumerStatefulWidget {
  final StateNotifierProvider<ProjectListFilterController,
      ProjectListFilter> filterProvider;
  final List<FilterOption>? statusOptions;
  final bool showDateRange;
  final bool showProjectPicker;

  const _FilterSheet({
    required this.filterProvider,
    required this.statusOptions,
    required this.showDateRange,
    required this.showProjectPicker,
  });

  @override
  ConsumerState<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends ConsumerState<_FilterSheet> {
  late ProjectListFilter _draft;

  @override
  void initState() {
    super.initState();
    _draft = ref.read(widget.filterProvider);
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('MMM d, yyyy');
    final mq = MediaQuery.of(context);
    return Padding(
      padding: EdgeInsets.only(
        bottom: mq.viewInsets.bottom,
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppDimensions.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Text(
                    'Filter',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () {
                      setState(() => _draft = ProjectListFilter.empty);
                    },
                    child: const Text('Reset'),
                  ),
                ],
              ),
              if (widget.showProjectPicker) ...[
                const SizedBox(height: AppDimensions.xs),
                _SectionLabel('Project'),
                _ProjectPickerField(
                  value: _draft.projectId,
                  onChanged: (id) => setState(
                    () => _draft = _draft.copyWith(projectId: id),
                  ),
                ),
              ],
              if (widget.statusOptions != null) ...[
                const SizedBox(height: AppDimensions.md),
                _SectionLabel('Status'),
                _ChipGroup(
                  options: widget.statusOptions!,
                  selected: _draft.status,
                  onChanged: (v) => setState(
                    () => _draft = _draft.copyWith(status: v),
                  ),
                ),
              ],
              if (widget.showDateRange) ...[
                const SizedBox(height: AppDimensions.md),
                _SectionLabel('Date range'),
                Row(
                  children: [
                    Expanded(
                      child: _DateField(
                        label: 'From',
                        value: _draft.dateFrom,
                        formatter: fmt,
                        onChanged: (d) => setState(
                          () => _draft = _draft.copyWith(dateFrom: d),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppDimensions.sm),
                    Expanded(
                      child: _DateField(
                        label: 'To',
                        value: _draft.dateTo,
                        formatter: fmt,
                        onChanged: (d) => setState(
                          () => _draft = _draft.copyWith(dateTo: d),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: AppDimensions.lg),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: AppDimensions.sm),
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        final n = ref.read(widget.filterProvider.notifier);
                        // Apply each draft field via the controller setters so
                        // the controller stays the single source of truth.
                        n.setProjectId(_draft.projectId);
                        n.setStatus(_draft.status);
                        n.setDateFrom(_draft.dateFrom);
                        n.setDateTo(_draft.dateTo);
                        Navigator.of(context).pop();
                      },
                      child: const Text('Apply'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimensions.xs),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _ChipGroup extends StatelessWidget {
  final List<FilterOption> options;
  final String? selected;
  final ValueChanged<String?> onChanged;

  const _ChipGroup({
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: options.map((o) {
        final active = o.value == selected;
        return ChoiceChip(
          label: Text(o.label, style: const TextStyle(fontSize: 12)),
          selected: active,
          onSelected: (_) => onChanged(active ? null : o.value),
          selectedColor: AppColors.primary,
          backgroundColor: AppColors.background,
          labelStyle: TextStyle(
            color: active ? AppColors.textOnPrimary : AppColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
            side: BorderSide(
              color: active ? AppColors.primary : AppColors.neutral100,
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _DateField extends StatelessWidget {
  final String label;
  final DateTime? value;
  final DateFormat formatter;
  final ValueChanged<DateTime?> onChanged;

  const _DateField({
    required this.label,
    required this.value,
    required this.formatter,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final text = value == null ? label : formatter.format(value!);
    return InkWell(
      borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
      onTap: () async {
        final now = DateTime.now();
        final picked = await showDatePicker(
          context: context,
          initialDate: value ?? now,
          firstDate: DateTime(now.year - 5),
          lastDate: DateTime(now.year + 2),
        );
        if (picked != null) onChanged(picked);
      },
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
          border: Border.all(color: AppColors.neutral100),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today,
                size: 14, color: AppColors.textMuted),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 13,
                  color: value == null
                      ? AppColors.textMuted
                      : AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (value != null)
              InkWell(
                onTap: () => onChanged(null),
                child: const Padding(
                  padding: EdgeInsets.all(2),
                  child:
                      Icon(Icons.close, size: 14, color: AppColors.textMuted),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ProjectPickerField extends ConsumerWidget {
  final int? value;
  final ValueChanged<int?> onChanged;

  const _ProjectPickerField({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(projectLookupProvider);
    final projects = async.value ?? const <ProjectLookup>[];
    final selected = value == null
        ? null
        : projects.firstWhere(
            (p) => p.projectId == value,
            orElse: () => ProjectLookup(
              projectId: value,
              projectName: 'Project $value',
              projectDocumentNo: '',
              projectStatus: '',
            ),
          );

    return InkWell(
      borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
      onTap: () async {
        final picked = await showModalBottomSheet<ProjectLookup?>(
          context: context,
          isScrollControlled: true,
          backgroundColor: AppColors.surface,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(AppDimensions.radiusLg),
            ),
          ),
          builder: (_) => _ProjectPickerSheet(initial: value),
        );
        // Distinguish "user cleared" from "user dismissed without picking":
        // we explicitly pop with `null` from the Clear button below, so accept
        // pop-without-result as "no change" by checking the result type.
        if (picked != null) {
          onChanged(picked.projectId);
        }
      },
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
          border: Border.all(color: AppColors.neutral100),
        ),
        child: Row(
          children: [
            const Icon(Icons.work_outline,
                size: 16, color: AppColors.textMuted),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                async.isLoading && projects.isEmpty
                    ? 'Loading projects…'
                    : (selected?.label ?? 'All projects'),
                style: TextStyle(
                  fontSize: 13,
                  color: selected == null
                      ? AppColors.textMuted
                      : AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (selected != null)
              InkWell(
                onTap: () => onChanged(null),
                child: const Padding(
                  padding: EdgeInsets.all(2),
                  child:
                      Icon(Icons.close, size: 14, color: AppColors.textMuted),
                ),
              )
            else
              const Icon(Icons.expand_more,
                  size: 18, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}

class _ProjectPickerSheet extends ConsumerStatefulWidget {
  final int? initial;
  const _ProjectPickerSheet({required this.initial});

  @override
  ConsumerState<_ProjectPickerSheet> createState() =>
      _ProjectPickerSheetState();
}

class _ProjectPickerSheetState extends ConsumerState<_ProjectPickerSheet> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(projectLookupProvider);
    final all = async.value ?? const <ProjectLookup>[];
    final filtered = _search.isEmpty
        ? all
        : all.where((p) {
            final s = _search.toLowerCase();
            return p.projectName.toLowerCase().contains(s) ||
                p.projectDocumentNo.toLowerCase().contains(s);
          }).toList();

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      builder: (context, scrollCtl) {
        return Padding(
          padding: const EdgeInsets.all(AppDimensions.md),
          child: Column(
            children: [
              const Text(
                'Pick a project',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: AppDimensions.sm),
              TextField(
                onChanged: (v) => setState(() => _search = v),
                style: const TextStyle(fontSize: 14),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search, size: 18),
                  hintText: 'Search projects…',
                  hintStyle:
                      const TextStyle(fontSize: 13, color: AppColors.textMuted),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  filled: true,
                  fillColor: AppColors.background,
                  border: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(AppDimensions.radiusSm),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: AppDimensions.sm),
              Expanded(
                child: async.isLoading && all.isEmpty
                    ? const Center(child: CircularProgressIndicator())
                    : async.hasError
                        ? Center(
                            child: Text(
                              'Could not load projects: ${async.error}',
                              style: const TextStyle(color: AppColors.error),
                            ),
                          )
                        : ListView.separated(
                            controller: scrollCtl,
                            itemCount: filtered.length,
                            separatorBuilder: (_, _) => const Divider(
                              height: 1,
                              color: AppColors.neutral100,
                            ),
                            itemBuilder: (context, i) {
                              final p = filtered[i];
                              final picked = p.projectId == widget.initial;
                              return ListTile(
                                dense: true,
                                title: Text(
                                  p.projectName.isEmpty
                                      ? (p.projectDocumentNo.isEmpty
                                          ? '—'
                                          : p.projectDocumentNo)
                                      : p.projectName,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                subtitle: p.projectDocumentNo.isEmpty
                                    ? null
                                    : Text(
                                        p.projectDocumentNo,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: AppColors.textMuted,
                                        ),
                                      ),
                                trailing: picked
                                    ? const Icon(Icons.check,
                                        color: AppColors.primary, size: 18)
                                    : null,
                                onTap: () => Navigator.of(context).pop(p),
                              );
                            },
                          ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class FilterOption {
  final String value;
  final String label;
  const FilterOption(this.value, this.label);
}
