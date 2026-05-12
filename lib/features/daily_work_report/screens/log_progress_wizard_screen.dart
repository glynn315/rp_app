import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../auth/providers/auth_provider.dart';
import '../../project_management/providers/project_management_provider.dart';
import '../../project_management/widgets/boq_kind_chip.dart';
import '../models/work_report_models.dart';
import '../providers/log_progress_wizard_provider.dart';
import '../providers/work_report_provider.dart';
import '../theme/work_report_colors.dart';

/// 4-step guided flow:
///   1) Attendance — pick scope (project / JO / dept / admin proj) + time + tasks
///   2) BoQ       — pick a Bill-of-Quantities item the work falls under
///   3) Photo     — take or pick a progress photo
///   4) Evaluation — GPT-4o scores the photo against the chosen BoQ item
///
/// Submitting from step 4 appends the composed block to today's draft via
/// `workReportProvider.addBlock` and routes to /work-report/today so the
/// existing finalize/submit UX takes over.
class LogProgressWizardScreen extends ConsumerStatefulWidget {
  const LogProgressWizardScreen({super.key});

  @override
  ConsumerState<LogProgressWizardScreen> createState() =>
      _LogProgressWizardScreenState();
}

class _LogProgressWizardScreenState
    extends ConsumerState<LogProgressWizardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Bootstrap today's profile so step 1 has shift/contract context, and
      // reset any leftover wizard state from a prior run.
      final empId = ref.read(authProvider).user?.employeeId;
      if (empId != null && empId.isNotEmpty) {
        ref.read(workReportProvider.notifier).loadToday(employeeId: empId);
      }
      ref.read(logProgressWizardProvider.notifier).reset();
    });
  }

  @override
  Widget build(BuildContext context) {
    final wizard = ref.watch(logProgressWizardProvider);
    final dwr = ref.watch(workReportProvider);

    return Scaffold(
      backgroundColor: WorkReportColors.cream,
      appBar: AppBar(
        backgroundColor: WorkReportColors.cream,
        elevation: 0,
        foregroundColor: WorkReportColors.midnight,
        title: const Text(
          'Log Progress',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        // Top-left back arrow uses the same handler as the bottom Back
        // button so navigation is consistent across every step.
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: wizard.step == WizardStep.attendance
              ? 'Back to dashboard'
              : 'Previous step',
          onPressed: () => _handleBack(wizard),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            tooltip: 'Cancel',
            onPressed: () => _confirmCancel(context),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            _StepDots(current: wizard.step.index),
            const SizedBox(height: 8),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: _buildStep(wizard, dwr),
              ),
            ),
            _NavBar(
              wizard: wizard,
              onBack: () => _handleBack(wizard),
              onNext: _onNext,
            ),
          ],
        ),
      ),
    );
  }

  /// Single source of truth for "Back" — used by both the AppBar arrow and
  /// the bottom Back button so they always behave identically.
  ///
  /// On step 1, leaves the wizard. Prompts the discard dialog only when the
  /// worker has already entered data; if the form is still empty, exits
  /// straight to the dashboard. On steps 2-4, walks one step back inside
  /// the wizard.
  void _handleBack(LogProgressWizardState wizard) {
    if (wizard.step == WizardStep.attendance) {
      final dirty = wizard.timeIn.isNotEmpty ||
          wizard.timeOut.isNotEmpty ||
          wizard.tasks.trim().isNotEmpty ||
          wizard.boqReady ||
          wizard.photoReady;
      if (dirty) {
        _confirmCancel(context);
      } else {
        ref.read(logProgressWizardProvider.notifier).reset();
        context.go('/home');
      }
    } else {
      ref.read(logProgressWizardProvider.notifier).back();
    }
  }

  Widget _buildStep(LogProgressWizardState w, WorkReportState dwr) {
    switch (w.step) {
      case WizardStep.attendance:
        return _AttendanceStepView(
          key: const ValueKey('step-attendance'),
          state: w,
          dwr: dwr,
        );
      case WizardStep.boq:
        return _BoqStepView(key: const ValueKey('step-boq'), state: w);
      case WizardStep.photo:
        return _PhotoStepView(key: const ValueKey('step-photo'), state: w);
      case WizardStep.evaluation:
        return _EvaluationStepView(
          key: const ValueKey('step-eval'),
          state: w,
        );
      case WizardStep.done:
        return const _DoneView(key: ValueKey('step-done'));
    }
  }

  Future<void> _onNext() async {
    final notifier = ref.read(logProgressWizardProvider.notifier);
    final w = ref.read(logProgressWizardProvider);

    switch (w.step) {
      case WizardStep.attendance:
        if (!w.attendanceReady) {
          _toast('Fill in scope, time, and tasks before continuing.');
          return;
        }
        notifier.next();

      case WizardStep.boq:
        if (!w.boqReady) {
          _toast('Pick a BoQ item to continue.');
          return;
        }
        notifier.next();

      case WizardStep.photo:
        if (!w.photoReady) {
          _toast('Capture or pick a progress photo first.');
          return;
        }
        notifier.next();

      case WizardStep.evaluation:
        // Persist the entry via the dedicated progress-entry endpoint, then
        // route home with a success snackbar. This sidesteps DetectScreen
        // (which would block when the worker has no profile/attendance).
        final err = await notifier.commitProgress();
        if (!mounted) return;
        if (err != null) {
          _toast(err);
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Progress entry saved.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        context.go('/home');

      case WizardStep.done:
        // Shouldn't be reachable through Next.
        break;
    }
  }

  void _confirmCancel(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Discard progress entry?'),
        content: const Text(
          'Your attendance, photo, and AI evaluation will be lost.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Keep editing'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      ref.read(logProgressWizardProvider.notifier).reset();
      // ignore: use_build_context_synchronously
      context.go('/home');
    }
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }
}

