import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

/// One row of the pending-task report image.
class TaskReportRow {
  final String title;
  final String dateEncoded;
  final String tentativeDone;
  final String status;
  final String notes;
  final bool overdue;

  const TaskReportRow({
    required this.title,
    required this.dateEncoded,
    required this.tentativeDone,
    required this.status,
    required this.notes,
    required this.overdue,
  });
}

class _Col {
  final String label;
  final double weight;
  final TextAlign align;
  final String Function(TaskReportRow) value;
  const _Col(this.label, this.weight, this.align, this.value);
}

String _vTitle(TaskReportRow r) => r.title;
String _vEncoded(TaskReportRow r) => r.dateEncoded;
String _vTentative(TaskReportRow r) => r.tentativeDone;
String _vStatus(TaskReportRow r) => r.status;
String _vNotes(TaskReportRow r) => r.notes;

const _cols = <_Col>[
  _Col('TASK NAME', 2.6, TextAlign.left, _vTitle),
  _Col('DATE\nENCODED', 1.0, TextAlign.center, _vEncoded),
  _Col('TENTATIVE\nDATE DONE', 1.1, TextAlign.center, _vTentative),
  _Col('STATUS', 1.0, TextAlign.center, _vStatus),
  _Col('NOTES / UPDATES', 3.0, TextAlign.left, _vNotes),
];

const _tentativeCol = 2; // index drawn red when overdue

/// Renders the pending-task report as a bordered table PNG (the Flutter
/// parallel to the web canvas renderer). Returns PNG bytes, or null on
/// failure. Uses dart:ui directly — no widget mounting needed.
Future<Uint8List?> renderTaskReportImage(
    String owner, List<TaskReportRow> rows) async {
  try {
    const scale = 2.0;
    const w = 1100.0;
    const padX = 6.0;
    const padY = 6.0;
    const titleH = 26.0;

    const headStyle = TextStyle(
        fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF1A1A1A));
    const bodyStyle = TextStyle(fontSize: 11, color: Color(0xFF1A1A1A));
    const redStyle = TextStyle(fontSize: 11, color: Color(0xFFCC0000));
    const titleStyle = TextStyle(
        fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF1A1A1A));

    TextPainter tp(String text, TextStyle style, double maxW, TextAlign align) {
      final p = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: TextDirection.ltr,
        textAlign: align,
      );
      p.layout(maxWidth: maxW < 8 ? 8 : maxW);
      return p;
    }

    final totalWeight = _cols.fold<double>(0, (s, c) => s + c.weight);
    final colW = _cols.map((c) => w * c.weight / totalWeight).toList();
    final colX = <double>[];
    var cx = 0.0;
    for (final cw in colW) {
      colX.add(cx);
      cx += cw;
    }

    // Header painters + band height.
    final headTps = [
      for (var i = 0; i < _cols.length; i++)
        tp(_cols[i].label, headStyle, colW[i] - padX * 2, TextAlign.center)
    ];
    final headH =
        headTps.map((p) => p.height).reduce((a, b) => a > b ? a : b) + padY * 2;

    // Body painters + per-row height.
    final rowTps = <List<TextPainter>>[];
    final rowH = <double>[];
    final display = rows.isEmpty
        ? const [
            TaskReportRow(
              title: 'No pending tasks.',
              dateEncoded: '',
              tentativeDone: '',
              status: '',
              notes: '',
              overdue: false,
            )
          ]
        : rows;
    for (final r in display) {
      final ps = [
        for (var i = 0; i < _cols.length; i++)
          tp(
            _cols[i].value(r),
            i == _tentativeCol && r.overdue ? redStyle : bodyStyle,
            colW[i] - padX * 2,
            _cols[i].align,
          )
      ];
      final maxH = ps.map((p) => p.height).reduce((a, b) => a > b ? a : b);
      rowTps.add(ps);
      rowH.add(maxH + padY * 2);
    }

    final tableTop = titleH + 4;
    final totalH =
        tableTop + headH + rowH.fold<double>(0, (s, h) => s + h) + 2;

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    canvas.scale(scale, scale);

    canvas.drawRect(ui.Rect.fromLTWH(0, 0, w, totalH),
        ui.Paint()..color = const Color(0xFFFFFFFF));

    tp(owner.toUpperCase(), titleStyle, w, TextAlign.left)
        .paint(canvas, const ui.Offset(0, 4));

    var y = tableTop;
    canvas.drawRect(
        ui.Rect.fromLTWH(0, y, w, headH), ui.Paint()..color = const Color(0xFFF2F2F2));
    for (var i = 0; i < _cols.length; i++) {
      headTps[i].paint(canvas, ui.Offset(colX[i] + padX, y + padY));
    }
    y += headH;

    for (var ri = 0; ri < display.length; ri++) {
      for (var ci = 0; ci < _cols.length; ci++) {
        rowTps[ri][ci].paint(canvas, ui.Offset(colX[ci] + padX, y + padY));
      }
      y += rowH[ri];
    }

    final linePaint = ui.Paint()
      ..color = const Color(0xFF000000)
      ..strokeWidth = 1;
    final gridBottom = y;
    for (var i = 0; i <= _cols.length; i++) {
      final vx = i < _cols.length ? colX[i] : w;
      canvas.drawLine(
          ui.Offset(vx, tableTop), ui.Offset(vx, gridBottom), linePaint);
    }
    final yLines = <double>[tableTop, tableTop + headH];
    var acc = tableTop + headH;
    for (final h in rowH) {
      acc += h;
      yLines.add(acc);
    }
    for (final ly in yLines) {
      canvas.drawLine(ui.Offset(0, ly), ui.Offset(w, ly), linePaint);
    }

    final picture = recorder.endRecording();
    final img =
        await picture.toImage((w * scale).ceil(), (totalH * scale).ceil());
    final bd = await img.toByteData(format: ui.ImageByteFormat.png);
    picture.dispose();
    img.dispose();
    return bd?.buffer.asUint8List();
  } catch (_) {
    return null;
  }
}
