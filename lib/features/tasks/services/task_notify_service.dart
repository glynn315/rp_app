import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/api/api_client.dart';
import '../models/task_model.dart';
import 'task_report_image.dart';

/// Posts the owner's pending-task report to the backend, which renders it into
/// the #task Discord channel. The report is sent as a PNG table image (built
/// client-side); the backend edits one message per owner in place, so the
/// Discord message id is remembered in SharedPreferences (mirrors the web's
/// localStorage). Best-effort — failures are swallowed by the caller.
class TaskNotifyService {
  final ApiClient _api;
  TaskNotifyService({ApiClient? api}) : _api = api ?? ApiClient();

  static String _key(String ownerId) =>
      'rpv_task_report_msg_${ownerId.isEmpty ? 'anon' : ownerId}';

  static String _mdy(DateTime? d) {
    if (d == null) return '';
    return '${d.month}/${d.day}/${d.year}';
  }

  /// Builds report rows from the current pending tasks (excludes
  /// completed/cancelled), newest first.
  static List<TaskReportRow> buildRows(List<Task> tasks) {
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    return tasks
        .where((t) =>
            t.status != TaskStatus.completed &&
            t.status != TaskStatus.cancelled)
        .map((t) => TaskReportRow(
              title: t.title,
              dateEncoded: _mdy(t.createdAt),
              tentativeDone: _mdy(t.dueDate),
              status: t.status.label,
              notes: t.description ?? '',
              overdue: t.dueDate != null && t.dueDate!.isBefore(todayDate),
            ))
        .toList();
  }

  Future<bool> syncReport({
    required String ownerId,
    required String ownerName,
    required List<Task> tasks,
    String? token,
  }) async {
    final rows = buildRows(tasks);

    final bytes = await renderTaskReportImage(ownerName, rows);
    final dataUrl =
        bytes != null ? 'data:image/png;base64,${base64Encode(bytes)}' : null;

    final prefs = await SharedPreferences.getInstance();
    final key = _key(ownerId);
    final existing = prefs.getString(key);
    final hasMessageId = existing != null && existing.isNotEmpty;

    try {
      final res = await _api.post(
        '/task/notify-update',
        {
          'owner': ownerName,
          if (hasMessageId) 'report_message_id': existing,
          'report_image': ?dataUrl,
          'tasks': [
            for (final r in rows)
              {
                'title': r.title,
                'date_encoded': r.dateEncoded,
                'tentative_done': r.tentativeDone,
                'status': r.status,
                'overdue': r.overdue,
                'updates': const [],
              }
          ],
        },
        token: token,
      );
      final mid = res['message_id']?.toString();
      if (mid != null && mid.isNotEmpty) {
        await prefs.setString(key, mid);
      }
      return true;
    } catch (_) {
      return false;
    }
  }
}