// ───────────────────────────────────────────────────────────────────────
// Step indicator
// ───────────────────────────────────────────────────────────────────────

class _StepDots extends StatelessWidget {
  final int current;
  const _StepDots({required this.current});

  static const _labels = ['Attendance', 'BoQ', 'Photo', 'AI'];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
      child: Row(
        children: List.generate(_labels.length, (i) {
          final done = current > i;
          final active = current == i;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Column(
                children: [
                  Container(
                    height: 28,
                    width: 28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: done
                          ? WorkReportColors.success
                          : active
                              ? WorkReportColors.terracotta
                              : Colors.white,
                      border: Border.all(
                        color: done || active
                            ? Colors.transparent
                            : WorkReportColors.stone.withValues(alpha: 0.4),
                        width: 1.4,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: done
                        ? const Icon(Icons.check, size: 16, color: Colors.white)
                        : Text(
                            '${i + 1}',
                            style: TextStyle(
                              color: active ? Colors.white : WorkReportColors.stone,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _labels[i],
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                      color: active
                          ? WorkReportColors.midnight
                          : WorkReportColors.stone,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ───────────────────────────────────────────────────────────────────────
// Step 1 — Attendance
// ───────────────────────────────────────────────────────────────────────

class _AttendanceStepView extends ConsumerStatefulWidget {
  final LogProgressWizardState state;
  final WorkReportState dwr;
  const _AttendanceStepView({super.key, required this.state, required this.dwr});

  @override
  ConsumerState<_AttendanceStepView> createState() =>
      _AttendanceStepViewState();
}

class _AttendanceStepViewState
    extends ConsumerState<_AttendanceStepView> {
  late TextEditingController _tasksCtl;
  late TextEditingController _timeInCtl;
  late TextEditingController _timeOutCtl;

  @override
  void initState() {
    super.initState();
    _tasksCtl = TextEditingController(text: widget.state.tasks);
    _timeInCtl = TextEditingController(text: widget.state.timeIn);
    _timeOutCtl = TextEditingController(text: widget.state.timeOut);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _suggestTimes();
    });
  }

  @override
  void dispose() {
    _tasksCtl.dispose();
    _timeInCtl.dispose();
    _timeOutCtl.dispose();
    super.dispose();
  }

  void _suggestTimes() {
    if (_timeInCtl.text.isNotEmpty && _timeOutCtl.text.isNotEmpty) return;
    final s = ref.read(workReportProvider.notifier).suggestTimes();
    setState(() {
      if (_timeInCtl.text.isEmpty) _timeInCtl.text = s.timeIn;
      if (_timeOutCtl.text.isEmpty) _timeOutCtl.text = s.timeOut;
    });
    _commit();
  }

  /// Mirrors the form fields into the wizard state. The project tag is
  /// derived later from the BoQ pick — step 1 only captures time + tasks.
  void _commit() {
    ref.read(logProgressWizardProvider.notifier).setAttendance(
          timeIn: _timeInCtl.text,
          timeOut: _timeOutCtl.text,
          tasks: _tasksCtl.text,
        );
  }

  Future<void> _pickTime(TextEditingController ctl) async {
    TimeOfDay initial;
    final parts = ctl.text.split(':');
    if (parts.length == 2) {
      initial = TimeOfDay(
        hour: int.tryParse(parts[0]) ?? 8,
        minute: int.tryParse(parts[1]) ?? 0,
      );
    } else {
      initial = const TimeOfDay(hour: 8, minute: 0);
    }
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked != null) {
      ctl.text =
          '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      _commit();
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final shift = widget.dwr.profile?.shift;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _StepHeader(
            title: 'Step 1 · Time logs',
            subtitle:
                'Log when you worked and what you did. You\'ll pick the BoQ item this work falls under in the next step.',
          ),
          const SizedBox(height: 12),
          if (shift != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: WorkReportColors.midnight.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.access_time,
                      size: 14, color: WorkReportColors.stone),
                  const SizedBox(width: 6),
                  Text(
                    "Today's shift: ${shift.timeIn} – ${shift.timeOut}",
                    style: const TextStyle(
                      fontSize: 12,
                      color: WorkReportColors.charcoal,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _TimeBox(
                    label: 'Time in',
                    controller: _timeInCtl,
                    onTap: () => _pickTime(_timeInCtl)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _TimeBox(
                    label: 'Time out',
                    controller: _timeOutCtl,
                    onTap: () => _pickTime(_timeOutCtl)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _tasksCtl,
            minLines: 3,
            maxLines: 6,
            onChanged: (_) => _commit(),
            decoration: InputDecoration(
              labelText: 'Tasks',
              hintText: 'What did you work on during this block?',
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          ),
        ],
      ),
    );
  }
}

class _TimeBox extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final VoidCallback onTap;

  const _TimeBox({
    required this.label,
    required this.controller,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
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
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
        ),
      ),
    );
  }
}

// ───────────────────────────────────────────────────────────────────────
// Step 2 — BoQ selection
// ───────────────────────────────────────────────────────────────────────

class _BoqStepView extends ConsumerWidget {
  final LogProgressWizardState state;
  const _BoqStepView({super.key, required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(boqListProvider);
    final money = NumberFormat.currency(locale: 'en_PH', symbol: '₱');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 8, 20, 0),
          child: _StepHeader(
            title: 'Step 2 · Select BoQ',
            subtitle:
                'Pick the Bill-of-Quantities item this block of work falls under. The AI will check your photo against this scope.',
          ),
        ),
        Expanded(
          child: async.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text('Failed to load BoQ: $e',
                    textAlign: TextAlign.center),
              ),
            ),
            data: (items) {
              if (items.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Text(
                      'No BoQ lines available. Make sure projects with BOM/LMC budgets exist.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                itemCount: items.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final it = items[i];
                  final selected = state.selectedBoq?.lineId == it.lineId &&
                      it.lineId != null;
                  return InkWell(
                    onTap: () => ref
                        .read(logProgressWizardProvider.notifier)
                        .setBoq(it),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: selected
                              ? WorkReportColors.terracotta
                              : AppColors.neutral100,
                          width: selected ? 2 : 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              BoqKindChip(kind: it.lineKind),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  it.itemLabel.isEmpty ? '—' : it.itemLabel,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              if (selected)
                                const Icon(Icons.check_circle,
                                    color: WorkReportColors.terracotta,
                                    size: 18),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            it.projectName,
                            style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary),
                          ),
                          if (it.scopeName.isNotEmpty || it.stageName.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                [it.scopeName, it.stageName]
                                    .where((s) => s.isNotEmpty)
                                    .join(' · '),
                                style: const TextStyle(
                                    fontSize: 10,
                                    color: AppColors.textMuted),
                              ),
                            ),
                          const SizedBox(height: 6),
                          Text(
                            money.format(it.amount),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

// ───────────────────────────────────────────────────────────────────────
// Step 3 — Photo
// ───────────────────────────────────────────────────────────────────────

class _PhotoStepView extends ConsumerStatefulWidget {
  final LogProgressWizardState state;
  const _PhotoStepView({super.key, required this.state});

  @override
  ConsumerState<_PhotoStepView> createState() => _PhotoStepViewState();
}

class _PhotoStepViewState extends ConsumerState<_PhotoStepView> {
  Future<void> _pick(ImageSource source) async {
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
      _toast('Could not open ${source.name}: $e');
      return;
    }
    if (picked == null) return;

    await ref.read(logProgressWizardProvider.notifier).uploadPhoto(picked);
  }

  Future<void> _showSourceSheet() async {
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
    if (source != null) await _pick(source);
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    final w = ref.watch(logProgressWizardProvider);
    final canAdd = w.canAddPhoto;
    final count  = w.photoFiles.length;
    final tileCount = count + (canAdd ? 1 : 0);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _StepHeader(
            title: 'Step 3 · Progress photos',
            subtitle: w.selectedBoq == null
                ? 'Add up to ${LogProgressWizardState.maxPhotos} photos of the work in progress.'
                : 'Photos for: ${w.selectedBoq!.itemLabel}  ($count/${LogProgressWizardState.maxPhotos})',
          ),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: tileCount == 0 ? 1 : tileCount,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 1,
            ),
            itemBuilder: (context, i) {
              if (count == 0 && i == 0) {
                return _AddPhotoTile(
                  onTap: w.busy ? null : _showSourceSheet,
                );
              }
              if (i == count) {
                return _AddPhotoTile(
                  onTap: w.busy ? null : _showSourceSheet,
                );
              }
              return _PhotoTile(
                file: w.photoFiles[i],
                onRemove: w.busy
                    ? null
                    : () => ref
                        .read(logProgressWizardProvider.notifier)
                        .removePhoto(i),
              );
            },
          ),
          if (w.busy) ...[
            const SizedBox(height: 12),
            const Row(
              children: [
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 10),
                Text('Uploading…', style: TextStyle(fontSize: 13)),
              ],
            ),
          ],
          if (count > 0) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: w.busy
                    ? null
                    : () => ref
                        .read(logProgressWizardProvider.notifier)
                        .clearPhotos(),
                icon: const Icon(Icons.delete_sweep_outlined, size: 18),
                label: const Text('Remove all'),
              ),
            ),
          ],
          if (w.error != null) ...[
            const SizedBox(height: 12),
            _ErrorBanner(message: w.error!),
          ],
        ],
      ),
    );
  }
}

