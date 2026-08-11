import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../model/diagram_model.dart';
import '../edit/editor_controller.dart';
import '../edit/hit_test.dart';
import 'merge_bar.dart';

/// Custom painter that draws the entire BPMN diagram on a canvas.
class DiagramPainter extends CustomPainter {
  final EditorController controller;
  final Map<String, ui.Image>? screenImages;

  // UI mode node dimensions (portrait phone screen).
  static const double _uiTaskWidth = 100.0;
  static const double _uiTaskHeight = 178.0;

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

  // UI mode paints.
  static final _phoneBezelPaint = Paint()
    ..color = const Color(0xFF1C1C1E)
    ..style = PaintingStyle.fill;
  static final _phoneScreenPaint = Paint()
    ..color = Colors.white
    ..style = PaintingStyle.fill;
  static final _phoneNotchPaint = Paint()
    ..color = const Color(0xFF1C1C1E)
    ..style = PaintingStyle.fill;
  static final _phoneScreenBorderPaint = Paint()
    ..color = const Color(0xFFE0E0E0)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 0.5;
  static final _phoneStatusBarPaint = Paint()
    ..color = const Color(0xFFBBBBBB)
    ..style = PaintingStyle.fill;
  static final _phoneNavBarPaint = Paint()
    ..color = const Color(0xFF333333)
    ..style = PaintingStyle.fill;

  DiagramPainter(this.controller, {this.screenImages}) : super(repaint: controller);

  /// Offset that shifts diagram coordinates into the widget's local space.
  /// Must match [_DiagramCanvasState._canvasOffset].
  static const _canvasOffset = Offset(2000, 2000);

  @override
  void paint(Canvas canvas, Size size) {
    _drawGrid(canvas, size);
    canvas.save();
    canvas.translate(_canvasOffset.dx, _canvasOffset.dy);

    if (controller.viewMode == ViewMode.ui) {
      _paintUiMode(canvas, size);
    } else {
      _paintDiagramMode(canvas, size);
    }

    canvas.restore();
  }

  void _paintDiagramMode(Canvas canvas, Size size) {
    final mergeBars = computeMergeBars(controller.diagram);
    final orphans = controller.diagram.orphanedNodeIds();
    _drawEdges(canvas, mergeBars, orphans);
    _drawMergeBars(canvas, mergeBars);
    _drawNodes(canvas, orphans);
    _drawSnapGuides(canvas, size);
    _drawConnectionPreview(canvas);
    _drawConnectorHandle(canvas);
  }

  void _paintUiMode(Canvas canvas, Size size) {
    final diagram = controller.diagram;
    // Build display-rect map for UI mode (portrait for tasks).
    final displayRects = <String, Rect>{};
    for (final node in diagram.nodes.values) {
      displayRects[node.id] = _uiDisplayRect(node);
    }
    _drawUiEdges(canvas, diagram, displayRects);
    _drawUiNodes(canvas, diagram, displayRects);
  }

  /// Returns the display rect for a node in UI mode.
  Rect _uiDisplayRect(NodeModel node) {
    if (node.type == NodeType.task) {
      return Rect.fromCenter(
        center: node.center,
        width: _uiTaskWidth,
        height: _uiTaskHeight,
      );
    }
    return node.rect;
  }

  /// Creates a virtual NodeModel with the UI display rect (for clipToNodeBorder).
  NodeModel _uiVirtualNode(NodeModel node, Rect displayRect) {
    if (displayRect == node.rect) return node;
    return NodeModel(
      id: node.id,
      type: node.type,
      name: node.name,
      rect: displayRect,
      content: node.content,
    );
  }

  void _drawGrid(Canvas canvas, Size size) {
    const step = 20.0;
    for (double x = 0; x < size.width; x += step) {
      for (double y = 0; y < size.height; y += step) {
        canvas.drawCircle(Offset(x, y), 0.7, _gridPaint);
      }
    }
  }

