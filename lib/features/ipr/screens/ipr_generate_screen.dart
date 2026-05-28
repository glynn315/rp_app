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

/// Pick an eligible project (has un-requisitioned BOM lines) and generate a
/// draft IPR for it. Mirrors the web mobile IprGenerateScreen.
class IprGenerateScreen extends ConsumerStatefulWidget {
  const IprGenerateScreen({super.key});

  @override
  ConsumerState<IprGenerateScreen> createState() => _IprGenerateScreenState();
}

class _IprGenerateScreenState extends ConsumerState<IprGenerateScreen> {
  final _searchCtl = TextEditingController();
  List<EligibleProject> _projects = const [];
  bool _loading = true;
  int? _generatingId;
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

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await ref.read(iprApiProvider).eligibleProjects(
            search: _searchCtl.text.trim(),
            token: ref.read(authProvider).token,
          );
      if (!mounted) return;
      setState(() {
        _projects = list;
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

  Future<void> _generate(EligibleProject p) async {
    setState(() => _generatingId = p.wipProjectId);
    try {
      final detail = await ref.read(iprApiProvider).generate(
            p.wipProjectId,
            postedBy: ref.read(authProvider).user?.name,
            token: ref.read(authProvider).token,
          );
      if (!mounted) return;
      // Replace so Back returns to the list, not this generate screen.
      context.pushReplacement('/ipr/${detail.ipr.id}');
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _generatingId = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: AppColors.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: const AppBackButton(),
        title: const Text('Generate IPR'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppDimensions.md),
            child: TextField(
              controller: _searchCtl,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _load(),
              decoration: InputDecoration(
                hintText: 'Search project…',
                prefixIcon: const Icon(Icons.search),
                isDense: true,
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                ),
              ),
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
                : _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _projects.isEmpty
                        ? const Center(
                            child: Text('No projects with lines to requisition.'))
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(
                                AppDimensions.md, 0, AppDimensions.md,
                                AppDimensions.md),
                            itemCount: _projects.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: AppDimensions.sm),
                            itemBuilder: (context, i) {
                              final p = _projects[i];
                              final busy = _generatingId == p.wipProjectId;
                              return Material(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(
                                    AppDimensions.radiusMd),
                                child: InkWell(
                                  onTap: _generatingId != null
                                      ? null
                                      : () => _generate(p),
                                  borderRadius: BorderRadius.circular(
                                      AppDimensions.radiusMd),
                                  child: Padding(
                                    padding:
                                        const EdgeInsets.all(AppDimensions.md),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(p.projectName,
                                                  style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      fontSize: 14)),
                                              const SizedBox(height: 2),
                                              Text(
                                                  '${p.linesToReq} line${p.linesToReq == 1 ? '' : 's'} to requisition · ${p.projectStatus}',
                                                  style: const TextStyle(
                                                      fontSize: 12,
                                                      color: AppColors
                                                          .textSecondary)),
                                            ],
                                          ),
                                        ),
                                        busy
                                            ? const SizedBox(
                                                width: 18,
                                                height: 18,
                                                child:
                                                    CircularProgressIndicator(
                                                        strokeWidth: 2))
                                            : const Icon(Icons.chevron_right,
                                                color: AppColors.textMuted),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}