class _PhotoTile extends StatelessWidget {
  final XFile file;
  final VoidCallback? onRemove;
  const _PhotoTile({required this.file, this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          // Preview the LOCAL bytes, not the server URL. On Flutter web the
          // static-asset URL is cross-origin and historically the storage
          // symlink wasn't behind the CORS middleware.
          child: _XFileImage(file: file),
        ),
        Positioned(
          top: 2,
          right: 2,
          child: Material(
            color: Colors.black54,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onRemove,
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(Icons.close, size: 16, color: Colors.white),
              ),
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(
            color: WorkReportColors.stone.withValues(alpha: 0.4),
            width: 1,
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_a_photo_outlined,
                  size: 28, color: WorkReportColors.stone),
              SizedBox(height: 6),
              Text(
                'Add photo',
                style: TextStyle(
                  fontSize: 11,
                  color: WorkReportColors.stone,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Renders an [XFile]'s bytes via [Image.memory]. Works on web (where
/// [Image.network] would hit CORS on the storage symlink) and on mobile
/// without changes. Uses a [FutureBuilder] because [XFile.readAsBytes] is
/// async on every platform.
class _XFileImage extends StatelessWidget {
  final XFile file;
  const _XFileImage({required this.file});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List>(
      future: file.readAsBytes(),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return Container(
            color: WorkReportColors.stone.withValues(alpha: 0.08),
            alignment: Alignment.center,
            child: const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }
        if (snap.hasError || snap.data == null) {
          return Container(
            color: WorkReportColors.stone.withValues(alpha: 0.15),
            alignment: Alignment.center,
            child: const Icon(Icons.broken_image_outlined,
                size: 28, color: WorkReportColors.stone),
          );
        }
        return Image.memory(snap.data!, fit: BoxFit.cover);
      },
    );
  }
}

// ───────────────────────────────────────────────────────────────────────
// Step 4 — AI evaluation
// ───────────────────────────────────────────────────────────────────────

class _EvaluationStepView extends ConsumerStatefulWidget {
  final LogProgressWizardState state;
  const _EvaluationStepView({super.key, required this.state});

  @override
  ConsumerState<_EvaluationStepView> createState() =>
      _EvaluationStepViewState();
}

class _EvaluationStepViewState extends ConsumerState<_EvaluationStepView> {
  bool _kicked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_kicked) return;
      _kicked = true;
      _runEvaluation();
    });
  }

  Future<void> _runEvaluation() async {
    final w = ref.read(logProgressWizardProvider);
    if (w.evaluation != null) return;
    if (w.photoFiles.isEmpty) return;
    // Evaluate the most recently uploaded photo. The AI verdict is scored
    // against a single image, and the last upload represents the worker's
    // current view of the task — earlier shots are kept for the record but
    // don't drive the verdict.
    await ref
        .read(logProgressWizardProvider.notifier)
        .runEvaluation(w.photoFiles.last);
  }

  @override
  Widget build(BuildContext context) {
    final w = ref.watch(logProgressWizardProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _StepHeader(
            title: 'Step 4 · AI review',
            subtitle:
                'GPT-4o checks whether your photo plausibly shows progress on the chosen BoQ item.',
          ),
          const SizedBox(height: 16),
          if (w.photoFiles.isNotEmpty) ...[
            // Show the photo the AI scored (always the most recently
            // uploaded one — see _runEvaluation).
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: _XFileImage(file: w.photoFiles.last),
              ),
            ),
            if (w.photoFiles.length > 1) ...[
              const SizedBox(height: 8),
              Text(
                'AI reviewed the latest photo · ${w.photoFiles.length} attached',
                style: const TextStyle(
                  fontSize: 11,
                  color: WorkReportColors.stone,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
          const SizedBox(height: 12),
          if (w.busy)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: WorkReportColors.midnight.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                children: [
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Asking the AI to look at your photo…',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            )
          else if (w.evaluation != null)
            _EvalCard(evaluation: w.evaluation!)
          else if (w.error != null)
            _ErrorBanner(message: w.error!)
          else
            const SizedBox(),
          const SizedBox(height: 12),
          if (w.evaluation != null && !w.busy)
            OutlinedButton.icon(
              onPressed: () {
                _kicked = false;
                ref
                    .read(logProgressWizardProvider.notifier)
                    .clearEvaluation();
                _runEvaluation();
              },
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Re-run evaluation'),
            ),
        ],
      ),
    );
  }
}