  // ── UI mode: edges ──
  void _drawUiEdges(Canvas canvas, DiagramModel diagram,
      Map<String, Rect> displayRects) {
    for (final edge in diagram.edges.values) {
      final isSelected = edge.id == controller.selectedEdgeId;
      final paint = isSelected ? _edgeSelectedPaint : _edgePaint;
      final arrowFill = isSelected ? _arrowSelectedPaint : _arrowPaint;

      final source = diagram.nodes[edge.sourceId];
      final target = diagram.nodes[edge.targetId];
      if (source == null || target == null) continue;

      final sourceRect = displayRects[source.id] ?? source.rect;
      final targetRect = displayRects[target.id] ?? target.rect;
      final virtualSource = _uiVirtualNode(source, sourceRect);
      final virtualTarget = _uiVirtualNode(target, targetRect);

      // Simple direct connection: source center → target center, clipped.
      final clippedStart = clipToNodeBorder(virtualSource, virtualTarget.center);
      final clippedEnd = clipToNodeBorder(virtualTarget, virtualSource.center);

      // Draw a simple L-shaped orthogonal edge.
      final path = Path();
      path.moveTo(clippedStart.dx, clippedStart.dy);

      // Determine the dominant exit direction and route orthogonally.
      final dx = clippedEnd.dx - clippedStart.dx;
      final dy = clippedEnd.dy - clippedStart.dy;
      final horizontal = dx.abs() > dy.abs();

      if (horizontal) {
        final midX = clippedStart.dx + dx / 2;
        path.lineTo(midX, clippedStart.dy);
        path.lineTo(midX, clippedEnd.dy);
      } else {
        final midY = clippedStart.dy + dy / 2;
        path.lineTo(clippedStart.dx, midY);
        path.lineTo(clippedEnd.dx, midY);
      }
      path.lineTo(clippedEnd.dx, clippedEnd.dy);
      canvas.drawPath(path, paint);

      // Arrowhead.
      final prevPt = horizontal
          ? Offset(clippedStart.dx + dx / 2, clippedEnd.dy)
          : Offset(clippedEnd.dx, clippedStart.dy + dy / 2);
      _drawArrow(canvas, prevPt, clippedEnd, arrowFill);

      // Edge name label.
      if (edge.name.isNotEmpty) {
        final labelPos = Offset(
          (clippedStart.dx + clippedEnd.dx) / 2,
          (clippedStart.dy + clippedEnd.dy) / 2 - 12,
        );
        _drawText(canvas, edge.name, labelPos, fontSize: 11, background: true);
      }
    }
  }

  // ── UI mode: nodes ──
  void _drawUiNodes(Canvas canvas, DiagramModel diagram,
      Map<String, Rect> displayRects) {
    for (final node in diagram.nodes.values) {
      final isSelected = node.id == controller.selectedNodeId;
      final displayRect = displayRects[node.id] ?? node.rect;

      if (node.type == NodeType.task) {
        _drawPhoneFrame(canvas, node, displayRect, isSelected);
      } else if (node.type == NodeType.startEvent) {
        _drawUiStartEvent(canvas, node, isSelected);
      } else if (node.type == NodeType.endEvent) {
        _drawUiEndEvent(canvas, node, isSelected);
      } else {
        // Gateway — keep diamond shape.
        final fill = _nodePaint;
        final stroke = isSelected ? _selectedStroke : null;
        _drawGatewayNode(canvas, node, isSelected, fill, stroke);
      }
    }
  }

