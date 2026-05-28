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

/// Browsable list of IPRs (item purchase requisitions) with search + status
/// filter. Mirrors the web mobile IprListScreen.
class IprListScreen extends ConsumerStatefulWidget {
  const IprListScreen({super.key});

  @override
  ConsumerState<IprListScreen> createState() => _IprListScreenState();
}

class _IprListScreenState extends ConsumerState<IprListScreen> {
  final _searchCtl = TextEditingController();
  String _status = ''; // '' | 'DR' | 'PR'
  List<IprSummary> _rows = const [];
  IprMeta _meta = const IprMeta(total: 0, page: 1, perPage: 20, lastPage: 1);
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtl.dispose();
    super.dispose();
  }

  Future<void> _load({int page = 1}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await ref.read(iprApiProvider).list(
            search: _searchCtl.text.trim(),
            status: _status,
            page: page,
            token: ref.read(authProvider).token,
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
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: const AppBackButton(),
        title: const Text('IPR'),
        actions: [
          IconButton(
            tooltip: 'Monitoring',
            icon: const Icon(Icons.monitor_heart_outlined),
            onPressed: () => context.push('/ipr/monitoring'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/ipr/generate'),
        icon: const Icon(Icons.add),
        label: const Text('Generate'),
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
                    hintText: 'Search doc no. or project…',
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
                const SizedBox(height: AppDimensions.sm),
                Row(
                  children: [
                    for (final s in const [
                      ('', 'All'),
                      ('DR', 'Draft'),
                      ('PR', 'Posted'),
                    ])
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(s.$2),
                          selected: _status == s.$1,
                          onSelected: (_) {
                            setState(() => _status = s.$1);
                            _load();
                          },
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => _load(page: _meta.page),
              child: _error != null
                  ? ListView(children: [
                      Padding(
                        padding: const EdgeInsets.all(AppDimensions.lg),
                        child: Text(_error!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: AppColors.error)),
                      ),
                    ])
                  : _loading && _rows.isEmpty
                      ? const Center(child: CircularProgressIndicator())
                      : _rows.isEmpty
                          ? ListView(children: const [
                              Padding(
                                padding: EdgeInsets.all(AppDimensions.lg),
                                child: Center(child: Text('No IPRs found.')),
                              ),
                            ])
                          : ListView.separated(
                              padding: const EdgeInsets.fromLTRB(
                                  AppDimensions.md, 0, AppDimensions.md, 80),
                              itemCount: _rows.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: AppDimensions.sm),
                              itemBuilder: (context, i) =>
                                  _IprCard(row: _rows[i]),
                            ),
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

class _IprCard extends StatelessWidget {
  final IprSummary row;
  const _IprCard({required this.row});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
      child: InkWell(
        onTap: () => context.push('/ipr/${row.id}'),
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.md),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(row.documentno,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 14)),
                    const SizedBox(height: 2),
                    Text(row.projectName ?? '—',
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textSecondary)),
                    const SizedBox(height: 2),
                    Text('${row.lineCount} line${row.lineCount == 1 ? '' : 's'}',
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.textMuted)),
                  ],
                ),
              ),
              IprStatusPill(status: row.docstatus),
            ],
          ),
        ),
      ),
    );
  }
}
