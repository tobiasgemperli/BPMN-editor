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
    with TickerProviderStateMixin {
  bool _isDiagramDrag = false;
  int? _activePointer;

  // Bounce animation (add / select / drop).
  late final AnimationController _blobAnimController;
  late final Animation<double> _blobAnimation;
  int _lastBounceCounter = 0;

  // Lift animation (grow on touch-down, shrink on drop).
  late final AnimationController _liftGrowController;
  late final Animation<double> _liftGrowAnimation;
  late final AnimationController _liftShrinkController;
  late final Animation<double> _liftShrinkAnimation;

  @override
  void initState() {
    super.initState();

    // Bounce.
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

    // Lift grow (touch down → scale up).
    _liftGrowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _liftGrowAnimation = Tween(begin: 1.0, end: 1.12).animate(
      CurvedAnimation(parent: _liftGrowController, curve: Curves.easeOut),
    );
    _liftGrowController.addListener(_onLiftTick);

    // Lift shrink (drop → scale back to 1.0).
    _liftShrinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _liftShrinkAnimation = Tween(begin: 1.12, end: 1.0).animate(
      CurvedAnimation(parent: _liftShrinkController, curve: Curves.easeInOut),
    );
    _liftShrinkController.addListener(_onLiftShrinkTick);

    widget.controller.addListener(_checkNewNode);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_checkNewNode);
    _blobAnimController.removeListener(_onBlobTick);
    _blobAnimController.dispose();
    _liftGrowController.removeListener(_onLiftTick);
    _liftGrowController.dispose();
    _liftShrinkController.removeListener(_onLiftShrinkTick);
    _liftShrinkController.dispose();
    super.dispose();
  }

  void _onBlobTick() {
    widget.controller.updateBlobScale(_blobAnimation.value);
  }

  void _onLiftTick() {
    widget.controller.updateLiftScale(_liftGrowAnimation.value);
  }

  void _onLiftShrinkTick() {
    widget.controller.updateLiftScale(_liftShrinkAnimation.value);
  }

  void _checkNewNode() {
    final counter = widget.controller.bounceCounter;
    if (counter != _lastBounceCounter) {
      _lastBounceCounter = counter;
      widget.controller.blobNodeId = widget.controller.bounceNodeId;
      _blobAnimController.forward(from: 0);
    }
  }

  void _startLift(String nodeId) {
    if (_liftShrinkController.isAnimating) _liftShrinkController.stop();
    widget.controller.startLift(nodeId);
    _liftGrowController.forward(from: 0);
  }

  void _endLift() {
    _liftGrowController.stop();
    _liftShrinkController.forward(from: 0);
    // endLift clears liftNodeId after shrink completes.
    _liftShrinkController.addStatusListener(_onShrinkDone);
  }

  void _onShrinkDone(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      widget.controller.endLift();
      _liftShrinkController.removeStatusListener(_onShrinkDone);
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
          // Connector handle — no grow animation.
          _isDiagramDrag = true;
          ctrl.startConnectionFromHandle(hit.connectorSide!);
        } else if (hit.hitNode) {
          _isDiagramDrag = true;
          // Grow the touched node.
          if (hit.nodeId != null) {
            _startLift(hit.nodeId!);
          }
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
          // End lift animation (shrink back).
          if (ctrl.liftNodeId != null) {
            _endLift();
          }
          if (ctrl.isConnecting || ctrl.isDragging) {
            ctrl.onDragEnd(
              ctrl.isConnecting
                  ? (ctrl.connectionEnd ?? Offset.zero)
                  : (ctrl.selectedNodeId != null
                      ? ctrl.diagram.nodes[ctrl.selectedNodeId]!.center
                      : Offset.zero),
            );
          } else {
            // No drag or connection started — clean up pending state
            // and treat as a tap to select.
            ctrl.cancelPendingDrag();
            ctrl.onTapDown(event.localPosition);
          }
        }
        _isDiagramDrag = false;
        _activePointer = null;
      },
      onPointerCancel: (event) {
        if (_isDiagramDrag && event.pointer == _activePointer) {
          if (widget.controller.liftNodeId != null) {
            _endLift();
          }
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
