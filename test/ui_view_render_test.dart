import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bpmn_editor/diagram/model/diagram_model.dart';
import 'package:bpmn_editor/diagram/edit/editor_controller.dart';
import 'package:bpmn_editor/diagram/render/diagram_painter.dart';

Future<ui.Image> _solidImage(int w, int h, Color color) async {
  final rec = ui.PictureRecorder();
  final canvas = Canvas(rec);
  canvas.drawRect(
      Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()), Paint()..color = color);
  canvas.drawRect(
      Rect.fromLTWH(1, 1, w - 2, h - 2),
      Paint()
        ..color = const Color(0xFF1C1C1E)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4);
  return rec.endRecording().toImage(w, h);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('renders UI view with content replicas to a PNG for inspection', () async {
    final d = DiagramModel();
    d.nodes['s'] = NodeModel(
        id: 's',
        type: NodeType.startEvent,
        name: 'Intro',
        rect: const Rect.fromLTWH(200, 80, 60, 40),
        content: TaskContent(
            text: 'Welcome to the session.',
            imagePaths: ['assets/x.png'],
            displayMode: ContentDisplayMode.mixed));
    d.nodes['a'] = NodeModel(
        id: 'a',
        type: NodeType.task,
        name: 'Warm up',
        rect: const Rect.fromLTWH(190, 220, 140, 70),
        content: TaskContent(
            text: 'Do 5 minutes of light cardio and stretching to prepare.',
            imagePaths: ['assets/x.png'],
            displayMode: ContentDisplayMode.mixed));
    d.nodes['b'] = NodeModel(
        id: 'b',
        type: NodeType.task,
        name: 'Squats demonstration video',
        rect: const Rect.fromLTWH(190, 360, 140, 70),
        content:
            TaskContent(videoPaths: ['v.mp4'], displayMode: ContentDisplayMode.video));
    d.nodes['e'] = NodeModel(
        id: 'e',
        type: NodeType.endEvent,
        name: 'Done',
        rect: const Rect.fromLTWH(200, 500, 60, 40));
    d.edges['e1'] = EdgeModel(id: 'e1', sourceId: 's', targetId: 'a');
    d.edges['e2'] = EdgeModel(id: 'e2', sourceId: 'a', targetId: 'b');
    d.edges['e3'] = EdgeModel(id: 'e3', sourceId: 'b', targetId: 'e');

    final c = EditorController(diagram: d);
    c.viewMode = ViewMode.ui;

    // Decoded content images with distinct aspect ratios to verify contain-fit.
    final landscape = await _solidImage(160, 90, const Color(0xFF4C9AFF)); // 16:9
    final portrait = await _solidImage(90, 160, const Color(0xFFFF6B6B)); // 9:16
    final images = {'a': landscape, 's': portrait};

    const size = Size(560, 820);
    final rec = ui.PictureRecorder();
    final canvas = Canvas(rec);
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFFEFEFF4));
    // Fit: the painter offsets by (2000,2000) and spreads ~2.2x from the
    // centroid (~245,317). Center that and zoom out so the frames fit.
    canvas.translate(size.width / 2, size.height / 2);
    canvas.scale(0.5);
    canvas.translate(-2245.0, -2317.0);
    DiagramPainter(c, screenImages: images).paint(canvas, size);
    final img =
        await rec.endRecording().toImage(size.width.toInt(), size.height.toInt());
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    File('/tmp/claude-501/ui_view.png')
        .writeAsBytesSync(data!.buffer.asUint8List());
    expect(data.lengthInBytes, greaterThan(500));
  });
}
