import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../model/diagram_model.dart';

/// Renders [diagram] to PNG bytes for use as a stored model thumbnail
/// (`ThumbnailFileId`). Returns null when the diagram has no nodes.
///
/// The output mirrors the on-card mini-render (white background, scaled nodes
/// and edges) so a stored thumbnail looks the same as the live preview — but is
/// computed once here instead of repainted on every card.
Future<Uint8List?> rasterizeDiagramPng(
  DiagramModel diagram, {
  int width = 480,
  int height = 360,
}) async {
  final nodes = diagram.nodes.values.toList();
  if (nodes.isEmpty) return null;

  final size = Size(width.toDouble(), height.toDouble());
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder, Offset.zero & size);

  canvas.drawRect(Offset.zero & size, Paint()..color = Colors.white);

  // Fit the whole diagram (full node rects, not just centers) into the frame.
  var minX = double.infinity, minY = double.infinity;
  var maxX = -double.infinity, maxY = -double.infinity;
  for (final node in nodes) {
    final r = node.rect;
    minX = math.min(minX, r.left);
    minY = math.min(minY, r.top);
    maxX = math.max(maxX, r.right);
    maxY = math.max(maxY, r.bottom);
  }
  final dw = (maxX - minX).clamp(1.0, double.infinity);
  final dh = (maxY - minY).clamp(1.0, double.infinity);
  const pad = 24.0;
  final scale = math
      .min((size.width - pad * 2) / dw, (size.height - pad * 2) / dh)
      .clamp(0.0001, double.infinity);
  final offsetX = (size.width - dw * scale) / 2 - minX * scale;
  final offsetY = (size.height - dh * scale) / 2 - minY * scale;
  Offset map(Offset p) =>
      Offset(p.dx * scale + offsetX, p.dy * scale + offsetY);

  final linePaint = Paint()
    ..color = Colors.black26
    ..strokeWidth = 1.5
    ..style = PaintingStyle.stroke;
  for (final edge in diagram.edges.values) {
    final src = diagram.nodes[edge.sourceId];
    final tgt = diagram.nodes[edge.targetId];
    if (src == null || tgt == null) continue;
    final points = <Offset>[
      map(src.rect.center),
      if (edge.waypoints.length >= 3)
        for (var i = 1; i < edge.waypoints.length - 1; i++)
          map(edge.waypoints[i]),
      map(tgt.rect.center),
    ];
    for (var i = 0; i < points.length - 1; i++) {
      canvas.drawLine(points[i], points[i + 1], linePaint);
    }
  }

  final fill = Paint()..color = const Color(0xFFF2F4F7);
  final stroke = Paint()
    ..color = Colors.black54
    ..strokeWidth = 1.5
    ..style = PaintingStyle.stroke;
  for (final node in nodes) {
    final r = Rect.fromPoints(map(node.rect.topLeft), map(node.rect.bottomRight));
    switch (node.type) {
      case NodeType.startEvent:
      case NodeType.endEvent:
        final c = r.center;
        final radius = math.min(r.width, r.height) / 2;
        canvas.drawCircle(c, radius, fill);
        canvas.drawCircle(c, radius, stroke);
        break;
      case NodeType.exclusiveGateway:
        final c = r.center;
        final s = math.min(r.width, r.height) / 2;
        final path = Path()
          ..moveTo(c.dx, c.dy - s)
          ..lineTo(c.dx + s, c.dy)
          ..lineTo(c.dx, c.dy + s)
          ..lineTo(c.dx - s, c.dy)
          ..close();
        canvas.drawPath(path, fill);
        canvas.drawPath(path, stroke);
        break;
      case NodeType.task:
        final rr = RRect.fromRectAndRadius(r, const Radius.circular(4));
        canvas.drawRRect(rr, fill);
        canvas.drawRRect(rr, stroke);
        break;
    }
  }

  final image = await recorder.endRecording().toImage(width, height);
  try {
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data?.buffer.asUint8List();
  } finally {
    image.dispose();
  }
}
