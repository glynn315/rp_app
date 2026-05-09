import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/work_report_models.dart';
import '../providers/work_report_provider.dart';
import '../theme/work_report_colors.dart';

class UnmatchedList extends ConsumerWidget {
  final String employeeId;
  final String contractType;
  const UnmatchedList({super.key, required this.employeeId, required this.contractType});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(calendarProvider);
    if (state.unmatchedDates.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 32),
        child: Center(
          child: Text(
            'No unmatched days. Nice work!',
            style: TextStyle(color: WorkReportColors.stone, fontWeight: FontWeight.w600),
          ),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: state.unmatchedDates.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, idx) {
        final date = state.unmatchedDates[idx];
        return _UnmatchedRow(
          date: date,
          contractType: contractType,
          employeeId: employeeId,
        );
      },
    );
  }
}

class _UnmatchedRow extends ConsumerStatefulWidget {
  final String date;
  final String contractType;
  final String employeeId;
  const _UnmatchedRow({required this.date, required this.contractType, required this.employeeId});

  @override
  ConsumerState<_UnmatchedRow> createState() => _UnmatchedRowState();
}

class _UnmatchedRowState extends ConsumerState<_UnmatchedRow> {
  String _tagType = '';
  LookupOption? _selected;
  List<LookupOption> _options = const [];
  bool _loading = false;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tagType = FeatureFlags.tagTypesFor(widget.contractType).first;
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadOptions());
  }

  Future<void> _loadOptions() async {
    setState(() => _loading = true);
    try {
      final list = await ref
          .read(lookupProvider.notifier)
          .options(contractType: widget.contractType, tagType: _tagType);
      if (!mounted) return;
      setState(() {
        _options = list;
        if (_selected == null && list.isNotEmpty) _selected = list.first;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Failed to load options.';
      });
    }
  }

  Future<void> _save() async {
    final selected = _selected;
    if (selected == null) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(calendarProvider.notifier).lateMatch(
            employeeId: widget.employeeId,
            date: widget.date,
            tagType: _tagType,
            tagId: selected.id,
            tagLabel: selected.name,
          );
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    }
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final tagOptions = FeatureFlags.tagTypesFor(widget.contractType);

    final dt = DateTime.parse(widget.date);
    final label = DateFormat('EEE, MMM d').format(dt);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: WorkReportColors.terracotta.withValues(alpha: 0.06),
        border: Border.all(color: WorkReportColors.terracotta.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.history, color: WorkReportColors.terracotta, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: WorkReportColors.charcoal,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: tagOptions.map((t) {
              final selected = _tagType == t;
              return GestureDetector(
                onTap: () {
                  if (_tagType == t) return;
                  setState(() {
                    _tagType = t;
                    _selected = null;
                    _options = const [];
                  });
                  _loadOptions();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: selected ? WorkReportColors.midnight : Colors.white,
                    border: Border.all(color: WorkReportColors.midnight),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    TagType.labelFor(t),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: selected ? Colors.white : WorkReportColors.midnight,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
          if (_loading)
            const LinearProgressIndicator(minHeight: 2)
          else
            DropdownButtonFormField<LookupOption>(
              initialValue: _selected,
              isExpanded: true,
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
              items: _options
                  .map((o) => DropdownMenuItem(value: o, child: Text(o.name, overflow: TextOverflow.ellipsis)))
                  .toList(),
              onChanged: (v) => setState(() => _selected = v),
            ),
          if (_error != null) ...[
            const SizedBox(height: 6),
            Text(_error!, style: const TextStyle(color: WorkReportColors.danger, fontSize: 12)),
          ],
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: WorkReportColors.terracotta,
                foregroundColor: Colors.white,
                minimumSize: const Size(120, 36),
              ),
              onPressed: _saving || _selected == null ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Match'),
            ),
          ),
        ],
      ),
    );
  }
}
