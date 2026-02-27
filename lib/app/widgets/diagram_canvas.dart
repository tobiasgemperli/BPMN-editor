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

        // Use the debug closest point to decide: if it's a connector
        // handle, start a connection. If it's a node center, prepare
        // a node drag. Otherwise let InteractiveViewer handle pan/zoom.
        final hit = HitTester().test(canvasPoint, ctrl.diagram,
            selectedNodeId: ctrl.selectedNodeId);

        if (hit.isConnectorHandle && hit.connectorSide != null) {
          // Connector handle hit — go straight to connection mode.
          _isDiagramDrag = true;
          ctrl.startConnectionFromHandle(hit.connectorSide!);
        } else if (hit.hitNode) {
          // Node body hit — prepare a node drag.
          _isDiagramDrag = true;
          ctrl.onDragStart(canvasPoint);
        } else {
          _isDiagramDrag = false;
          ctrl.onTapDown(canvasPoint);
        }
      },
      onPointerMove: (event) {
        // Only update debug dot on pointer down, not during drag.
        if (_isDiagramDrag && event.pointer == _activePointer) {
          widget.controller.onDragUpdate(event.localPosition);
        }
      },
      onPointerUp: (event) {
        if (_isDiagramDrag && event.pointer == _activePointer) {
          final ctrl = widget.controller;
          if (ctrl.isConnecting || ctrl.isDragging) {
            ctrl.onDragEnd(
              ctrl.isConnecting
                  ? (ctrl.connectionEnd ?? Offset.zero)
                  : (ctrl.selectedNodeId != null
                      ? ctrl.diagram.nodes[ctrl.selectedNodeId]!.center
                      : Offset.zero),
            );
          } else {
            // No drag or connection started — treat as a tap to select.
            ctrl.onTapDown(event.localPosition);
          }
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
        final dragging = widget.controller.hasPendingDrag ||
            widget.controller.isConnecting;
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
