import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../models/work_report_models.dart';
import '../providers/work_report_provider.dart';
import '../theme/work_report_colors.dart';

/// Shared form fields used by both the Add and Edit block forms.
class BlockFormFields extends ConsumerStatefulWidget {
  final String contractType;
  /// When editing, the existing block. Null for create.
  final WorkBlock? initial;
  final String submitLabel;
  final void Function(WorkBlock candidate) onSubmit;
  final VoidCallback? onCancel;
  /// Pre-fill values for create flow (not used when [initial] is supplied).
  final String? defaultTimeIn;
  final String? defaultTimeOut;
  final String? errorMessage;
  /// When true the tag-type pill row is disabled (block already exists,
  /// changing tag type is forbidden by the spec).
  final bool lockTagType;

  const BlockFormFields({
    super.key,
    required this.contractType,
    required this.submitLabel,
    required this.onSubmit,
    this.initial,
    this.onCancel,
    this.defaultTimeIn,
    this.defaultTimeOut,
    this.errorMessage,
    this.lockTagType = false,
  });

  @override
  ConsumerState<BlockFormFields> createState() => _BlockFormFieldsState();
}

class _BlockFormFieldsState extends ConsumerState<BlockFormFields> {
  late String _tagType;
  LookupOption? _selected;
  late TextEditingController _tasksCtl;
  late TextEditingController _timeInCtl;
  late TextEditingController _timeOutCtl;
  bool _loadingOptions = false;
  List<LookupOption> _options = const [];
  List<String> _taskTemplates = const [];
  bool _loadingTasks = false;
  String? _localError;
  bool _uploadingPhoto = false;

  /// Local mirror of the block's photo paths/urls. We keep these on the form
  /// state (rather than re-deriving from the provider every build) so that
  /// pick → upload → render is straightforward and survives the form being
  /// used in both create and edit flows.
  late List<String> _photoPaths;
  late List<String> _photoUrls;

  static const int _maxPhotos = 5;

  @override
  void initState() {
    super.initState();
    final init = widget.initial;
    if (init != null) {
      _tagType = init.tagType;
      _selected = LookupOption(id: init.tagId, code: '', name: init.tagLabel);
      _tasksCtl = TextEditingController(text: init.tasks);
      _timeInCtl = TextEditingController(text: init.timeIn);
      _timeOutCtl = TextEditingController(text: init.timeOut);
      _photoPaths = [...init.photoPaths];
      _photoUrls = [...init.photoUrls];
    } else {
      // Default to the first tag-type allowed under the current flag.
      _tagType = FeatureFlags.tagTypesFor(widget.contractType).first;
      _tasksCtl = TextEditingController();
      _timeInCtl = TextEditingController(text: widget.defaultTimeIn ?? '');
      _timeOutCtl = TextEditingController(text: widget.defaultTimeOut ?? '');
      _photoPaths = [];
      _photoUrls = [];
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadOptions());
  }

  @override
  void dispose() {
    _tasksCtl.dispose();
    _timeInCtl.dispose();
    _timeOutCtl.dispose();
    super.dispose();
  }

