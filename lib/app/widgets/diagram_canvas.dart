import 'package:flutter/material.dart';
import '../../diagram/edit/editor_controller.dart';
import '../../diagram/render/diagram_painter.dart';

/// The interactive diagram canvas with pan/zoom support.
class DiagramCanvas extends StatefulWidget {
  final EditorController controller;
  final VoidCallback? onLongPressEmpty;
  final void Function(Offset position)? onLongPressPosition;

  const DiagramCanvas({
    super.key,
    required this.controller,
    this.onLongPressEmpty,
    this.onLongPressPosition,
  });

  @override
  State<DiagramCanvas> createState() => _DiagramCanvasState();
}

class _DiagramCanvasState extends State<DiagramCanvas> {
  final TransformationController _transformController = TransformationController();

  Offset _toCanvasPoint(Offset screenPoint) {
    final inv = Matrix4.inverted(_transformController.value);
    final v = MatrixUtils.transformPoint(inv, screenPoint);
    return v;
  }

  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Canvas is larger than viewport for scrolling.
        const canvasSize = Size(4000, 4000);

        return GestureDetector(
          onLongPressStart: (details) {
            final canvasPoint = _toCanvasPoint(details.localPosition);
            final isEmpty = widget.controller.onLongPress(canvasPoint);
            if (isEmpty) {
              widget.onLongPressPosition?.call(canvasPoint);
            }
          },
          child: InteractiveViewer(
            transformationController: _transformController,
            constrained: false,
            boundaryMargin: const EdgeInsets.all(2000),
            minScale: 0.2,
            maxScale: 3.0,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (details) {
                widget.controller.onTapDown(details.localPosition);
              },
              onPanStart: (details) {
                widget.controller.onDragStart(details.localPosition);
              },
              onPanUpdate: (details) {
                widget.controller.onDragUpdate(details.localPosition);
              },
              onPanEnd: (details) {
                widget.controller.onDragEnd(
                  // Use the last known position.
                  widget.controller.isConnecting
                      ? (widget.controller.connectionEnd ?? Offset.zero)
                      : (widget.controller.selectedNodeId != null
                          ? widget.controller.diagram.nodes[widget.controller.selectedNodeId]!.center
                          : Offset.zero),
                );
              },
              child: SizedBox(
                width: canvasSize.width,
                height: canvasSize.height,
                child: RepaintBoundary(
                  child: CustomPaint(
                    painter: DiagramPainter(widget.controller),
                    size: canvasSize,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
