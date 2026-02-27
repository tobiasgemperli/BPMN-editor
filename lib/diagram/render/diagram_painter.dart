import 'dart:math';
import 'package:flutter/material.dart';
import '../model/diagram_model.dart';
import '../edit/editor_controller.dart';
import '../edit/hit_test.dart';
import 'merge_bar.dart';

/// Custom painter that draws the entire BPMN diagram on a canvas.
class DiagramPainter extends CustomPainter {
  final EditorController controller;

  // Merge bar constants.
  static const double _mergeBarThickness = 3.5;

  // Cached paints.
  static final _nodePaint = Paint()
    ..color = Colors.white
    ..style = PaintingStyle.fill;
  static const double _strokeWidth = 2.0;
  static final _nodeStroke = Paint()
    ..color = Colors.black87
    ..style = PaintingStyle.stroke
    ..strokeWidth = _strokeWidth;
  static final _endNodeStroke = Paint()
    ..color = Colors.black87
    ..style = PaintingStyle.stroke
    ..strokeWidth = _strokeWidth;
  static final _selectedStroke = Paint()
    ..color = Colors.blue
    ..style = PaintingStyle.stroke
    ..strokeWidth = _strokeWidth;
  static final _edgePaint = Paint()
    ..color = Colors.black87
    ..style = PaintingStyle.stroke
    ..strokeWidth = _strokeWidth;
  static final _edgeSelectedPaint = Paint()
    ..color = Colors.blue
    ..style = PaintingStyle.stroke
    ..strokeWidth = _strokeWidth;
  static final _arrowPaint = Paint()
    ..color = Colors.black87
    ..style = PaintingStyle.fill;
  static final _arrowSelectedPaint = Paint()
    ..color = Colors.blue
    ..style = PaintingStyle.fill;
  static final _connectionPreviewPaint = Paint()
    ..color = Colors.blue.withValues(alpha: 0.5)
    ..style = PaintingStyle.stroke
    ..strokeWidth = _strokeWidth
    ..strokeCap = StrokeCap.round;
  static final _handlePaint = Paint()
    ..color = Colors.blue
    ..style = PaintingStyle.fill;
  static final _gridPaint = Paint()
    ..color = const Color(0x22000000)
    ..style = PaintingStyle.fill;
  static final _snapGuidePaint = Paint()
    ..color = Colors.red
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.0;
  static final _mergeBarPaint = Paint()
    ..color = Colors.black87
    ..style = PaintingStyle.stroke
    ..strokeWidth = _mergeBarThickness
    ..strokeCap = StrokeCap.round;
  static final _mergeConnectorPaint = Paint()
    ..color = Colors.black87
    ..style = PaintingStyle.stroke
    ..strokeWidth = _strokeWidth;

  DiagramPainter(this.controller) : super(repaint: controller);

  @override
  void paint(Canvas canvas, Size size) {
    _drawGrid(canvas, size);
    final mergeBars = computeMergeBars(controller.diagram);
    _drawEdges(canvas, mergeBars);
    _drawMergeBars(canvas, mergeBars);
    _drawNodes(canvas);
    _drawSnapGuides(canvas, size);
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

  void _drawEdges(Canvas canvas, Map<String, MergeBarInfo> mergeBars) {
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

      // Clip start to source node boundary.
      final clippedStart = clipToNodeBorder(source, wps[1]);

      // Check if target has a merge bar.
      final mergeBar = mergeBars[edge.targetId];

      List<Offset> adjustedWps;
      bool skipArrow;

      if (mergeBar != null) {
        adjustedWps = adjustEdgeForMergeBar(wps, clippedStart, mergeBar, edge.id);
        skipArrow = true;
      } else {
        final clippedEnd = clipToNodeBorder(target, wps[wps.length - 2]);
        adjustedWps = [clippedStart, ...wps.sublist(1, wps.length - 1), clippedEnd];
        skipArrow = false;
      }

      // Draw polyline.
      final path = Path();
      path.moveTo(adjustedWps[0].dx, adjustedWps[0].dy);
      for (int i = 1; i < adjustedWps.length; i++) {
        path.lineTo(adjustedWps[i].dx, adjustedWps[i].dy);
      }
      canvas.drawPath(path, paint);

      // Arrowhead at the end (skip if edge terminates at a merge bar).
      if (!skipArrow) {
        _drawArrow(canvas, adjustedWps[adjustedWps.length - 2], adjustedWps.last, arrowFill);
      }

      // Draw edge name on the first segment, near the source.
      if (edge.name.isNotEmpty && adjustedWps.length >= 2) {
        final p0 = adjustedWps[0];
        final p1 = adjustedWps[1];
        // Place at 30% along the first segment (closer to source).
        final t = 0.3;
        final ptX = p0.dx + (p1.dx - p0.dx) * t;
        final ptY = p0.dy + (p1.dy - p0.dy) * t;
        final isVertical = (p0.dx - p1.dx).abs() < 1.0;
        final labelPos = isVertical
            ? Offset(ptX + 18, ptY)    // offset right for vertical segments
            : Offset(ptX, ptY - 12);   // offset up for horizontal segments
        _drawText(canvas, edge.name, labelPos, fontSize: 11, background: true);
      }
    }
  }