  Future<void> _loadOptions() async {
    setState(() => _loadingOptions = true);
    try {
      final list = await ref
          .read(lookupProvider.notifier)
          .options(contractType: widget.contractType, tagType: _tagType);
      if (!mounted) return;
      setState(() {
        _options = list;
        _loadingOptions = false;
        if (_selected != null) {
          // Re-resolve so display name is fresh
          final match = list.where((o) => o.id == _selected!.id).toList();
          if (match.isNotEmpty) _selected = match.first;
        } else if (list.isNotEmpty) {
          _selected = list.first;
        }
      });
      // Refresh task chips against the (possibly new) selection.
      await _loadTasks();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _options = const [];
        _loadingOptions = false;
        _localError = 'Failed to load options.';
      });
    }
  }

  /// Loads task templates for the currently-selected scope. Idempotent —
  /// the lookup cache short-circuits repeats.
  Future<void> _loadTasks() async {
    final selected = _selected;
    if (selected == null) {
      setState(() => _taskTemplates = const []);
      return;
    }
    setState(() => _loadingTasks = true);
    try {
      final tasks = await ref
          .read(lookupProvider.notifier)
          .tasksFor(tagType: _tagType, tagId: selected.id);
      if (!mounted) return;
      setState(() {
        _taskTemplates = tasks;
        _loadingTasks = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _taskTemplates = const [];
        _loadingTasks = false;
      });
    }
  }

  /// Prompts for a new task name, persists it under the currently-selected
  /// scope, refreshes the chip set, and auto-appends the new task to the
  /// textarea so it's instantly "selected".
  Future<void> _showAddTaskDialog() async {
    final selected = _selected;
    if (selected == null) return;
    final ctl = TextEditingController();
    final saved = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Add task to ${selected.name}'),
        content: TextField(
          controller: ctl,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          maxLength: 120,
          decoration: const InputDecoration(
            hintText: 'e.g. Concrete pour',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (v) => Navigator.of(ctx).pop(v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(ctl.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    ctl.dispose();
    if (saved == null || saved.isEmpty) return;

    setState(() => _loadingTasks = true);
    try {
      final list = await ref.read(lookupProvider.notifier).createTask(
            tagType: _tagType,
            tagId: selected.id,
            name: saved,
          );
      if (!mounted) return;
      setState(() {
        _taskTemplates = list;
        _loadingTasks = false;
      });
      _appendTaskLine(saved);
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingTasks = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to add task: $e')),
      );
    }
  }

  /// Toggles a task-template line in the tasks textarea. If the line is
  /// already present (case-insensitive bullet-line match), it is removed —
  /// otherwise it is appended as `• <name>` on its own line.
  void _appendTaskLine(String task) {
    final current = _tasksCtl.text;
    final line = '• $task';
    final lines = current.split('\n');
    final existingIdx = lines.indexWhere(
      (l) => l.trim().toLowerCase() == line.toLowerCase(),
    );
    if (existingIdx >= 0) {
      lines.removeAt(existingIdx);
      _tasksCtl.text = lines.where((l) => l.isNotEmpty).join('\n');
    } else {
      final next = current.trim().isEmpty ? line : '$current\n$line';
      _tasksCtl.text = next;
    }
    _tasksCtl.selection = TextSelection.fromPosition(
      TextPosition(offset: _tasksCtl.text.length),
    );
    setState(() {});
  }

  Future<void> _pickPhoto(ImageSource source) async {
    if (_photoPaths.length >= _maxPhotos) {
      setState(() => _localError =
          'Up to $_maxPhotos verification photos per block.');
      return;
    }
    final empId =
        ref.read(workReportProvider).profile?.employeeId;
    if (empId == null) {
      setState(() => _localError = 'No active profile — cannot upload yet.');
      return;
    }
    final picker = ImagePicker();
    final XFile? picked;
    try {
      picked = await picker.pickImage(
        source: source,
        maxWidth: 2048,
        maxHeight: 2048,
        imageQuality: 85,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _localError = 'Could not open ${source.name}: $e');
      return;
    }
    if (picked == null) return;

    setState(() {
      _uploadingPhoto = true;
      _localError = null;
    });
    try {
      // Photos are uploaded immediately on pick; the returned `path` is what
      // the submit payload references in `photo_paths`. The block itself may
      // not exist on the server yet — the path is independent of the block.
      final res = await ref
          .read(workReportProvider.notifier)
          .uploadVerificationPhoto(picked);
      if (!mounted) return;
      setState(() {
        _photoPaths = [..._photoPaths, res.path];
        _photoUrls = [..._photoUrls, res.url];
        _uploadingPhoto = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _uploadingPhoto = false;
        _localError = 'Photo upload failed: $e';
      });
    }
  }

  void _removePhoto(int index) {
    setState(() {
      final paths = [..._photoPaths]..removeAt(index);
      final urls = [..._photoUrls];
      if (index < urls.length) urls.removeAt(index);
      _photoPaths = paths;
      _photoUrls = urls;
    });
  }

  Future<void> _showPhotoSourceSheet() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Take photo'),
              onTap: () => Navigator.of(ctx).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Pick from gallery'),
              onTap: () => Navigator.of(ctx).pop(ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source != null) await _pickPhoto(source);
  }

  Future<void> _pickTime(TextEditingController ctl) async {
    TimeOfDay initial;
    final parsed = ctl.text.split(':');
    if (parsed.length == 2) {
      initial = TimeOfDay(
        hour: int.tryParse(parsed[0]) ?? 8,
        minute: int.tryParse(parsed[1]) ?? 0,
      );
    } else {
      initial = const TimeOfDay(hour: 8, minute: 0);
    }
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked != null) {
      ctl.text =
          '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      setState(() {});
    }
  }

  void _trySubmit() {
    final selected = _selected;
    if (selected == null) {
      setState(() => _localError = 'Pick an option from the list.');
      return;
    }
    if (_tasksCtl.text.trim().isEmpty) {
      setState(() => _localError = 'Tasks description is required.');
      return;
    }
    if (_timeInCtl.text.isEmpty || _timeOutCtl.text.isEmpty) {
      setState(() => _localError = 'Pick both time in and time out.');
      return;
    }
    final candidate = WorkBlock(
      localId: widget.initial?.localId ?? UniqueId.next(),
      blockId: widget.initial?.blockId,
      tagType: _tagType,
      tagId: selected.id,
      tagLabel: selected.name,
      timeIn: _timeInCtl.text,
      timeOut: _timeOutCtl.text,
      tasks: _tasksCtl.text.trim(),
      photoPaths: List.unmodifiable(_photoPaths),
      photoUrls: List.unmodifiable(_photoUrls),
    );
    final err = ref.read(workReportProvider.notifier).validateBlock(
          candidate,
          excludingLocalId: widget.initial?.localId,
        );
    if (err != null) {
      setState(() => _localError = err);
      return;
    }
    setState(() => _localError = null);
    widget.onSubmit(candidate);
  }

  @override
  Widget build(BuildContext context) {
    final tagTypeOptions = FeatureFlags.tagTypesFor(widget.contractType);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Tag type pills — Wrap so all 4 options flow on narrow screens.
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: tagTypeOptions.map((t) {
            final selected = _tagType == t;
            final disabled = widget.lockTagType && !selected;
            return GestureDetector(
              onTap: disabled
                  ? null
                  : () {
                      if (_tagType == t) return;
                      setState(() {
                        _tagType = t;
                        _selected = null;
                        _options = const [];
                      });
                      _loadOptions();
                    },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: selected
                      ? WorkReportColors.midnight
                      : Colors.white,
                  border: Border.all(
                    color: disabled
                        ? WorkReportColors.stone.withValues(alpha: 0.3)
                        : WorkReportColors.midnight,
                  ),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  TagType.labelFor(t),
                  style: TextStyle(
                    color: selected
                        ? Colors.white
                        : (disabled
                            ? WorkReportColors.stone
                            : WorkReportColors.midnight),
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 12),
        // Lookup dropdown
        if (_loadingOptions)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: LinearProgressIndicator(minHeight: 2),
          )
        else
          DropdownButtonFormField<LookupOption>(
            initialValue: _selected,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: TagType.labelFor(_tagType),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            items: _options
                .map((o) => DropdownMenuItem(
                      value: o,
                      child: Text(o.name, overflow: TextOverflow.ellipsis),
                    ))
                .toList(),
            onChanged: (v) {
              setState(() => _selected = v);
              _loadTasks();
            },
          ),
        const SizedBox(height: 12),
        // Time pair
        Row(
          children: [
            Expanded(child: _TimeField(label: 'Time in', controller: _timeInCtl, onTap: () => _pickTime(_timeInCtl))),
            const SizedBox(width: 12),
            Expanded(child: _TimeField(label: 'Time out', controller: _timeOutCtl, onTap: () => _pickTime(_timeOutCtl))),
          ],
        ),
        const SizedBox(height: 12),
        if (_loadingTasks)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 6),
            child: LinearProgressIndicator(minHeight: 2),
          )
        else if (_selected != null) ...[
          const Text(
            'COMMON TASKS — tap to add',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: WorkReportColors.stone,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              ..._taskTemplates.map((t) => _TaskChip(
                    label: t,
                    onTap: () => _appendTaskLine(t),
                  )),
              _AddTaskChip(onTap: _showAddTaskDialog),
            ],
          ),
          const SizedBox(height: 10),
        ],
        TextField(
          controller: _tasksCtl,
          minLines: 3,
          maxLines: 6,
          decoration: InputDecoration(
            labelText: 'Tasks',
            hintText:
                'Describe what was done — materials used, volume completed, specific locations, any issues encountered…',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
        ),
        const SizedBox(height: 12),
        _PhotoSection(
          photoUrls: _photoUrls,
          uploading: _uploadingPhoto,
          maxPhotos: _maxPhotos,
          onAdd: _showPhotoSourceSheet,
          onRemove: _removePhoto,
        ),
        if (_localError != null || widget.errorMessage != null) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: WorkReportColors.danger.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline, size: 16, color: WorkReportColors.danger),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _localError ?? widget.errorMessage!,
                    style: const TextStyle(color: WorkReportColors.danger, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 12),
        Row(
          children: [
            if (widget.onCancel != null) ...[
              OutlinedButton(
                onPressed: widget.onCancel,
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: WorkReportColors.terracotta,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(44),
                ),
                onPressed: _trySubmit,
                child: Text(widget.submitLabel),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _TaskChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _TaskChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: WorkReportColors.terracotta.withValues(alpha: 0.08),
          border: Border.all(color: WorkReportColors.terracotta.withValues(alpha: 0.4)),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.add, size: 14, color: WorkReportColors.terracotta),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: WorkReportColors.terracotta,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddTaskChip extends StatelessWidget {
  final VoidCallback onTap;

  const _AddTaskChip({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(
            color: WorkReportColors.midnight.withValues(alpha: 0.5),
            style: BorderStyle.solid,
          ),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.add_circle_outline, size: 14, color: WorkReportColors.midnight),
            SizedBox(width: 4),
            Text(
              'New task',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: WorkReportColors.midnight,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PhotoSection extends StatelessWidget {
  final List<String> photoUrls;
  final bool uploading;
  final int maxPhotos;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemove;

  const _PhotoSection({
    required this.photoUrls,
    required this.uploading,
    required this.maxPhotos,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final canAddMore = photoUrls.length < maxPhotos;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(Icons.photo_camera_outlined,
                size: 14, color: WorkReportColors.stone),
            const SizedBox(width: 4),
            Text(
              'VERIFICATION PHOTOS  ${photoUrls.length}/$maxPhotos',
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: WorkReportColors.stone,
                letterSpacing: 0.8,
              ),
            ),
            const Spacer(),
            if (uploading)
              const SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
          ],
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 84,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: photoUrls.length + (canAddMore ? 1 : 0),
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              if (i == photoUrls.length) {
                return _AddPhotoTile(
                  onTap: uploading ? null : onAdd,
                );
              }
              return _PhotoTile(
                url: photoUrls[i],
                onRemove: () => onRemove(i),
              );
            },
          ),
        ),
        if (photoUrls.isEmpty && !uploading)
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Text(
              'Required for completed / in-progress days. Add at least one '
              'photo as evidence of work done.',
              style: TextStyle(fontSize: 11, color: WorkReportColors.stone),
            ),
          ),
      ],
    );
  }
}

