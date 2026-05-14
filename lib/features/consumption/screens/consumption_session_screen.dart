import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/consumption_models.dart';
import '../providers/consumption_provider.dart';

/// Either loads BOM lines fresh from ERP (when [projectId] is given) or
/// resumes an existing draft session (when [sessionId] is given).
class ConsumptionSessionScreen extends ConsumerStatefulWidget {
  final int? projectId;
  final int? sessionId;

  const ConsumptionSessionScreen({
    super.key,
    this.projectId,
    this.sessionId,
  }) : assert(projectId != null || sessionId != null,
            'projectId or sessionId required');

  @override
  ConsumerState<ConsumptionSessionScreen> createState() =>
      _ConsumptionSessionScreenState();
}

class _ConsumptionSessionScreenState
    extends ConsumerState<ConsumptionSessionScreen> {
  List<ConsumptionLine> _lines = const [];
  String _projectType = 'project';
  String _projectName = '';
  int? _wipProjectId;
  int? _sessionId;
  String _status = 'draft';
  String? _updatedBy;
  DateTime? _updatedAt;
  bool _saving = false;
  bool _posting = false;
  bool _bootstrapped = false;
  final _remarksController = TextEditingController();

  @override
  void dispose() {
    _remarksController.dispose();
    super.dispose();
  }

  void _hydrateFromBom(ConsumptionBomBundle bundle) {
    _wipProjectId = bundle.projectId;
    _projectName = bundle.projectName;
    _projectType = bundle.projectType;
    _lines = bundle.lines;
    _sessionId = null;
    _status = 'draft';
    _updatedBy = null;
    _updatedAt = null;
    _bootstrapped = true;
  }

  void _hydrateFromSession(ConsumptionSession session) {
    _wipProjectId = session.wipProjectId;
    _projectType = session.projectType;
    _lines = session.lines;
    _sessionId = session.id;
    _status = session.status;
    _updatedBy = session.updatedBy ?? session.createdBy;
    _updatedAt = session.updatedAt;
    _remarksController.text = session.remarks ?? '';
    _bootstrapped = true;
  }

  bool get _isPosted => _status == 'posted';

  Future<void> _saveDraft() async {
    if (_saving || _posting) return;
    setState(() => _saving = true);

    final api = ref.read(consumptionApiProvider);
    final token = ref.read(authProvider).token;
    final actor = ref.read(authProvider).user?.name;
    try {
      final remarks =
          _remarksController.text.trim().isEmpty ? null : _remarksController.text.trim();
      final session = _sessionId == null
          ? await api.createSession(
              wipProjectId: _wipProjectId,
              projectType: _projectType,
              remarks: remarks,
              updatedBy: actor,
              lines: _lines,
              token: token,
            )
          : await api.updateSession(
              _sessionId!,
              projectType: _projectType,
              remarks: remarks,
              updatedBy: actor,
              lines: _lines,
              token: token,
            );
      if (!mounted) return;
      setState(() {
        _sessionId = session.id;
        _status = session.status;
        _lines = session.lines;
        _updatedBy = session.updatedBy ?? session.createdBy;
        _updatedAt = session.updatedAt;
      });
      // If this was created from a project, future invalidation will refresh
      // the projects list (draft count + last activity).
      ref.invalidate(consumptionProjectsProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Draft saved.'),
          backgroundColor: AppColors.success,
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: AppColors.error),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _post() async {
    if (_saving || _posting) return;
    if (_sessionId == null) {
      // Force a draft save first so we have a session id to post.
      await _saveDraft();
      if (!mounted || _sessionId == null) return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Post session?'),
        content: const Text(
          'Posting will finalise quantities and create transfer records. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Post'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _posting = true);
    final api = ref.read(consumptionApiProvider);
    final token = ref.read(authProvider).token;
    final postedBy = ref.read(authProvider).user?.name ?? 'unknown';
    try {
      final session = await api.postSession(
        _sessionId!,
        postedBy: postedBy,
        token: token,
      );
      if (!mounted) return;
      setState(() {
        _status = session.status;
        _lines = session.lines;
      });
      ref.invalidate(consumptionProjectsProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Session posted.'),
          backgroundColor: AppColors.success,
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: AppColors.error),
      );
    } finally {
      if (mounted) setState(() => _posting = false);
    }
  }

  String _fmtTimestamp(DateTime d) {
    final local = d.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)} ${two(local.hour)}:${two(local.minute)}';
  }

  void _updateLine(int index, ConsumptionLine next) {
    setState(() {
      _lines = [
        for (var i = 0; i < _lines.length; i++)
          if (i == index) next else _lines[i],
      ];
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_bootstrapped) {
      final async = widget.sessionId != null
          ? ref.watch(consumptionSessionProvider(widget.sessionId!))
          : ref.watch(consumptionBomProvider(widget.projectId!));
      return Scaffold(
        appBar: AppBar(title: const Text('Consumption')),
        body: async.when(
          data: (data) {
            // Hydrate on next frame so setState happens outside build.
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              setState(() {
                if (data is ConsumptionBomBundle) {
                  _hydrateFromBom(data);
                } else if (data is ConsumptionSession) {
                  _hydrateFromSession(data);
                }
              });
            });
            return const Center(child: CircularProgressIndicator());
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(AppDimensions.lg),
              child: Text(
                e.toString(),
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.error),
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(_projectName.isEmpty ? 'Consumption' : _projectName),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: AppDimensions.md),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _isPosted
                      ? AppColors.successLight
                      : AppColors.warningLight,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  _isPosted ? 'POSTED' : 'DRAFT',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: _isPosted ? AppColors.success : AppColors.warning,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(AppDimensions.md),
              itemCount: _lines.length + 1,
              separatorBuilder: (_, _) =>
                  const SizedBox(height: AppDimensions.sm),
              itemBuilder: (context, i) {
                if (i == _lines.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: AppDimensions.md),
                    child: TextField(
                      controller: _remarksController,
                      enabled: !_isPosted,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: 'Session remarks',
                        filled: true,
                        fillColor: AppColors.surface,
                        border: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(AppDimensions.radiusMd),
                        ),
                      ),
                    ),
                  );
                }
                return _LineCard(
                  line: _lines[i],
                  readOnly: _isPosted,
                  onChanged: (updated) => _updateLine(i, updated),
                );
              },
            ),
          ),
          if (_updatedBy != null && _updatedBy!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppDimensions.md,
                0,
                AppDimensions.md,
                AppDimensions.sm,
              ),
              child: Row(
                children: [
                  const Icon(Icons.history,
                      size: 14, color: AppColors.textMuted),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _updatedAt != null
                          ? 'Last updated by $_updatedBy · ${_fmtTimestamp(_updatedAt!)}'
                          : 'Last updated by $_updatedBy',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (!_isPosted)
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(AppDimensions.md),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _saving || _posting ? null : _saveDraft,
                        icon: _saving
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.save_outlined),
                        label: const Text('Save Draft'),
                      ),
                    ),
                    const SizedBox(width: AppDimensions.sm),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _saving || _posting ? null : _post,
                        icon: _posting
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor:
                                      AlwaysStoppedAnimation(Colors.white),
                                ),
                              )
                            : const Icon(Icons.send),
                        label: const Text('Post'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _LineCard extends StatefulWidget {
  final ConsumptionLine line;
  final bool readOnly;
  final ValueChanged<ConsumptionLine> onChanged;

  const _LineCard({
    required this.line,
    required this.readOnly,
    required this.onChanged,
  });

  @override
  State<_LineCard> createState() => _LineCardState();
}

class _LineCardState extends State<_LineCard> {
  late final TextEditingController _loc;
  late final TextEditingController _consumed;
  late final TextEditingController _over;

  @override
  void initState() {
    super.initState();
    _loc = TextEditingController(text: _fmt(widget.line.locQty));
    _consumed = TextEditingController(text: _fmt(widget.line.consumedQty));
    _over = TextEditingController(text: _fmt(widget.line.overQty));
  }

  @override
  void didUpdateWidget(covariant _LineCard old) {
    super.didUpdateWidget(old);
    // Re-sync controllers if the parent replaced the line (e.g. after Save).
    if (widget.line.locQty != old.line.locQty) {
      _loc.text = _fmt(widget.line.locQty);
    }
    if (widget.line.consumedQty != old.line.consumedQty) {
      _consumed.text = _fmt(widget.line.consumedQty);
    }
    if (widget.line.overQty != old.line.overQty) {
      _over.text = _fmt(widget.line.overQty);
    }
  }

  @override
  void dispose() {
    _loc.dispose();
    _consumed.dispose();
    _over.dispose();
    super.dispose();
  }

  String _fmt(double v) {
    if (v == 0) return '';
    if (v == v.roundToDouble()) return v.toStringAsFixed(0);
    return v.toString();
  }

  double _parse(String s) => double.tryParse(s.trim()) ?? 0;

  void _emit({
    double? loc,
    double? consumed,
    double? over,
    String? mode,
    bool? done,
  }) {
    widget.onChanged(widget.line.copyWith(
      locQty: loc,
      consumedQty: consumed,
      overQty: over,
      mode: mode,
      isDone: done,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final line = widget.line;
    final isOver = line.mode == 'over_budget';
    return Container(
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  line.itemDescription,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Text(
                '${_fmt(line.bgtQty)} ${line.unit ?? ''} bgt',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
          if (line.skuCode != null && line.skuCode!.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              line.skuCode!,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
            ),
          ],
          const SizedBox(height: AppDimensions.sm),
          Row(
            children: [
              Expanded(
                child: _QtyField(
                  label: 'Loc qty',
                  controller: _loc,
                  enabled: !widget.readOnly,
                  onChanged: (v) => _emit(loc: _parse(v)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _QtyField(
                  label: 'Consumed',
                  controller: _consumed,
                  enabled: !widget.readOnly,
                  onChanged: (v) => _emit(consumed: _parse(v)),
                ),
              ),
              if (isOver) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: _QtyField(
                    label: 'Over',
                    controller: _over,
                    enabled: !widget.readOnly,
                    onChanged: (v) => _emit(over: _parse(v)),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: AppDimensions.sm),
          Row(
            children: [
              Expanded(
                child: SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'consumed', label: Text('Consumed')),
                    ButtonSegment(
                        value: 'over_budget', label: Text('Over budget')),
                  ],
                  selected: {line.mode},
                  onSelectionChanged: widget.readOnly
                      ? null
                      : (s) => _emit(mode: s.first),
                ),
              ),
              const SizedBox(width: 8),
              FilterChip(
                selected: line.isDone,
                label: const Text('Done'),
                onSelected:
                    widget.readOnly ? null : (v) => _emit(done: v),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QtyField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final bool enabled;
  final ValueChanged<String> onChanged;

  const _QtyField({
    required this.label,
    required this.controller,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      enabled: enabled,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
      ],
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
        ),
      ),
    );
  }
}