class _EvalCard extends StatelessWidget {
  final ProgressPhotoEvaluation evaluation;
  const _EvalCard({required this.evaluation});

  @override
  Widget build(BuildContext context) {
    final v = evaluation.verdict;
    final (bg, fg, icon, label) = switch (v) {
      'ok' => (
          WorkReportColors.success.withValues(alpha: 0.1),
          WorkReportColors.success,
          Icons.check_circle,
          'Looks good',
        ),
      'retake' => (
          WorkReportColors.danger.withValues(alpha: 0.1),
          WorkReportColors.danger,
          Icons.replay_circle_filled,
          'Re-take recommended',
        ),
      _ => (
          WorkReportColors.terracotta.withValues(alpha: 0.1),
          WorkReportColors.terracotta,
          Icons.help_outline,
          'Uncertain',
        ),
    };

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: fg.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: fg, size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: fg,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            evaluation.evaluation.isEmpty
                ? '(no commentary returned)'
                : evaluation.evaluation,
            style: const TextStyle(fontSize: 13, height: 1.4),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────────────────────────────────────────────────────
// Done / shared widgets
// ───────────────────────────────────────────────────────────────────────

class _DoneView extends StatelessWidget {
  const _DoneView({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle, color: WorkReportColors.success, size: 48),
            SizedBox(height: 8),
            Text(
              'Block added to today\'s draft.',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  const _StepHeader({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
            color: WorkReportColors.midnight,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(
              fontSize: 12, color: WorkReportColors.stone, height: 1.4),
        ),
      ],
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: WorkReportColors.danger.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline,
              size: 16, color: WorkReportColors.danger),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                  color: WorkReportColors.danger, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavBar extends StatelessWidget {
  final LogProgressWizardState wizard;
  final VoidCallback onBack;
  final Future<void> Function() onNext;

  const _NavBar({required this.wizard, required this.onBack, required this.onNext});

  /// Returns a short list of missing fields so the worker knows why Next is
  /// disabled. Returns null when the step is complete.
  String? _missingHint() {
    switch (wizard.step) {
      case WizardStep.attendance:
        final missing = <String>[];
        if (wizard.timeIn.isEmpty || wizard.timeOut.isEmpty) {
          missing.add('time-in/out');
        }
        if (wizard.tasks.trim().isEmpty) missing.add('tasks');
        return missing.isEmpty ? null : 'Missing: ${missing.join(', ')}';
      case WizardStep.boq:
        return wizard.boqReady ? null : 'Pick a BoQ item to continue.';
      case WizardStep.photo:
        if (wizard.busy) return 'Uploading photo…';
        return wizard.photoReady ? null : 'Take or pick a progress photo.';
      case WizardStep.evaluation:
        return wizard.busy ? 'Running AI evaluation…' : null;
      case WizardStep.done:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLast = wizard.step == WizardStep.evaluation;
    final canNext = switch (wizard.step) {
      WizardStep.attendance => wizard.attendanceReady,
      WizardStep.boq => wizard.boqReady,
      WizardStep.photo => wizard.photoReady && !wizard.busy,
      WizardStep.evaluation => !wizard.busy,
      WizardStep.done => false,
    };
    final hint = _missingHint();

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      decoration: const BoxDecoration(
        color: WorkReportColors.cream,
        border: Border(top: BorderSide(color: AppColors.neutral100)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (hint != null && !canNext)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  const Icon(Icons.info_outline,
                      size: 14, color: WorkReportColors.stone),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      hint,
                      style: const TextStyle(
                        fontSize: 11,
                        color: WorkReportColors.stone,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back, size: 16),
                label: Text(
                  // On step 1 the bottom Back button leaves the wizard, so
                  // label it accordingly. On later steps it goes back one
                  // step inside the wizard.
                  wizard.step == WizardStep.attendance ? 'Exit' : 'Back',
                ),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 46),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: WorkReportColors.terracotta,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(46),
                  ),
                  onPressed: canNext ? () => onNext() : null,
                  child: Text(isLast ? 'Add to today\'s report' : 'Next'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
