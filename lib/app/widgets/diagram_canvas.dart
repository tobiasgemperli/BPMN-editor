import 'package:flutter/material.dart';
import '../../diagram/edit/editor_controller.dart';
import '../../diagram/edit/hit_test.dart';
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

  /// Whether the current gesture is dragging a node/connection (vs canvas pan).
  bool _isDiagramDrag = false;
  int? _activePointer;

  Offset _toCanvasPoint(Offset screenPoint) {
    final inv = Matrix4.inverted(_transformController.value);
    return MatrixUtils.transformPoint(inv, screenPoint);
  }

  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const canvasSize = Size(4000, 4000);

    return GestureDetector(
      onLongPressStart: (details) {
        final canvasPoint = _toCanvasPoint(details.localPosition);
        final isEmpty = widget.controller.onLongPress(canvasPoint);
        if (isEmpty) {
          widget.onLongPressPosition?.call(canvasPoint);
        }
      },
      child: ListenableBuilder(
        listenable: widget.controller,
        builder: (context, child) {
          final dragging = widget.controller.isDragging || widget.controller.isConnecting;
          return InteractiveViewer(
            transformationController: _transformController,
            constrained: false,
            boundaryMargin: const EdgeInsets.all(2000),
            minScale: 0.2,
            maxScale: 3.0,
            panEnabled: !dragging,
            scaleEnabled: !dragging,
            child: child!,
          );
        },
        child: Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: (event) {
            final canvasPoint = event.localPosition;
            _activePointer = event.pointer;

            // Check if we're hitting a node or connector handle
            // using the same hit tester as the editor controller.
            final ctrl = widget.controller;
            final hit = HitTester().test(canvasPoint, ctrl.diagram,
                selectedNodeId: ctrl.selectedNodeId, forDrag: true);

            if (hit.hitNode || hit.isConnectorHandle) {
              // We'll handle this as a diagram drag.
              _isDiagramDrag = true;
              ctrl.onTapDown(canvasPoint);
              ctrl.onDragStart(canvasPoint);
            } else {
              // Let InteractiveViewer handle pan/zoom.
              _isDiagramDrag = false;
              ctrl.onTapDown(canvasPoint);
            }
          },
          onPointerMove: (event) {
            if (_isDiagramDrag && event.pointer == _activePointer) {
              widget.controller.onDragUpdate(event.localPosition);
            }
          },
          onPointerUp: (event) {
            if (_isDiagramDrag && event.pointer == _activePointer) {
              final ctrl = widget.controller;
              ctrl.onDragEnd(
                ctrl.isConnecting
                    ? (ctrl.connectionEnd ?? Offset.zero)
                    : (ctrl.selectedNodeId != null
                        ? ctrl.diagram.nodes[ctrl.selectedNodeId]!.center
                        : Offset.zero),
              );
            }
            _isDiagramDrag = false;
            _activePointer = null;
          },
          onPointerCancel: (event) {
            if (_isDiagramDrag && event.pointer == _activePointer) {
              widget.controller.onDragEnd(Offset.zero);
            }
            _isDiagramDrag = false;
            _activePointer = null;
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
  }
}
