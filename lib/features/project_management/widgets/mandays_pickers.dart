import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../models/project_management_models.dart';
import '../services/project_management_api.dart';

/// Generic search-and-pick modal. Re-used by all three matching pickers
/// (project-stage, bpartner, account-pair) — each one supplies a typed
/// fetcher closure and an item builder.
class _SearchablePicker<T> extends StatefulWidget {
  final String title;
  final Future<List<T>> Function(String search) fetch;
  final Widget Function(BuildContext context, T item) itemBuilder;
  final String? Function(T item)? secondaryLabel;

  const _SearchablePicker({
    super.key,
    required this.title,
    required this.fetch,
    required this.itemBuilder,
    this.secondaryLabel,
  });

  @override
  State<_SearchablePicker<T>> createState() => _SearchablePickerState<T>();
}

class _SearchablePickerState<T> extends State<_SearchablePicker<T>> {
  final _controller = TextEditingController();
  Timer? _debounce;
  late Future<List<T>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.fetch('');
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      setState(() => _future = widget.fetch(v));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: SizedBox(
        width: 560,
        height: 540,
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: AppDimensions.sm),
              TextField(
                controller: _controller,
                onChanged: _onChanged,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search, size: 18),
                  hintText: 'Search',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: AppDimensions.sm),
              Expanded(
                child: FutureBuilder<List<T>>(
                  future: _future,
                  builder: (context, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snap.hasError) {
                      return Center(
                        child: Text(
                          'Could not load: ${snap.error}',
                          style: const TextStyle(color: AppColors.error),
                        ),
                      );
                    }
                    final items = snap.data ?? const [];
                    if (items.isEmpty) {
                      return const Center(
                        child: Text('No results.',
                            style: TextStyle(color: AppColors.textMuted)),
                      );
                    }
                    return ListView.separated(
                      itemCount: items.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, i) {
                        final item = items[i];
                        return InkWell(
                          onTap: () => Navigator.of(context).pop(item),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: AppDimensions.sm,
                                vertical: AppDimensions.sm),
                            child: widget.itemBuilder(context, item),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<MandaysStagePickerRow?> pickProjectStage(
  BuildContext context,
  ProjectManagementApi api, {
  String? token,
}) {
  return showDialog<MandaysStagePickerRow>(
    context: context,
    builder: (_) => _SearchablePicker<MandaysStagePickerRow>(
      title: 'Project · Scope · Stage',
      fetch: (q) => api.mandaysPickerStages(search: q, token: token),
      itemBuilder: (context, item) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.projectName.isEmpty
                  ? item.projectDocumentNo
                  : item.projectName,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            Text(
              '${item.scopeName} · ${item.stageName}',
              style: const TextStyle(
                  fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 2),
            Text(
              'LMC remaining: ₱${item.totalLmcRemaining.toStringAsFixed(2)} '
              '/ ₱${item.totalLmcBudget.toStringAsFixed(2)}',
              style:
                  const TextStyle(fontSize: 11, color: AppColors.textMuted),
            ),
          ],
        );
      },
    ),
  );
}

Future<MandaysBpartnerPickerRow?> pickBpartner(
  BuildContext context,
  ProjectManagementApi api, {
  String? token,
}) {
  return showDialog<MandaysBpartnerPickerRow>(
    context: context,
    builder: (_) => _SearchablePicker<MandaysBpartnerPickerRow>(
      title: 'Accountable Business Partner',
      fetch: (q) => api.mandaysPickerBpartners(search: q, token: token),
      itemBuilder: (context, item) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(item.name,
              style: const TextStyle(fontWeight: FontWeight.w600)),
          if (item.code.isNotEmpty)
            Text(item.code,
                style: const TextStyle(
                    fontSize: 11, color: AppColors.textMuted)),
          if (item.description.isNotEmpty)
            Text(item.description,
                style: const TextStyle(
                    fontSize: 11, color: AppColors.textSecondary)),
        ],
      ),
    ),
  );
}

Future<MandaysAcctPairPickerRow?> pickAcctPair(
  BuildContext context,
  ProjectManagementApi api, {
  String? token,
}) {
  return showDialog<MandaysAcctPairPickerRow>(
    context: context,
    builder: (_) => _SearchablePicker<MandaysAcctPairPickerRow>(
      title: 'Account Pair',
      fetch: (q) => api.mandaysPickerAcctPairs(search: q, token: token),
      itemBuilder: (context, item) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '[${item.acctCode}] ${item.acctName}',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          Text(
            '[${item.subacctCode}] ${item.subacctName}',
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
        ],
      ),
    ),
  );
}
