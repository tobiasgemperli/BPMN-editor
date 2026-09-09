import 'dart:io';
import 'dart:math' as math;
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

/// Render the UI view of [d] to [out], auto-fitting the spread frames.
Future<void> _renderUiView(DiagramModel d, String out,
    {Map<String, List<ui.Image>>? images,
    Map<String, ui.Image>? videoThumbs}) async {
  final c = EditorController(diagram: d);
  c.viewMode = ViewMode.ui;
  final rects = DiagramPainter.uiDisplayRects(d).values;
  var l = double.infinity, t = double.infinity;
  var r = -double.infinity, b = -double.infinity;
  for (final rc in rects) {
    l = math.min(l, rc.left);
    t = math.min(t, rc.top);
    r = math.max(r, rc.right);
    b = math.max(b, rc.bottom);
  }
  const pad = 40.0;
  final size = Size(
      ((r - l) + pad * 2).clamp(200.0, 2400.0),
      ((b - t) + pad * 2).clamp(200.0, 3200.0));
  final rec = ui.PictureRecorder();
  final canvas = Canvas(rec);
  canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFFEFEFF4));
  // Content is drawn at diagram-coords + (2000,2000); shift so it fits at pad.
  canvas.translate(-(2000 + l - pad), -(2000 + t - pad));
  DiagramPainter(c, screenImages: images, videoThumbs: videoThumbs)
      .paint(canvas, size);
  final img =
      await rec.endRecording().toImage(size.width.toInt(), size.height.toInt());
  final data = await img.toByteData(format: ui.ImageByteFormat.png);
  File(out).writeAsBytesSync(data!.buffer.asUint8List());
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

  test('reported gateway diagram: start → gateway → two branches + chain',
      () async {
    final img = await _solidImage(160, 90, const Color(0xFF4C9AFF));
    Rect rc(double x, double y, [double w = 140, double h = 70]) =>
        Rect.fromLTWH(x, y, w, h);
    NodeModel task(String id, double x, double y, {TaskContent? c}) =>
        NodeModel(id: id, type: NodeType.task, name: id, rect: rc(x, y), content: c);

    final d = DiagramModel();
    d.nodes['s'] = NodeModel(
        id: 's',
        type: NodeType.startEvent,
        name: 'start',
        rect: rc(196, 76, 48, 48),
        content: TaskContent(
            imagePaths: ['assets/x.png'], displayMode: ContentDisplayMode.image));
    d.nodes['g'] = NodeModel(
        id: 'g',
        type: NodeType.exclusiveGateway,
        name: '',
        rect: rc(192, 232, 56, 56));
    d.nodes['t5'] = task('t5', 60, 385,
        c: TaskContent(text: 'dhdhhd snsbnd d. d'));
    d.nodes['t7'] = task('t7', 240, 385,
        c: TaskContent(
            imagePaths: ['a', 'b', 'c'], displayMode: ContentDisplayMode.mixed));
    d.nodes['t9'] = task('t9', 240, 545,
        c: TaskContent(
            imagePaths: ['a'], displayMode: ContentDisplayMode.image));
    d.nodes['t13'] = task('t13', 240, 705);
    d.nodes['t15'] = task('t15', 240, 865);
    d.nodes['t17'] = task('t17', 240, 1025,
        c: TaskContent(videoPaths: ['v'], displayMode: ContentDisplayMode.video));
    d.nodes['t19'] = task('t19', 240, 1185);
    d.nodes['t21'] = task('t21', 240, 1345);
    d.nodes['end'] = NodeModel(
        id: 'end', type: NodeType.endEvent, name: '', rect: rc(646, 76, 48, 48));
    for (final e in [
      ['s', 'g'], ['g', 't5'], ['g', 't7'], ['t7', 't9'], ['t9', 't13'],
      ['t13', 't15'], ['t15', 't17'], ['t17', 't19'], ['t19', 't21'],
    ]) {
      d.edges['${e[0]}_${e[1]}'] =
          EdgeModel(id: '${e[0]}_${e[1]}', sourceId: e[0], targetId: e[1]);
    }

    await _renderUiView(d, '/tmp/claude-501/ui_reported.png',
        images: {
          's': [img],
          't7': [img, img, img],
          't9': [img],
        },
        videoThumbs: {'t17': img});
    expect(File('/tmp/claude-501/ui_reported.png').existsSync(), true);
  });
}