  void _drawMergeBars(Canvas canvas, Map<String, MergeBarInfo> mergeBars) {
    for (final bar in mergeBars.values) {
      // Draw the thick bar line.
      final barStart = bar.isHorizontal
          ? Offset(bar.minCross, bar.barPos)
          : Offset(bar.barPos, bar.minCross);
      final barEnd = bar.isHorizontal
          ? Offset(bar.maxCross, bar.barPos)
          : Offset(bar.barPos, bar.maxCross);
      canvas.drawLine(barStart, barEnd, _mergeBarPaint);

      // Draw the connector from bar center to the node border.
      final barCenter = bar.isHorizontal
          ? Offset(bar.nodeCenter.dx, bar.barPos)
          : Offset(bar.barPos, bar.nodeCenter.dy);
      canvas.drawLine(barCenter, bar.connectorNodePoint, _mergeConnectorPaint);

      // Arrowhead on the connector at the node border.
      _drawArrow(canvas, barCenter, bar.connectorNodePoint, _arrowPaint);
    }
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
      final isLifted = node.id == controller.liftNodeId;
      final isConnectionTarget = node.id == controller.connectionTargetId;
      final isSelected = node.id == controller.selectedNodeId || isLifted || isConnectionTarget;
      final isBlob = node.id == controller.blobNodeId && controller.blobScale != 1.0;

      // Apply scale transforms (lift or blob, lift takes priority).
      final needsScale = (isLifted && controller.liftScale != 1.0) || isBlob;
      if (needsScale) {
        final scale = isLifted ? controller.liftScale : controller.blobScale;
        final c = node.center;
        canvas.save();
        canvas.translate(c.dx, c.dy);
        canvas.scale(scale);
        canvas.translate(-c.dx, -c.dy);
      }

      final fill = _nodePaint;

      switch (node.type) {
        case NodeType.startEvent:
          _drawCircleNode(canvas, node, isSelected, false, fill);
          break;
        case NodeType.endEvent:
          _drawCircleNode(canvas, node, isSelected, true, fill);
          break;
        case NodeType.task:
          _drawTaskNode(canvas, node, isSelected, fill);
          break;
        case NodeType.exclusiveGateway:
          _drawGatewayNode(canvas, node, isSelected, fill);
          break;
      }

      if (needsScale) {
        canvas.restore();
      }
    }
  }

  void _drawCircleNode(Canvas canvas, NodeModel node, bool selected, bool thick, Paint fill) {
    final c = node.center;
    final r = node.rect.width / 2;

    canvas.drawCircle(c, r, fill);
    canvas.drawCircle(c, r, selected ? _selectedStroke : (thick ? _endNodeStroke : _nodeStroke));

    // Draw X inside end events.
    if (thick) {
      final xSize = r * 0.707;
      final xPaint = selected ? _selectedStroke : (Paint()
        ..color = Colors.black87
        ..style = PaintingStyle.stroke
        ..strokeWidth = _strokeWidth);
      canvas.drawLine(
          Offset(c.dx - xSize, c.dy - xSize), Offset(c.dx + xSize, c.dy + xSize), xPaint);
      canvas.drawLine(
          Offset(c.dx + xSize, c.dy - xSize), Offset(c.dx - xSize, c.dy + xSize), xPaint);
    }

    if (node.name.isNotEmpty) {
      _drawText(canvas, node.name, Offset(c.dx, node.rect.bottom + 14), fontSize: 11, background: true);
    }
  }

  void _drawTaskNode(Canvas canvas, NodeModel node, bool selected, Paint fill) {
    final rr = RRect.fromRectAndRadius(node.rect, const Radius.circular(8));
    canvas.drawRRect(rr, fill);
    canvas.drawRRect(rr, selected ? _selectedStroke : _nodeStroke);

    // Draw name centered.
    final label = node.name.isNotEmpty ? node.name : 'Task';
    _drawText(canvas, label, node.center, fontSize: 13, maxWidth: node.rect.width - 12);
  }

  void _drawGatewayNode(Canvas canvas, NodeModel node, bool selected, Paint fill) {
    final c = node.center;
    final hw = node.rect.width / 2;
    final hh = node.rect.height / 2;

    final path = Path()
      ..moveTo(c.dx, c.dy - hh)
      ..lineTo(c.dx + hw, c.dy)
      ..lineTo(c.dx, c.dy + hh)
      ..lineTo(c.dx - hw, c.dy)
      ..close();

    canvas.drawPath(path, fill);
    canvas.drawPath(path, selected ? _selectedStroke : _nodeStroke);

    if (node.name.isNotEmpty) {
      // Place gateway label above the diamond where the incoming line arrives.
      _drawText(canvas, node.name, Offset(c.dx, node.rect.top - 14), fontSize: 11, background: true);
    }
  }

  void _drawSnapGuides(Canvas canvas, Size size) {
    if (!controller.isDragging) return;

    if (controller.snapGuideX != null) {
      canvas.drawLine(
        Offset(controller.snapGuideX!, 0),
        Offset(controller.snapGuideX!, size.height),
        _snapGuidePaint,
      );
    }
    if (controller.snapGuideY != null) {
      canvas.drawLine(
        Offset(0, controller.snapGuideY!),
        Offset(size.width, controller.snapGuideY!),
        _snapGuidePaint,
      );
    }
  }

  void _drawConnectionPreview(Canvas canvas) {
    if (controller.isConnecting &&
        controller.connectionStart != null &&
        controller.connectionEnd != null) {
      final start = controller.connectionStart!;
      final end = controller.connectionEnd!;
      final side = controller.connectionSourceSide;

      // Draw orthogonal L-shaped preview.
      final path = Path();
      path.moveTo(start.dx, start.dy);

      if (side != null) {
        // Stub out from the source side, then bend toward cursor.
        const stubLen = 30.0;
        Offset stub;
        switch (side) {
          case ConnectorSide.top:
            stub = Offset(start.dx, start.dy - stubLen);
            path.lineTo(stub.dx, stub.dy);
            path.lineTo(end.dx, stub.dy);
            break;
          case ConnectorSide.right:
            stub = Offset(start.dx + stubLen, start.dy);
            path.lineTo(stub.dx, stub.dy);
            path.lineTo(stub.dx, end.dy);
            break;
          case ConnectorSide.bottom:
            stub = Offset(start.dx, start.dy + stubLen);
            path.lineTo(stub.dx, stub.dy);
            path.lineTo(end.dx, stub.dy);
            break;
          case ConnectorSide.left:
            stub = Offset(start.dx - stubLen, start.dy);
            path.lineTo(stub.dx, stub.dy);
            path.lineTo(stub.dx, end.dy);
            break;
        }
      }

      path.lineTo(end.dx, end.dy);
      canvas.drawPath(path, _connectionPreviewPaint);

      // Draw a small circle at the end.
      canvas.drawCircle(
        end,
        5,
        Paint()
          ..color = Colors.blue.withValues(alpha: 0.5)
          ..style = PaintingStyle.fill,
      );
    }
  }

  void _drawConnectorHandle(Canvas canvas) {
    if (controller.selectedNodeId == null || controller.isConnecting || controller.isDragging) return;
    if (controller.liftNodeId != null) return;
    if (controller.blobNodeId == controller.selectedNodeId && controller.blobScale != 1.0) return;
    if (!controller.canDrawFrom(controller.selectedNodeId!)) return;
    final node = controller.diagram.nodes[controller.selectedNodeId];
    if (node == null) return;

    for (final side in ConnectorSide.values) {
      final center = connectorHandleCenter(node, side);
      canvas.drawCircle(center, 6, _handlePaint);
    }
  }

  static final _labelBgPaint = Paint()
    ..color = Colors.white
    ..style = PaintingStyle.fill;
  static const _labelPadH = 6.0;
  static const _labelPadV = 2.0;
  static const _labelRadius = Radius.circular(4);

  void _drawText(Canvas canvas, String text, Offset center,
      {double fontSize = 13, double? maxWidth, bool background = false, bool alignRight = false}) {
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

    // alignRight: right edge of text aligns to center.dx
    final topLeft = alignRight
        ? Offset(center.dx - tp.width, center.dy - tp.height / 2)
        : Offset(center.dx - tp.width / 2, center.dy - tp.height / 2);

    if (background) {
      final bgRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          topLeft.dx - _labelPadH,
          topLeft.dy - _labelPadV,
          tp.width + _labelPadH * 2,
          tp.height + _labelPadV * 2,
        ),
        _labelRadius,
      );
      canvas.drawRRect(bgRect, _labelBgPaint);
    }

    tp.paint(canvas, topLeft);
  }

  @override
  bool shouldRepaint(covariant DiagramPainter oldDelegate) => false;
}
