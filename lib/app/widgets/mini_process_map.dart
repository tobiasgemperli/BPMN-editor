import 'package:flutter/material.dart';
import '../../diagram/model/diagram_model.dart';

/// Mini flowchart with uniform dot density across all diagrams.
/// Supports both vertical (portrait/mobile) and horizontal (landscape/web)
/// orientations.
class MiniProcessMap extends StatelessWidget {
  final List<NodeModel> steps;
  final DiagramModel diagram;
  final String currentNodeId;

  /// If true, render the diagram horizontally (swap X/Y from portrait layout).
  final bool horizontal;

  /// Background color of the container.
  final Color backgroundColor;

  /// Whether to show a shadow.
  final bool showShadow;

  const MiniProcessMap({
    super.key,
    required this.steps,
    required this.diagram,
    required this.currentNodeId,
    this.horizontal = false,
    this.backgroundColor = Colors.white,
    this.showShadow = true,
  });

  @override
  Widget build(BuildContext context) {
    if (steps.isEmpty) return const SizedBox.shrink();

    const targetDist = 16.0;
    const padding = 8.0;

    // Compute bounding box of all step nodes.
    double minX = double.infinity, minY = double.infinity;
    double maxX = -double.infinity, maxY = -double.infinity;
    for (final node in steps) {
      final c = _nodeCenter(node);
      if (c.dx < minX) minX = c.dx;
      if (c.dy < minY) minY = c.dy;
      if (c.dx > maxX) maxX = c.dx;
      if (c.dy > maxY) maxY = c.dy;
    }

    final diagramW = (maxX - minX).clamp(1.0, double.infinity);
    final diagramH = (maxY - minY).clamp(1.0, double.infinity);

    // Compute average edge length.
    final stepIds = {for (final s in steps) s.id};
    double totalDist = 0;
    int edgeCount = 0;
    for (final edge in diagram.edges.values) {
      if (!stepIds.contains(edge.sourceId) ||
          !stepIds.contains(edge.targetId)) continue;
      final src = diagram.nodes[edge.sourceId];
      final tgt = diagram.nodes[edge.targetId];
      if (src == null || tgt == null) continue;
      totalDist +=
          (_nodeCenter(src) - _nodeCenter(tgt)).distance;
      edgeCount++;
    }
    final avgDist =
        edgeCount > 0 ? totalDist / edgeCount : (horizontal ? diagramW : diagramH);

    final scale = targetDist / avgDist;

    final mapW = diagramW * scale + padding * 2;
    final mapH = diagramH * scale + padding * 2;

    return Container(
      width: mapW + 12,
      height: mapH + 12,
      decoration: BoxDecoration(
        color: backgroundColor.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(10),
        boxShadow: showShadow
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      alignment: Alignment.center,
      child: CustomPaint(
        size: Size(mapW, mapH),
        painter: _MiniFlowPainter(
          steps: steps,
          diagram: diagram,
          currentNodeId: currentNodeId,
          originX: minX,
          originY: minY,
          scale: scale,
          padding: padding,
          horizontal: horizontal,
        ),
      ),
    );
  }

  /// Get the effective center of a node, swapping X/Y for horizontal mode.
  Offset _nodeCenter(NodeModel node) {
    final c = node.rect.center;
    return horizontal ? Offset(c.dy, c.dx) : c;
  }
}

class _MiniFlowPainter extends CustomPainter {
  final List<NodeModel> steps;
  final DiagramModel diagram;
  final String currentNodeId;
  final double originX, originY, scale, padding;
  final bool horizontal;

  _MiniFlowPainter({
    required this.steps,
    required this.diagram,
    required this.currentNodeId,
    required this.originX,
    required this.originY,
    required this.scale,
    required this.padding,
    required this.horizontal,
  });

  Offset _toMapped(Offset diagramCenter) {
    final c = horizontal ? Offset(diagramCenter.dy, diagramCenter.dx) : diagramCenter;
    return Offset(
      (c.dx - originX) * scale + padding,
      (c.dy - originY) * scale + padding,
    );
  }

  Offset _mapWaypoint(Offset wp) {
    final c = horizontal ? Offset(wp.dy, wp.dx) : wp;
    return Offset(
      (c.dx - originX) * scale + padding,
      (c.dy - originY) * scale + padding,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    const dotRadius = 4.0;
    const diamondSize = 5.5;

    final linePaint = Paint()
      ..color = Colors.black26
      ..strokeWidth = 1;

    final currentPaint = Paint()..color = Colors.black;
    final futurePaint = Paint()..color = Colors.black26;

    final stepIds = {for (final s in steps) s.id};

    // Draw edges.
    for (final edge in diagram.edges.values) {
      if (!stepIds.contains(edge.sourceId) ||
          !stepIds.contains(edge.targetId)) {
        continue;
      }
      final srcNode = diagram.nodes[edge.sourceId];
      final tgtNode = diagram.nodes[edge.targetId];
      if (srcNode == null || tgtNode == null) continue;

      final points = <Offset>[
        _toMapped(srcNode.rect.center),
        if (edge.waypoints.length >= 3)
          for (int i = 1; i < edge.waypoints.length - 1; i++)
            _mapWaypoint(edge.waypoints[i]),
        _toMapped(tgtNode.rect.center),
      ];
      for (int i = 0; i < points.length - 1; i++) {
        canvas.drawLine(points[i], points[i + 1], linePaint);
      }
    }

    // Draw nodes on top.
    final bgPaint = Paint()..color = Colors.white;
    for (final node in steps) {
      final center = _toMapped(node.rect.center);
      final paint = node.id == currentNodeId ? currentPaint : futurePaint;

      if (node.type == NodeType.exclusiveGateway) {
        final path = Path()
          ..moveTo(center.dx, center.dy - diamondSize)
          ..lineTo(center.dx + diamondSize, center.dy)
          ..lineTo(center.dx, center.dy + diamondSize)
          ..lineTo(center.dx - diamondSize, center.dy)
          ..close();
        canvas.drawPath(path, bgPaint);
        canvas.drawPath(path, paint);
      } else {
        canvas.drawCircle(center, dotRadius, bgPaint);
        canvas.drawCircle(center, dotRadius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_MiniFlowPainter oldDelegate) =>
      oldDelegate.currentNodeId != currentNodeId;
}
