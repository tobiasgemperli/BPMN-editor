import 'dart:math';
import 'package:flutter/material.dart';
import '../model/diagram_model.dart';
import '../edit/editor_controller.dart';

/// Custom painter that draws the entire BPMN diagram on a canvas.
class DiagramPainter extends CustomPainter {
  final EditorController controller;

  // Cached paints.
  static final _nodePaint = Paint()
    ..color = Colors.white
    ..style = PaintingStyle.fill;
  static final _nodeStroke = Paint()
    ..color = Colors.black87
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.0;
  static final _endNodeStroke = Paint()
    ..color = Colors.black87
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3.5;
  static final _selectedStroke = Paint()
    ..color = Colors.blue
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.5;
  static final _edgePaint = Paint()
    ..color = Colors.black87
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.8;
  static final _edgeSelectedPaint = Paint()
    ..color = Colors.blue
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.5;
  static final _arrowPaint = Paint()
    ..color = Colors.black87
    ..style = PaintingStyle.fill;
  static final _arrowSelectedPaint = Paint()
    ..color = Colors.blue
    ..style = PaintingStyle.fill;
  static final _connectionPreviewPaint = Paint()
    ..color = Colors.blue.withValues(alpha: 0.5)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.0
    ..strokeCap = StrokeCap.round;
  static final _handlePaint = Paint()
    ..color = Colors.blue
    ..style = PaintingStyle.fill;
  static final _gridPaint = Paint()
    ..color = const Color(0x22000000)
    ..style = PaintingStyle.fill;

  DiagramPainter(this.controller) : super(repaint: controller);

  @override
  void paint(Canvas canvas, Size size) {
    _drawGrid(canvas, size);
    _drawEdges(canvas);
    _drawNodes(canvas);
    _drawConnectionPreview(canvas);
    _drawConnectorHandle(canvas);
  }

  void _drawGrid(Canvas canvas, Size size) {
    const step = 20.0;
    for (double x = 0; x < size.width; x += step) {
      for (double y = 0; y < size.height; y += step) {
        canvas.drawCircle(Offset(x, y), 0.7, _gridPaint);
      }
    }
  }

  void _drawEdges(Canvas canvas) {
    final diagram = controller.diagram;
    for (final edge in diagram.edges.values) {
      final isSelected = edge.id == controller.selectedEdgeId;
      final paint = isSelected ? _edgeSelectedPaint : _edgePaint;
      final arrowFill = isSelected ? _arrowSelectedPaint : _arrowPaint;

      final source = diagram.nodes[edge.sourceId];
      final target = diagram.nodes[edge.targetId];
      if (source == null || target == null) continue;

      final wps = edge.waypoints.isNotEmpty
          ? edge.waypoints
          : [source.center, target.center];

      if (wps.length < 2) continue;

      // Clip start and end to node boundaries.
      final clippedStart = _clipToNodeBorder(source, wps[1]);
      final clippedEnd = _clipToNodeBorder(target, wps[wps.length - 2]);

      final adjustedWps = [clippedStart, ...wps.sublist(1, wps.length - 1), clippedEnd];

      // Draw polyline.
      final path = Path();
      path.moveTo(adjustedWps[0].dx, adjustedWps[0].dy);
      for (int i = 1; i < adjustedWps.length; i++) {
        path.lineTo(adjustedWps[i].dx, adjustedWps[i].dy);
      }
      canvas.drawPath(path, paint);

      // Arrowhead at the end.
      _drawArrow(canvas, adjustedWps[adjustedWps.length - 2], adjustedWps.last, arrowFill);

      // Draw edge name if present.
      if (edge.name.isNotEmpty && adjustedWps.length >= 2) {
        final mid = Offset(
          (adjustedWps.first.dx + adjustedWps.last.dx) / 2,
          (adjustedWps.first.dy + adjustedWps.last.dy) / 2 - 10,
        );
        _drawText(canvas, edge.name, mid, fontSize: 11);
      }
    }
  }

  Offset _clipToNodeBorder(NodeModel node, Offset other) {
    final c = node.center;
    final dx = other.dx - c.dx;
    final dy = other.dy - c.dy;

    if (node.type == NodeType.startEvent || node.type == NodeType.endEvent) {
      final r = node.rect.width / 2;
      final dist = sqrt(dx * dx + dy * dy);
      if (dist == 0) return c;
      return Offset(c.dx + dx / dist * r, c.dy + dy / dist * r);
    }

    if (node.type == NodeType.exclusiveGateway) {
      // Diamond clipping: scale to touch diamond edge.
      final hw = node.rect.width / 2;
      final hh = node.rect.height / 2;
      if (dx == 0 && dy == 0) return c;
      final adx = dx.abs();
      final ady = dy.abs();
      final scale = 1.0 / (adx / hw + ady / hh);
      return Offset(c.dx + dx * scale, c.dy + dy * scale);
    }

    // Rectangle clipping for tasks.
    final hw = node.rect.width / 2;
    final hh = node.rect.height / 2;
    if (dx == 0 && dy == 0) return c;
    final scaleX = dx != 0 ? (hw / dx.abs()) : double.infinity;
    final scaleY = dy != 0 ? (hh / dy.abs()) : double.infinity;
    final scale = min(scaleX, scaleY);
    return Offset(c.dx + dx * scale, c.dy + dy * scale);
  }

