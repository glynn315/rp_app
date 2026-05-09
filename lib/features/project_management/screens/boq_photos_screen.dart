import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../daily_work_report/services/daily_work_report_api.dart';
import '../../daily_work_report/theme/work_report_colors.dart';
import '../models/project_management_models.dart';
import '../widgets/boq_kind_chip.dart';

/// Manage expected-output reference images for a single BOQ line. Supervisor
/// uploads "what done looks like" shots; the field worker compares their
/// progress photo against these in the Log-Progress wizard.
class BoqPhotosScreen extends ConsumerStatefulWidget {
  final BoqItem? item;

  const BoqPhotosScreen({super.key, required this.item});

  @override
  ConsumerState<BoqPhotosScreen> createState() => _BoqPhotosScreenState();
}

class _BoqPhotosScreenState extends ConsumerState<BoqPhotosScreen> {
  final DailyWorkReportApi _api = DailyWorkReportApi();
  final TextEditingController _captionCtl = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  List<Map<String, dynamic>> _images = const [];
  bool _loading = false;
  bool _uploading = false;
  String? _error;

  BoqItem? get _item => widget.item;
  String get _boqItemId => _item?.lineId?.toString() ?? '';
  String get _boqLabel => _item?.itemLabel ?? '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  @override
  void dispose() {
    _captionCtl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (_boqItemId.isEmpty) {
      setState(() => _error = 'This BOQ line has no line_id — cannot attach images.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // Admin listing so a supervisor can see deactivated rows too.
      final list = await _api.adminListBoqOutputUploads(boqItemId: _boqItemId);
      if (!mounted) return;
      setState(() {
        _images = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Failed to load images: $e';
      });
    }
  }

  Future<void> _pickAndUpload(ImageSource source) async {
    if (_boqItemId.isEmpty) return;
    XFile? picked;
    try {
      picked = await _picker.pickImage(source: source, maxWidth: 2048, imageQuality: 85);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Could not open image source: $e');
      return;
    }
    if (picked == null) return;

    setState(() {
      _uploading = true;
      _error = null;
    });
    try {
      final caption = _captionCtl.text.trim();
      await _api.createBoqOutputUpload(
        file: picked,
        boqItemId: _boqItemId,
        boqLabel: _boqLabel,
        caption: caption.isEmpty ? null : caption,
      );
      if (!mounted) return;
      _captionCtl.clear();
      setState(() => _uploading = false);
      await _load();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _uploading = false;
        _error = 'Upload failed: $e';
      });
    }
  }

  Future<void> _showSourceSheet() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source != null) _pickAndUpload(source);
  }

  Future<void> _confirmDelete(Map<String, dynamic> row) async {
    final id = row['id']?.toString() ?? '';
    if (id.isEmpty) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remove image?'),
        content: const Text(
          'This hides the reference image from the field worker. '
          'The file is kept on disk and can be re-enabled later.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: WorkReportColors.danger),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _api.deleteBoqOutputUpload(id: id);
      await _load();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Delete failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Expected output images'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppDimensions.md),
        children: _buildBody(),
      ),
    );
  }

  List<Widget> _buildBody() {
    final item = _item;
    if (item == null) {
      return const [
        SizedBox(height: 64),
        Icon(Icons.image_not_supported, size: 56, color: AppColors.textMuted),
        SizedBox(height: 12),
        Text(
          'No BOQ line selected',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
      ];
    }

    return [
      _ScopeHeader(item: item),
      const SizedBox(height: AppDimensions.md),
      _AddImageCard(
        captionCtl: _captionCtl,
        uploading: _uploading,
        onPick: _showSourceSheet,
      ),
      if (_error != null) ...[
        const SizedBox(height: AppDimensions.sm),
        _ErrorBanner(message: _error!),
      ],
      const SizedBox(height: AppDimensions.md),
      const _SectionLabel('EXISTING IMAGES'),
      const SizedBox(height: 8),
      if (_loading)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Center(child: CircularProgressIndicator()),
        )
      else if (_images.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Center(
            child: Text(
              'No images yet — add one above.',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textMuted.withValues(alpha: 0.9),
              ),
            ),
          ),
        )
      else
        ..._images.map((row) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _ImageRow(row: row, onDelete: () => _confirmDelete(row)),
            )),
      const SizedBox(height: AppDimensions.lg),
    ];
  }
}

class _ScopeHeader extends StatelessWidget {
  final BoqItem item;

  const _ScopeHeader({required this.item});

  @override
  Widget build(BuildContext context) {
    final headline = item.itemLabel.isNotEmpty
        ? item.itemLabel
        : (item.scopeName.isNotEmpty ? item.scopeName : item.projectName);
    final sub = [item.scopeName, item.stageName]
        .where((s) => s.isNotEmpty)
        .join(' · ');

    return Container(
      width: double.infinity,
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
              BoqKindChip(kind: item.lineKind),
              const SizedBox(width: AppDimensions.xs),
              Expanded(
                child: Text(
                  headline,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          if (sub.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              sub,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textMuted,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.4,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AddImageCard extends StatelessWidget {
  final TextEditingController captionCtl;
  final bool uploading;
  final VoidCallback onPick;

  const _AddImageCard({
    required this.captionCtl,
    required this.uploading,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        border: Border.all(color: AppColors.neutral100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'ADD A REFERENCE IMAGE',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: AppColors.textMuted,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: captionCtl,
            maxLength: 255,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              hintText: 'Caption (optional) — e.g. front view, after curing',
              counterText: '',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: uploading ? null : onPick,
            style: FilledButton.styleFrom(
              backgroundColor: WorkReportColors.terracotta,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(44),
            ),
            icon: uploading
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.add_a_photo, size: 18),
            label: Text(uploading ? 'Uploading…' : 'Add image'),
          ),
        ],
      ),
    );
  }
}

class _ImageRow extends StatelessWidget {
  final Map<String, dynamic> row;
  final VoidCallback onDelete;

  const _ImageRow({required this.row, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final url = row['image_url']?.toString() ?? '';
    final caption = row['caption']?.toString() ?? '';
    final isActive = row['is_active'] == true;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.neutral100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
            child: AspectRatio(
              aspectRatio: 16 / 10,
              child: url.isEmpty
                  ? Container(color: AppColors.neutral100)
                  : Image.network(
                      url,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(
                        color: AppColors.neutral100,
                        alignment: Alignment.center,
                        child: const Icon(Icons.broken_image,
                            color: AppColors.textMuted),
                      ),
                    ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    caption.isEmpty ? '(no caption)' : caption,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isActive
                          ? AppColors.textPrimary
                          : AppColors.textMuted,
                      fontStyle:
                          caption.isEmpty ? FontStyle.italic : FontStyle.normal,
                    ),
                  ),
                ),
                if (!isActive)
                  Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.neutral100,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'INACTIVE',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textMuted,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20),
                  color: WorkReportColors.danger,
                  onPressed: onDelete,
                  tooltip: 'Remove',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        color: AppColors.textMuted,
        letterSpacing: 1.0,
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;

  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: WorkReportColors.danger.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, size: 14, color: WorkReportColors.danger),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: WorkReportColors.danger, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
