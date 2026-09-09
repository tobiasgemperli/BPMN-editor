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
    // Branching structure like the reported model: start → gateway → two tasks.
    final d = DiagramModel();
    d.nodes['s'] = NodeModel(
        id: 's',
        type: NodeType.startEvent,
        name: 'Intro',
        rect: const Rect.fromLTWH(371, 77, 48, 48),
        content: TaskContent(
            imagePaths: ['assets/x.png'],
            displayMode: ContentDisplayMode.image));
    d.nodes['g'] = NodeModel(
        id: 'g',
        type: NodeType.exclusiveGateway,
        name: '',
        rect: const Rect.fromLTWH(225, 288, 56, 56));
    d.nodes['a'] = NodeModel(
        id: 'a',
        type: NodeType.task,
        name: 'Warm up',
        rect: const Rect.fromLTWH(638, 626, 140, 70),
        content: TaskContent(
            text: 'Do 5 minutes of light cardio to prepare.',
            imagePaths: ['assets/1.png', 'assets/2.png', 'assets/3.png'],
            displayMode: ContentDisplayMode.mixed));
    d.nodes['b'] = NodeModel(
        id: 'b',
        type: NodeType.task,
        name: 'Squats video',
        rect: const Rect.fromLTWH(130, 507, 140, 70),
        content:
            TaskContent(videoPaths: ['v.mp4'], displayMode: ContentDisplayMode.video));
    d.nodes['c'] = NodeModel(
        id: 'c',
        type: NodeType.task,
        name: 'Cooldown',
        rect: const Rect.fromLTWH(130, 631, 140, 70),
        content: TaskContent(
            imagePaths: ['assets/x.png'],
            displayMode: ContentDisplayMode.image));
    d.edges['e1'] = EdgeModel(id: 'e1', sourceId: 's', targetId: 'g');
    d.edges['e2'] = EdgeModel(id: 'e2', sourceId: 'g', targetId: 'a');
    d.edges['e3'] = EdgeModel(id: 'e3', sourceId: 'g', targetId: 'b');
    d.edges['e4'] = EdgeModel(id: 'e4', sourceId: 'b', targetId: 'c');

    final c = EditorController(diagram: d);
    c.viewMode = ViewMode.ui;

    // Decoded content images with distinct aspect ratios to verify contain-fit.
    final landscape = await _solidImage(160, 90, const Color(0xFF4C9AFF)); // 16:9
    final portrait = await _solidImage(90, 160, const Color(0xFFFF6B6B)); // 9:16
    final square = await _solidImage(120, 120, const Color(0xFF34C759));
    final images = {
      'a': [landscape, portrait, square], // multiple images (mixed) → row
      's': [portrait],
    };
    final videoThumbs = {'b': landscape}; // video poster thumbnail

    const size = Size(820, 860);
    final rec = ui.PictureRecorder();
    final canvas = Canvas(rec);
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFFEFEFF4));
    // Fit: the painter offsets by (2000,2000) and spreads ~2.2x from the
    // centroid. Center the spread content and zoom out so the frames fit.
    canvas.translate(size.width / 2, size.height / 2);
    canvas.scale(0.44);
    canvas.translate(-2578.0, -2296.0);
    DiagramPainter(c, screenImages: images, videoThumbs: videoThumbs)
        .paint(canvas, size);
    final img =
        await rec.endRecording().toImage(size.width.toInt(), size.height.toInt());
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    File('/tmp/claude-501/ui_view.png')
        .writeAsBytesSync(data!.buffer.asUint8List());
    expect(data.lengthInBytes, greaterThan(500));
  });
}
