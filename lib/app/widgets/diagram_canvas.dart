import 'package:flutter/material.dart';
import '../../diagram/edit/editor_controller.dart';
import '../../diagram/edit/hit_test.dart';
import '../../diagram/render/diagram_painter.dart';

/// The interactive diagram canvas with pan/zoom support.
class DiagramCanvas extends StatefulWidget {
  final EditorController controller;
  final TransformationController transformationController;

  const DiagramCanvas({
    super.key,
    required this.controller,
    required this.transformationController,
  });

  @override
  State<DiagramCanvas> createState() => _DiagramCanvasState();
}

class _DiagramCanvasState extends State<DiagramCanvas>
    with SingleTickerProviderStateMixin {
  bool _isDiagramDrag = false;
  int? _activePointer;

  late final AnimationController _blobAnimController;
  late final Animation<double> _blobAnimation;
  String? _animatingNodeId;

  @override
  void initState() {
    super.initState();
    _blobAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _blobAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.15), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.15, end: 0.92), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 0.92, end: 1.0), weight: 30),
    ]).animate(CurvedAnimation(
      parent: _blobAnimController,
      curve: Curves.easeOut,
    ));
    _blobAnimController.addListener(_onBlobTick);
    widget.controller.addListener(_checkNewNode);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_checkNewNode);
    _blobAnimController.removeListener(_onBlobTick);
    _blobAnimController.dispose();
    super.dispose();
  }

  void _onBlobTick() {
    widget.controller.updateBlobScale(_blobAnimation.value);
  }

  void _checkNewNode() {
    final newId = widget.controller.lastAddedNodeId;
    if (newId != null && newId != _animatingNodeId) {
      _animatingNodeId = newId;
      widget.controller.blobNodeId = newId;
      widget.controller.blobScale = 0.0;
      _blobAnimController.forward(from: 0);
    }
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
            selectedNodeId: ctrl.selectedNodeId);

        if (hit.isConnectorHandle && hit.connectorSide != null) {
          _isDiagramDrag = true;
          ctrl.startConnectionFromHandle(hit.connectorSide!);
        } else if (hit.hitNode) {
          _isDiagramDrag = true;
          ctrl.onDragStart(canvasPoint);
        } else {
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
          if (ctrl.isConnecting || ctrl.isDragging) {
            ctrl.onDragEnd(
              ctrl.isConnecting
                  ? (ctrl.connectionEnd ?? Offset.zero)
                  : (ctrl.selectedNodeId != null
                      ? ctrl.diagram.nodes[ctrl.selectedNodeId]!.center
                      : Offset.zero),
            );
          } else {
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
          transformationController: widget.transformationController,
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