class _PhotoTile extends StatelessWidget {
  final String url;
  final VoidCallback onRemove;

  const _PhotoTile({required this.url, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(
            url,
            width: 84,
            height: 84,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => Container(
              width: 84,
              height: 84,
              color: WorkReportColors.stone.withValues(alpha: 0.15),
              alignment: Alignment.center,
              child: const Icon(Icons.broken_image_outlined,
                  size: 22, color: WorkReportColors.stone),
            ),
            loadingBuilder: (_, child, progress) {
              if (progress == null) return child;
              return Container(
                width: 84,
                height: 84,
                color: WorkReportColors.stone.withValues(alpha: 0.08),
                alignment: Alignment.center,
                child: const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              );
            },
          ),
        ),
        Positioned(
          top: 2,
          right: 2,
          child: InkWell(
            onTap: onRemove,
            borderRadius: BorderRadius.circular(999),
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, size: 14, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}

class _AddPhotoTile extends StatelessWidget {
  final VoidCallback? onTap;

  const _AddPhotoTile({this.onTap});

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 84,
        height: 84,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(
            color: disabled
                ? WorkReportColors.stone.withValues(alpha: 0.3)
                : WorkReportColors.terracotta,
            style: BorderStyle.solid,
            width: 1.2,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.add_a_photo_outlined,
              size: 22,
              color: disabled
                  ? WorkReportColors.stone
                  : WorkReportColors.terracotta,
            ),
            const SizedBox(height: 4),
            Text(
              'Add photo',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: disabled
                    ? WorkReportColors.stone
                    : WorkReportColors.terracotta,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimeField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final VoidCallback onTap;

  const _TimeField({required this.label, required this.controller, required this.onTap});

  @override
  Widget build(BuildContext context) {
    // See note in BoqLogTime's _TimeField: GestureDetector + AbsorbPointer so
    // taps always open the picker, even when the TextField loses/regains focus.
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AbsorbPointer(
        child: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: label,
            suffixIcon: const Icon(Icons.access_time, size: 18),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
        ),
      ),
    );
  }
}
