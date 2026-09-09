import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../diagram/edit/editor_controller.dart';
import '../../diagram/edit/hit_test.dart';
import '../../diagram/render/diagram_painter.dart';
import 'properties_sheet.dart';

/// The interactive diagram canvas with pan/zoom support.
class DiagramCanvas extends StatefulWidget {
  final EditorController controller;
  final TransformationController transformationController;
  final bool readOnly;
  final Map<String, ui.Image>? screenImages;

  /// Called in UI mode when a screen is tapped, with the node id — used to
  /// open that screen's detail.
  final void Function(String nodeId)? onScreenTap;

  const DiagramCanvas({
    super.key,
    required this.controller,
    required this.transformationController,
    this.readOnly = false,
    this.screenImages,
    this.onScreenTap,
  });

  @override
  State<DiagramCanvas> createState() => _DiagramCanvasState();
}

class _DiagramCanvasState extends State<DiagramCanvas>
    with TickerProviderStateMixin {
  /// Offset added so that diagram coordinates (which can be negative)
  /// map to positive widget-local coordinates within the SizedBox.
  static const _canvasOffset = Offset(2000, 2000);

  bool _isDiagramDrag = false;
  int? _activePointer;

  /// UI-mode: pointer-down location for detecting a tap (vs a pan) that opens
  /// a screen's detail.
  Offset? _uiTapStart;

  // Long-press detection.
  Timer? _longPressTimer;
  Offset? _longPressStart;
  String? _longPressNodeId;
  static const _longPressDuration = Duration(milliseconds: 500);
  static const _longPressMoveThreshold = 10.0;

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
      duration: const Duration(milliseconds: 200),
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
    _cancelLongPress();
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

  void _cancelLongPress() {
    _longPressTimer?.cancel();
    _longPressTimer = null;
    _longPressNodeId = null;
    _longPressStart = null;
  }

  /// UI mode: open the detail of the screen at [tapPoint], if any.
  void _openUiScreen(Offset tapPoint) {
    final onTap = widget.onScreenTap;
    if (onTap == null) return;
    final rects = DiagramPainter.uiDisplayRects(widget.controller.diagram);
    for (final entry in rects.entries) {
      if (entry.value.contains(tapPoint)) {
        onTap(entry.key);
        return;
      }
    }
  }

  void _onLongPress() {
    final nodeId = _longPressNodeId;
    _cancelLongPress();
    if (nodeId == null) return;

    final node = widget.controller.diagram.nodes[nodeId];
    if (node == null) return;

    // Cancel any drag in progress.
    widget.controller.cancelPendingDrag();
    if (widget.controller.liftNodeId != null) {
      _endLift();
    }
    _isDiagramDrag = false;

    // Open the node editor.
    showNodeEditor(context, node, widget.controller);
  }

  Widget _buildCanvas() {
    const canvasSize = Size(8000, 8000);
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (event) {
        // UI mode is view-only: no moving symbols or editing lines — only a
        // tap opens a screen's detail. Pan/zoom is the InteractiveViewer's.
        if (widget.controller.viewMode == ViewMode.ui) {
          _activePointer = event.pointer;
          _uiTapStart = event.localPosition - _canvasOffset;
          return;
        }
        if (widget.readOnly) return;
        final canvasPoint = event.localPosition - _canvasOffset;
        _activePointer = event.pointer;
        _cancelLongPress();

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
          // Start long-press timer for node editing.
          if (hit.nodeId != null) {
            _longPressNodeId = hit.nodeId;
            _longPressStart = canvasPoint;
            _longPressTimer = Timer(_longPressDuration, _onLongPress);
            _startLift(hit.nodeId!);
          }
          ctrl.onDragStart(canvasPoint);
        } else {
          _isDiagramDrag = false;
          ctrl.onTapDown(canvasPoint);
        }
      },
      onPointerMove: (event) {
        if (widget.controller.viewMode == ViewMode.ui) {
          // Movement means a pan/zoom, not a tap — cancel the pending open.
          if (_uiTapStart != null &&
              ((event.localPosition - _canvasOffset) - _uiTapStart!).distance >
                  _longPressMoveThreshold) {
            _uiTapStart = null;
          }
          return;
        }
        if (_isDiagramDrag && event.pointer == _activePointer) {
          final canvasPoint = event.localPosition - _canvasOffset;
          // Cancel long-press if finger moved too far.
          if (_longPressStart != null) {
            final d = (canvasPoint - _longPressStart!).distance;
            if (d > _longPressMoveThreshold) {
              _cancelLongPress();
            }
          }
          widget.controller.onDragUpdate(canvasPoint);
        }
      },
      onPointerUp: (event) {
        _cancelLongPress();
        if (widget.controller.viewMode == ViewMode.ui) {
          if (event.pointer == _activePointer && _uiTapStart != null) {
            _openUiScreen(event.localPosition - _canvasOffset);
          }
          _uiTapStart = null;
          _activePointer = null;
          return;
        }
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
            // No drag or connection started — treat as a tap to select.
            ctrl.cancelPendingDrag();
            ctrl.onTapDown(event.localPosition - _canvasOffset);
          }
        }
        _isDiagramDrag = false;
        _activePointer = null;
      },
      onPointerCancel: (event) {
        _cancelLongPress();
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
            painter: DiagramPainter(widget.controller,
                screenImages: widget.screenImages),
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
        // Disable pan/zoom only during an ACTIVE drag or connection — not on a
        // mere touch on a symbol — so pinch-zoom works even with a finger on a
        // node.
        final dragging = widget.controller.isDragging ||
            widget.controller.isConnecting;
        return InteractiveViewer(
          transformationController: widget.transformationController,
          constrained: false,
          boundaryMargin: const EdgeInsets.all(2000),
          minScale: widget.readOnly ? 0.7 : 0.15,
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