  void _drawPhoneFrame(Canvas canvas, NodeModel node, Rect displayRect,
      bool selected) {
    final bezelRadius = Radius.circular(14);
    final screenRadius = Radius.circular(11);
    const bezelWidth = 4.0;

    // Phone body (bezel).
    final bodyRR = RRect.fromRectAndRadius(displayRect, bezelRadius);
    canvas.drawRRect(bodyRR, _phoneBezelPaint);

    // Screen area.
    final screenRect = displayRect.deflate(bezelWidth);
    final screenRR = RRect.fromRectAndRadius(screenRect, screenRadius);

    // Check for a screenshot image.
    final img = screenImages?[node.id];
    if (img != null) {
      // Clip to screen shape and draw the image.
      canvas.save();
      canvas.clipRRect(screenRR);
      final src = Rect.fromLTWH(
          0, 0, img.width.toDouble(), img.height.toDouble());
      canvas.drawImageRect(img, src, screenRect, Paint());
      canvas.restore();
    } else {
      // Placeholder gradient screen.
      final gradient = ui.Gradient.linear(
        screenRect.topCenter,
        screenRect.bottomCenter,
        [const Color(0xFFF8F9FA), const Color(0xFFE9ECEF)],
      );
      canvas.drawRRect(
          screenRR, Paint()..shader = gradient);
    }

    // Dynamic island / notch.
    final notchRR = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(displayRect.center.dx, screenRect.top + 10),
        width: 22,
        height: 7,
      ),
      const Radius.circular(4),
    );
    canvas.drawRRect(notchRR, _phoneNotchPaint);

    // Status bar indicators (time, signal, battery).
    final statusY = screenRect.top + 8;
    // Time (left).
    _drawText(canvas, '9:41', Offset(screenRect.left + 16, statusY),
        fontSize: 7);
    // Signal + battery (right) — simple dots.
    final batteryRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(screenRect.right - 12, statusY),
        width: 14,
        height: 6,
      ),
      const Radius.circular(1.5),
    );
    canvas.drawRRect(batteryRect, _phoneScreenBorderPaint);
    // Battery fill.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
            batteryRect.left + 1, batteryRect.top + 1,
            (batteryRect.width - 2) * 0.7, batteryRect.height - 2),
        const Radius.circular(0.5),
      ),
      Paint()..color = const Color(0xFF34C759),
    );

    // Node name centered on screen (below notch).
    final label = node.name.isNotEmpty ? node.name : 'Screen';
    _drawText(canvas, label,
        Offset(displayRect.center.dx, displayRect.center.dy - 10),
        fontSize: 11, maxWidth: screenRect.width - 12);

    // Content type hints.
    final content = node.content;
    if (content != null && !content.isEmpty) {
      if (content.text != null) {
        // Show text preview lines.
        for (int i = 0; i < 3; i++) {
          final y = displayRect.center.dy + 10 + i * 8.0;
          final lineWidth = screenRect.width * (i < 2 ? 0.6 : 0.35);
          canvas.drawLine(
            Offset(displayRect.center.dx - lineWidth / 2, y),
            Offset(displayRect.center.dx + lineWidth / 2, y),
            Paint()
              ..color = const Color(0xFFCCCCCC)
              ..strokeWidth = 2
              ..strokeCap = StrokeCap.round,
          );
        }
      }
    }

    // Home indicator bar at bottom.
    final homeBarRR = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(displayRect.center.dx, screenRect.bottom - 6),
        width: 30,
        height: 3,
      ),
      const Radius.circular(1.5),
    );
    canvas.drawRRect(homeBarRR, _phoneNavBarPaint);

    // Selection highlight.
    if (selected) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            displayRect.inflate(2), Radius.circular(16)),
        _selectedStroke,
      );
    }
  }

  void _drawUiStartEvent(Canvas canvas, NodeModel node, bool selected) {
    // Draw as a small app icon.
    final iconRect = Rect.fromCenter(
        center: node.center, width: 44, height: 44);
    final rr = RRect.fromRectAndRadius(iconRect, const Radius.circular(10));

    // Green gradient.
    final gradient = ui.Gradient.linear(
      iconRect.topCenter,
      iconRect.bottomCenter,
      [const Color(0xFF34C759), const Color(0xFF28A745)],
    );
    canvas.drawRRect(rr, Paint()..shader = gradient);

    // Play icon.
    final c = node.center;
    final playPath = Path()
      ..moveTo(c.dx - 6, c.dy - 8)
      ..lineTo(c.dx + 8, c.dy)
      ..lineTo(c.dx - 6, c.dy + 8)
      ..close();
    canvas.drawPath(playPath, Paint()..color = Colors.white);

    if (selected) {
      canvas.drawRRect(rr.inflate(2), _selectedStroke);
    }

    if (node.name.isNotEmpty) {
      _drawText(canvas, node.name,
          Offset(c.dx, node.rect.bottom + 14), fontSize: 11, background: true);
    }
  }

  void _drawUiEndEvent(Canvas canvas, NodeModel node, bool selected) {
    // Draw as a small stop icon.
    final iconRect = Rect.fromCenter(
        center: node.center, width: 44, height: 44);
    final rr = RRect.fromRectAndRadius(iconRect, const Radius.circular(10));

    // Red gradient.
    final gradient = ui.Gradient.linear(
      iconRect.topCenter,
      iconRect.bottomCenter,
      [const Color(0xFFFF3B30), const Color(0xFFCC2F26)],
    );
    canvas.drawRRect(rr, Paint()..shader = gradient);

    // Stop square.
    final c = node.center;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: c, width: 12, height: 12),
        const Radius.circular(2),
      ),
      Paint()..color = Colors.white,
    );

    if (selected) {
      canvas.drawRRect(rr.inflate(2), _selectedStroke);
    }

    if (node.name.isNotEmpty) {
      _drawText(canvas, node.name,
          Offset(c.dx, node.rect.bottom + 14), fontSize: 11, background: true);
    }
  }

  static final _orphanEdgePaint = Paint()
    ..color = Colors.red.withValues(alpha: 0.6)
    ..style = PaintingStyle.stroke
    ..strokeWidth = _strokeWidth;
  static final _orphanArrowPaint = Paint()
    ..color = Colors.red.withValues(alpha: 0.6)
    ..style = PaintingStyle.fill;

  void _drawEdges(Canvas canvas, Map<String, MergeBarInfo> mergeBars, Set<String> orphans) {
    final diagram = controller.diagram;
    for (final edge in diagram.edges.values) {
      final isSelected = edge.id == controller.selectedEdgeId;
      final isOrphanEdge = orphans.contains(edge.sourceId) || orphans.contains(edge.targetId);
      final paint = isSelected ? _edgeSelectedPaint : (isOrphanEdge ? _orphanEdgePaint : _edgePaint);
      final arrowFill = isSelected ? _arrowSelectedPaint : (isOrphanEdge ? _orphanArrowPaint : _arrowPaint);

      final source = diagram.nodes[edge.sourceId];
      final target = diagram.nodes[edge.targetId];
      if (source == null || target == null) continue;

      final wps = edge.waypoints.isNotEmpty
          ? edge.waypoints
          : [source.center, target.center];

      if (wps.length < 2) continue;

      // Clip start/end to node boundary, accounting for lift scale.
      // For routed edges, wps[0] is the source anchor on the border — clip
      // toward it to keep the first segment orthogonal.
      // For fallback center-to-center edges, wps[0] is at the center — use wps[1].
      final scaledSource = _applyLiftScale(source);
      final scaledTarget = _applyLiftScale(target);
      final clipDir =
          (wps[0] - scaledSource.center).distance > 1.0 ? wps[0] : wps[1];
      final clippedStart = clipToNodeBorder(scaledSource, clipDir);

      // Check if target has a merge bar.
      final mergeBar = mergeBars[edge.targetId];

      List<Offset> adjustedWps;
      bool skipArrow;

      if (mergeBar != null) {
        adjustedWps = adjustEdgeForMergeBar(wps, clippedStart, mergeBar, edge.id,
            obstacles: diagram.nodes.values.toList(),
            sourceId: edge.sourceId, targetId: edge.targetId);
        skipArrow = true;
      } else {
        final endClipDir =
            (wps.last - scaledTarget.center).distance > 1.0
                ? wps.last
                : wps[wps.length - 2];
        final clippedEnd = clipToNodeBorder(scaledTarget, endClipDir);
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

  static final _orphanFill = Paint()
    ..color = const Color(0x22FF0000)
    ..style = PaintingStyle.fill;
  static final _orphanStroke = Paint()
    ..color = Colors.red
    ..style = PaintingStyle.stroke
    ..strokeWidth = _strokeWidth;

  void _drawNodes(Canvas canvas, Set<String> orphans) {
    for (final node in controller.diagram.nodes.values) {
      final isLifted = node.id == controller.liftNodeId;
      final isConnectionTarget = node.id == controller.connectionTargetId;
      final isSelected = node.id == controller.selectedNodeId || isLifted || isConnectionTarget;
      final isBlob = node.id == controller.blobNodeId && controller.blobScale != 1.0;
      final isOrphan = orphans.contains(node.id);

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

      final fill = isOrphan ? _orphanFill : _nodePaint;

      final stroke = isSelected ? _selectedStroke : (isOrphan ? _orphanStroke : null);

      switch (node.type) {
        case NodeType.startEvent:
          _drawCircleNode(canvas, node, isSelected, false, fill, stroke);
          break;
        case NodeType.endEvent:
          _drawCircleNode(canvas, node, isSelected, true, fill, stroke);
          break;
        case NodeType.task:
          _drawTaskNode(canvas, node, isSelected, fill, stroke);
          break;
        case NodeType.exclusiveGateway:
          _drawGatewayNode(canvas, node, isSelected, fill, stroke);
          break;
      }

      if (needsScale) {
        canvas.restore();
      }
    }
  }

  void _drawCircleNode(Canvas canvas, NodeModel node, bool selected, bool thick, Paint fill, [Paint? overrideStroke]) {
    final c = node.center;
    final r = node.rect.width / 2;

    canvas.drawCircle(c, r, fill);
    canvas.drawCircle(c, r, overrideStroke ?? (selected ? _selectedStroke : (thick ? _endNodeStroke : _nodeStroke)));

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

  static final _iconPaint = Paint()
    ..color = Colors.black45
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.5;

  void _drawTaskNode(Canvas canvas, NodeModel node, bool selected, Paint fill, [Paint? overrideStroke]) {
    final rr = RRect.fromRectAndRadius(node.rect, const Radius.circular(8));
    canvas.drawRRect(rr, fill);
    canvas.drawRRect(rr, overrideStroke ?? (selected ? _selectedStroke : _nodeStroke));

    // Draw name centered.
    final label = node.name.isNotEmpty ? node.name : 'Task';
    _drawText(canvas, label, node.center, fontSize: 13, maxWidth: node.rect.width - 12);

    // Draw content type indicators in bottom-right corner.
    final content = node.content;
    if (content != null && !content.isEmpty) {
      double iconX = node.rect.right - 10;
      final iconY = node.rect.bottom - 10;
      const iconSize = 8.0;

      if (content.imagePath != null) {
        // Small image icon (rectangle with mountain).
        canvas.drawRect(
          Rect.fromCenter(center: Offset(iconX, iconY), width: iconSize, height: iconSize),
          _iconPaint,
        );
        iconX -= 14;
      }
      if (content.videoPath != null) {
        // Small play triangle.
        final path = Path()
          ..moveTo(iconX - 4, iconY - 4)
          ..lineTo(iconX + 4, iconY)
          ..lineTo(iconX - 4, iconY + 4)
          ..close();
        canvas.drawPath(path, _iconPaint);
        iconX -= 14;
      }
      if (content.text != null) {
        // Small text lines icon.
        canvas.drawLine(Offset(iconX - 4, iconY - 3), Offset(iconX + 4, iconY - 3), _iconPaint);
        canvas.drawLine(Offset(iconX - 4, iconY + 1), Offset(iconX + 3, iconY + 1), _iconPaint);
        iconX -= 14;
      }
    }
  }

  void _drawGatewayNode(Canvas canvas, NodeModel node, bool selected, Paint fill, [Paint? overrideStroke]) {
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
    canvas.drawPath(path, overrideStroke ?? (selected ? _selectedStroke : _nodeStroke));

    if (node.name.isNotEmpty) {
      // Place gateway label above the diamond tip.
      _drawText(canvas, node.name, Offset(c.dx, node.rect.top - 10), fontSize: 11, background: true);
    }
  }

  void _drawSnapGuides(Canvas canvas, Size size) {
    // Snap guide lines disabled.
    // if (!controller.isDragging) return;
    //
    // if (controller.snapGuideX != null) {
    //   canvas.drawLine(
    //     Offset(controller.snapGuideX!, 0),
    //     Offset(controller.snapGuideX!, size.height),
    //     _snapGuidePaint,
    //   );
    // }
    // if (controller.snapGuideY != null) {
    //   canvas.drawLine(
    //     Offset(0, controller.snapGuideY!),
    //     Offset(size.width, controller.snapGuideY!),
    //     _snapGuidePaint,
    //   );
    // }
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
          case ConnectorSide.topLeft:
            stub = Offset(start.dx, start.dy - stubLen);
            path.lineTo(stub.dx, stub.dy);
            path.lineTo(end.dx, stub.dy);
            break;
          case ConnectorSide.right:
          case ConnectorSide.topRight:
            stub = Offset(start.dx + stubLen, start.dy);
            path.lineTo(stub.dx, stub.dy);
            path.lineTo(stub.dx, end.dy);
            break;
          case ConnectorSide.bottom:
          case ConnectorSide.bottomRight:
            stub = Offset(start.dx, start.dy + stubLen);
            path.lineTo(stub.dx, stub.dy);
            path.lineTo(end.dx, stub.dy);
            break;
          case ConnectorSide.left:
          case ConnectorSide.bottomLeft:
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

    for (final side in ConnectorSide.cardinal) {
      final center = connectorHandleCenter(node, side);
      canvas.drawCircle(center, 6, _handlePaint);
    }
  }

  /// Returns a node with its rect scaled by the lift factor if it's being lifted.
  NodeModel _applyLiftScale(NodeModel node) {
    if (node.id != controller.liftNodeId || controller.liftScale == 1.0) {
      return node;
    }
    final s = controller.liftScale;
    final c = node.center;
    final scaledRect = Rect.fromCenter(
      center: c,
      width: node.rect.width * s,
      height: node.rect.height * s,
    );
    return NodeModel(
      id: node.id,
      type: node.type,
      name: node.name,
      rect: scaledRect,
      content: node.content,
    );
  }

  static final _labelBgPaint = Paint()
    ..color = Colors.white.withValues(alpha: 0.75)
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