  void _drawArrow(Canvas canvas, Offset from, Offset to, Paint paint) {
    final dx = to.dx - from.dx;
    final dy = to.dy - from.dy;
    final len = sqrt(dx * dx + dy * dy);
    if (len == 0) return;

    const arrowLen = 12.0;
    const arrowWidth = 5.0;
    final ux = dx / len;
    final uy = dy / len;

    final base = Offset(to.dx - ux * arrowLen, to.dy - uy * arrowLen);
    final left = Offset(base.dx - uy * arrowWidth, base.dy + ux * arrowWidth);
    final right = Offset(base.dx + uy * arrowWidth, base.dy - ux * arrowWidth);

    final path = Path()
      ..moveTo(to.dx, to.dy)
      ..lineTo(left.dx, left.dy)
      ..lineTo(right.dx, right.dy)
      ..close();
    canvas.drawPath(path, paint);
  }

  void _drawNodes(Canvas canvas) {
    for (final node in controller.diagram.nodes.values) {
      final isSelected = node.id == controller.selectedNodeId;

      switch (node.type) {
        case NodeType.startEvent:
          _drawCircleNode(canvas, node, isSelected, false);
          break;
        case NodeType.endEvent:
          _drawCircleNode(canvas, node, isSelected, true);
          break;
        case NodeType.task:
          _drawTaskNode(canvas, node, isSelected);
          break;
        case NodeType.exclusiveGateway:
          _drawGatewayNode(canvas, node, isSelected);
          break;
      }
    }
  }

  void _drawCircleNode(Canvas canvas, NodeModel node, bool selected, bool thick) {
    final c = node.center;
    final r = node.rect.width / 2;

    canvas.drawCircle(c, r, _nodePaint);
    canvas.drawCircle(c, r, thick ? _endNodeStroke : _nodeStroke);

    if (selected) {
      canvas.drawCircle(c, r + 3, _selectedStroke);
    }

    if (node.name.isNotEmpty) {
      _drawText(canvas, node.name, Offset(c.dx, node.rect.bottom + 14), fontSize: 11);
    }
  }

  void _drawTaskNode(Canvas canvas, NodeModel node, bool selected) {
    final rr = RRect.fromRectAndRadius(node.rect, const Radius.circular(8));
    canvas.drawRRect(rr, _nodePaint);
    canvas.drawRRect(rr, _nodeStroke);

    if (selected) {
      canvas.drawRRect(rr.inflate(3), _selectedStroke);
    }

    // Draw name centered.
    final label = node.name.isNotEmpty ? node.name : 'Task';
    _drawText(canvas, label, node.center, fontSize: 13, maxWidth: node.rect.width - 12);
  }

  void _drawGatewayNode(Canvas canvas, NodeModel node, bool selected) {
    final c = node.center;
    final hw = node.rect.width / 2;
    final hh = node.rect.height / 2;

    final path = Path()
      ..moveTo(c.dx, c.dy - hh)
      ..lineTo(c.dx + hw, c.dy)
      ..lineTo(c.dx, c.dy + hh)
      ..lineTo(c.dx - hw, c.dy)
      ..close();

    canvas.drawPath(path, _nodePaint);
    canvas.drawPath(path, _nodeStroke);

    if (selected) {
      final selPath = Path()
        ..moveTo(c.dx, c.dy - hh - 3)
        ..lineTo(c.dx + hw + 3, c.dy)
        ..lineTo(c.dx, c.dy + hh + 3)
        ..lineTo(c.dx - hw - 3, c.dy)
        ..close();
      canvas.drawPath(selPath, _selectedStroke);
    }

    // Draw X inside diamond.
    final xSize = min(hw, hh) * 0.45;
    final xPaint = Paint()
      ..color = Colors.black87
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawLine(
        Offset(c.dx - xSize, c.dy - xSize), Offset(c.dx + xSize, c.dy + xSize), xPaint);
    canvas.drawLine(
        Offset(c.dx + xSize, c.dy - xSize), Offset(c.dx - xSize, c.dy + xSize), xPaint);

    if (node.name.isNotEmpty) {
      _drawText(canvas, node.name, Offset(c.dx, node.rect.bottom + 14), fontSize: 11);
    }
  }

  void _drawConnectionPreview(Canvas canvas) {
    if (controller.isConnecting &&
        controller.connectionStart != null &&
        controller.connectionEnd != null) {
      canvas.drawLine(
          controller.connectionStart!, controller.connectionEnd!, _connectionPreviewPaint);

      // Draw a small circle at the end.
      canvas.drawCircle(
        controller.connectionEnd!,
        5,
        Paint()
          ..color = Colors.blue.withValues(alpha: 0.5)
          ..style = PaintingStyle.fill,
      );
    }
  }

  void _drawConnectorHandle(Canvas canvas) {
    if (controller.selectedNodeId == null || controller.isConnecting) return;
    final node = controller.diagram.nodes[controller.selectedNodeId];
    if (node == null) return;

    final handleCenter = Offset(node.rect.right + 18, node.rect.center.dy);
    canvas.drawCircle(handleCenter, 16, _handlePaint);

    // Draw arrow icon inside.
    final arrowPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(handleCenter.dx - 5, handleCenter.dy),
      Offset(handleCenter.dx + 5, handleCenter.dy),
      arrowPaint,
    );
    canvas.drawLine(
      Offset(handleCenter.dx + 1, handleCenter.dy - 5),
      Offset(handleCenter.dx + 6, handleCenter.dy),
      arrowPaint,
    );
    canvas.drawLine(
      Offset(handleCenter.dx + 1, handleCenter.dy + 5),
      Offset(handleCenter.dx + 6, handleCenter.dy),
      arrowPaint,
    );
  }

  void _drawText(Canvas canvas, String text, Offset center,
      {double fontSize = 13, double? maxWidth}) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: Colors.black87,
          fontSize: fontSize,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 2,
      ellipsis: '...',
    );
    tp.layout(maxWidth: maxWidth ?? 200);
    tp.paint(canvas, Offset(center.dx - tp.width / 2, center.dy - tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant DiagramPainter oldDelegate) => false;
}
