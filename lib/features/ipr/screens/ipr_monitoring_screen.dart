import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_client.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/widgets/app_back_button.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/ipr_models.dart';
import '../services/ipr_api.dart';
import 'ipr_status_pill.dart';

/// IPR → PO coverage monitoring with supplier/maker/search filters. Mirrors
/// the web mobile IprMonitoringScreen.
class IprMonitoringScreen extends ConsumerStatefulWidget {
  const IprMonitoringScreen({super.key});

  @override
  ConsumerState<IprMonitoringScreen> createState() =>
      _IprMonitoringScreenState();
}

class _IprMonitoringScreenState extends ConsumerState<IprMonitoringScreen> {
  final _searchCtl = TextEditingController();
  int? _supplierId;
  String _maker = '';
  IprMonitoringFilters? _filters;
  List<IprMonitoringRow> _rows = const [];
  IprMeta _meta = const IprMeta(total: 0, page: 1, perPage: 30, lastPage: 1);
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _searchCtl.dispose();
    super.dispose();
  }

  String? get _token => ref.read(authProvider).token;

  Future<void> _bootstrap() async {
    try {
      final f = await ref.read(iprApiProvider).monitoringFilters(token: _token);
      if (mounted) setState(() => _filters = f);
    } on ApiException {
      // Filters are optional — the list still works without them.
    }
    await _load();
  }

  Future<void> _load({int page = 1}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await ref.read(iprApiProvider).monitoring(
            search: _searchCtl.text.trim(),
            supplierId: _supplierId,
            maker: _maker,
            page: page,
            token: _token,
          );
      if (!mounted) return;
      setState(() {
        _rows = res.data;
        _meta = res.meta;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final f = _filters;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: const AppBackButton(),
        title: const Text('IPR monitoring'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppDimensions.md),
            child: Column(
              children: [
                TextField(
                  controller: _searchCtl,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _load(),
                  decoration: InputDecoration(
                    hintText: 'Search IPR / PO / project…',
                    prefixIcon: const Icon(Icons.search),
                    isDense: true,
                    filled: true,
                    fillColor: AppColors.surface,
                    border: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(AppDimensions.radiusMd),
                    ),
                  ),
                ),
                if (f != null) ...[
                  const SizedBox(height: AppDimensions.sm),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<int?>(
                          initialValue: _supplierId,
                          isExpanded: true,
                          decoration: const InputDecoration(
                              labelText: 'Supplier', isDense: true),
                          items: [
                            const DropdownMenuItem(
                                value: null, child: Text('All suppliers')),
                            for (final s in f.suppliers)
                              DropdownMenuItem(
                                  value: s.id,
                                  child: Text(s.name,
                                      overflow: TextOverflow.ellipsis)),
                          ],
                          onChanged: (v) {
                            setState(() => _supplierId = v);
                            _load();
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _maker,
                          isExpanded: true,
                          decoration: const InputDecoration(
                              labelText: 'Maker', isDense: true),
                          items: [
                            const DropdownMenuItem(
                                value: '', child: Text('All makers')),
                            for (final m in f.makers)
                              DropdownMenuItem(
                                  value: m,
                                  child: Text(m,
                                      overflow: TextOverflow.ellipsis)),
                          ],
                          onChanged: (v) {
                            setState(() => _maker = v ?? '');
                            _load();
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: _error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(AppDimensions.lg),
                      child: Text(_error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: AppColors.error)),
                    ),
                  )
                : _loading && _rows.isEmpty
                    ? const Center(child: CircularProgressIndicator())
                    : _rows.isEmpty
                        ? const Center(child: Text('No matching rows.'))
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(
                                AppDimensions.md, 0, AppDimensions.md,
                                AppDimensions.md),
                            itemCount: _rows.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: AppDimensions.sm),
                            itemBuilder: (context, i) =>
                                _MonRow(row: _rows[i]),
                          ),
          ),
          if (_meta.lastPage > 1)
            Padding(
              padding: const EdgeInsets.all(AppDimensions.sm),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton(
                    onPressed: _meta.page > 1 && !_loading
                        ? () => _load(page: _meta.page - 1)
                        : null,
                    child: const Text('← Prev'),
                  ),
                  Text('Page ${_meta.page} of ${_meta.lastPage}'),
                  TextButton(
                    onPressed: _meta.hasMore && !_loading
                        ? () => _load(page: _meta.page + 1)
                        : null,
                    child: const Text('Next →'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _MonRow extends StatelessWidget {
  final IprMonitoringRow row;
  const _MonRow({required this.row});

  String _fmt(double? v) => v == null
      ? '—'
      : (v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString());

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
      child: InkWell(
        onTap: () => context.push('/ipr/${row.requisitionId}'),
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(row.iprDocumentno,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 14)),
                  ),
                  IprStatusPill(status: row.iprStatus),
                ],
              ),
              const SizedBox(height: 2),
              Text(row.projectName ?? '—',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary)),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      row.poDocumentno != null
                          ? 'PO ${row.poDocumentno} · ${row.poStatus ?? ''}'
                          : 'No PO yet',
                      style: TextStyle(
                        fontSize: 12,
                        color: row.poDocumentno != null
                            ? AppColors.textPrimary
                            : AppColors.textMuted,
                      ),
                    ),
                  ),
                  Text('Ord ${_fmt(row.qtyOrdered)} / Rcv ${_fmt(row.qtyReceived)}',
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textSecondary)),
                ],
              ),
              if (row.supplierName != null || row.makerName != null) ...[
                const SizedBox(height: 4),
                Text(
                  [
                    if (row.supplierName != null) 'Supplier: ${row.supplierName}',
                    if (row.makerName != null) 'Maker: ${row.makerName}',
                  ].join('  ·  '),
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textMuted),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
