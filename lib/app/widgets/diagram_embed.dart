import 'package:flutter/material.dart';
import '../../diagram/edit/editor_controller.dart';
import '../../diagram/model/diagram_model.dart';
import '../../diagram/render/diagram_painter.dart';

/// A lightweight, read-only diagram embed that auto-fits the diagram
/// into the available space. No interaction — just a static rendering.
class DiagramEmbed extends StatefulWidget {
  final DiagramModel diagram;
  final Color backgroundColor;
  final bool showBorder;

  const DiagramEmbed({
    super.key,
    required this.diagram,
    this.backgroundColor = Colors.white,
    this.showBorder = true,
  });

  @override
  State<DiagramEmbed> createState() => _DiagramEmbedState();
}

class _DiagramEmbedState extends State<DiagramEmbed> {
  late final EditorController _controller;

  @override
  void initState() {
    super.initState();
    _controller = EditorController();
    _controller.loadDiagram(widget.diagram);
  }

  @override
  void didUpdateWidget(DiagramEmbed oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.diagram != widget.diagram) {
      _controller.loadDiagram(widget.diagram);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Compute bounding box of the diagram to auto-fit.
    final bbox = _computeBBox(widget.diagram);

    return Container(
      decoration: BoxDecoration(
        color: widget.backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: widget.showBorder
            ? Border.all(color: Colors.grey[300]!, width: 1)
            : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final viewW = constraints.maxWidth;
          final viewH = constraints.maxHeight;

          // Scale to fit with padding.
          const padding = 40.0;
          final scaleX = (viewW - padding) / bbox.width;
          final scaleY = (viewH - padding) / bbox.height;
          final scale = scaleX < scaleY ? scaleX : scaleY;

          // Center the diagram.
          final scaledW = bbox.width * scale;
          final scaledH = bbox.height * scale;
          final tx = (viewW - scaledW) / 2 - bbox.left * scale;
          final ty = (viewH - scaledH) / 2 - bbox.top * scale;

          return CustomPaint(
            size: Size(viewW, viewH),
            painter: _EmbedPainter(
              controller: _controller,
              scale: scale,
              translateX: tx,
              translateY: ty,
            ),
          );
        },
      ),
    );
  }

  Rect _computeBBox(DiagramModel diagram) {
    if (diagram.nodes.isEmpty) {
      return const Rect.fromLTWH(0, 0, 400, 400);
    }

    double minX = double.infinity, minY = double.infinity;
    double maxX = -double.infinity, maxY = -double.infinity;

    for (final node in diagram.nodes.values) {
      if (node.rect.left < minX) minX = node.rect.left;
      if (node.rect.top < minY) minY = node.rect.top;
      if (node.rect.right > maxX) maxX = node.rect.right;
      if (node.rect.bottom > maxY) maxY = node.rect.bottom;
    }

    // Include edge waypoints.
    for (final edge in diagram.edges.values) {
      for (final wp in edge.waypoints) {
        if (wp.dx < minX) minX = wp.dx;
        if (wp.dy < minY) minY = wp.dy;
        if (wp.dx > maxX) maxX = wp.dx;
        if (wp.dy > maxY) maxY = wp.dy;
      }
    }

    return Rect.fromLTRB(minX - 20, minY - 20, maxX + 20, maxY + 20);
  }
}

/// Wraps DiagramPainter with a transform to auto-fit.
class _EmbedPainter extends CustomPainter {
  final EditorController controller;
  final double scale;
  final double translateX;
  final double translateY;

  _EmbedPainter({
    required this.controller,
    required this.scale,
    required this.translateX,
    required this.translateY,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(translateX, translateY);
    canvas.scale(scale);
    DiagramPainter(controller).paint(canvas, size);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_EmbedPainter old) => true;
}
