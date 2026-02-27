import 'package:flutter/material.dart';
import '../../diagram/edit/editor_controller.dart';
import '../../diagram/edit/hit_test.dart';
import '../../diagram/render/diagram_painter.dart';

/// The interactive diagram canvas with pan/zoom support.
class DiagramCanvas extends StatefulWidget {
  final EditorController controller;

  const DiagramCanvas({
    super.key,
    required this.controller,
  });

  @override
  State<DiagramCanvas> createState() => _DiagramCanvasState();
}

class _DiagramCanvasState extends State<DiagramCanvas> {
  final TransformationController _transformController =
      TransformationController();

  bool _isDiagramDrag = false;
  int? _activePointer;

  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
  }

  Widget _buildCanvas() {
    const canvasSize = Size(4000, 4000);
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (event) {
        final canvasPoint = event.localPosition;
        _activePointer = event.pointer;

        final ctrl = widget.controller;
        ctrl.updateDebugClosest(canvasPoint);

        final hit = HitTester().test(canvasPoint, ctrl.diagram,
            selectedNodeId: ctrl.selectedNodeId, forDrag: true);

        if (hit.hitNode || hit.isConnectorHandle) {
          _isDiagramDrag = true;
          ctrl.onTapDown(canvasPoint);
          ctrl.onDragStart(canvasPoint);
        } else {
          _isDiagramDrag = false;
          ctrl.onTapDown(canvasPoint);
        }
      },
      onPointerMove: (event) {
        widget.controller.updateDebugClosest(event.localPosition);
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, child) {
        final dragging =
            widget.controller.isDragging || widget.controller.isConnecting;
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
      child: _buildCanvas(),
    );
  }
}
