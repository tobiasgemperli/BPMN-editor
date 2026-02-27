import 'package:flutter/foundation.dart';
import 'dart:ui';
import '../model/diagram_model.dart';
import '../../common/id_generator.dart';
import 'command_stack.dart';
import 'commands.dart';
import 'hit_test.dart';

/// The tool currently active in the editor.
enum EditorTool { select, addStart, addEnd, addTask, addGateway }

/// Central controller for the diagram editor.
///
/// Notifies listeners whenever the diagram or selection state changes.
class EditorController extends ChangeNotifier {
  DiagramModel diagram;
  final CommandStack _commandStack = CommandStack();
  final HitTester _hitTester = HitTester();
  final IdGenerator _idGen = IdGenerator();

  /// Currently selected node/edge.
  String? selectedNodeId;
  String? selectedEdgeId;

  /// Active tool.
  EditorTool activeTool = EditorTool.select;

  /// Connection drag state.
  bool isConnecting = false;
  Offset? connectionEnd;
  String? connectionSourceId;
  ConnectorSide? connectionSourceSide;

  /// Connection start point — computed from the node border on the active side.
  Offset? get connectionStart {
    if (connectionSourceId == null || connectionSourceSide == null) return null;
    final node = diagram.nodes[connectionSourceId!];
    if (node == null) return null;
    return _nodeBorderPoint(node, connectionSourceSide!);
  }

  static Offset _nodeBorderPoint(NodeModel node, ConnectorSide side) {
    switch (side) {
      case ConnectorSide.top:
        return Offset(node.rect.center.dx, node.rect.top);
      case ConnectorSide.right:
        return Offset(node.rect.right, node.rect.center.dy);
      case ConnectorSide.bottom:
        return Offset(node.rect.center.dx, node.rect.bottom);
      case ConnectorSide.left:
        return Offset(node.rect.left, node.rect.center.dy);
    }
  }

  /// Node drag state.
  bool isDragging = false;
  String? _pendingDragNodeId;
  Offset? _dragStartNodeCenter;

  /// True when a drag is pending or active — used to disable canvas pan.
  bool get hasPendingDrag => _pendingDragNodeId != null || isDragging;

  /// Snap guide lines visible during drag.
  double? snapGuideX; // vertical line at this x
  double? snapGuideY; // horizontal line at this y

  /// Debug: the closest target point (node center or connector handle).
  Offset? debugClosestPoint;

  EditorController({DiagramModel? diagram})
      : diagram = diagram ?? DiagramModel() {
    _idGen.seedFrom(this.diagram.nodes.keys.followedBy(this.diagram.edges.keys));
  }

  bool get canUndo => _commandStack.canUndo;
  bool get canRedo => _commandStack.canRedo;

  void _exec(Command cmd) {
    _commandStack.execute(cmd, diagram);
    notifyListeners();
  }

  void undo() {
    _commandStack.undo(diagram);
    notifyListeners();
  }

  void redo() {
    _commandStack.redo(diagram);
    notifyListeners();
  }

  void setTool(EditorTool tool) {
    activeTool = tool;
    notifyListeners();
  }

  void clearSelection() {
    selectedNodeId = null;
    selectedEdgeId = null;
    notifyListeners();
  }

  /// Update debug highlight: find the closest candidate point to the pointer.
  /// Considers all node centers and connector handles of the selected node.
  void updateDebugClosest(Offset point) {
    double bestDist = double.infinity;
    Offset? bestPoint;

    // Check all node centers.
    for (final node in diagram.nodes.values) {
      final d = (point - node.center).distance;
      if (d < bestDist) {
        bestDist = d;
        bestPoint = node.center;
      }
    }

    // Check connector handles of the selected node.
    if (selectedNodeId != null) {
      final selNode = diagram.nodes[selectedNodeId];
      if (selNode != null) {
        for (final side in ConnectorSide.values) {
          final center = connectorHandleCenter(selNode, side);
          final d = (point - center).distance;
          if (d < bestDist) {
            bestDist = d;
            bestPoint = center;
          }
        }
      }
    }

    debugClosestPoint = bestPoint;
    notifyListeners();
  }

  /// Called when the user taps on the canvas.
  void onTapDown(Offset canvasPoint) {
    if (activeTool != EditorTool.select) {
      _placeNode(canvasPoint);
      return;
    }

    // For taps, find the closest node center among all hit nodes.
    // This avoids accidentally hitting a connector handle when you meant
    // to tap a nearby node.
    final closestNode = _closestHitNode(canvasPoint);
    if (closestNode != null) {
      selectedNodeId = closestNode;
      selectedEdgeId = null;
    } else {
      // No node hit — check edges.
      final hit = _hitTester.test(canvasPoint, diagram);
      if (hit.hitEdge) {
        selectedEdgeId = hit.edgeId;
        selectedNodeId = null;
      } else {
        clearSelection();
      }
    }
    notifyListeners();
  }

  /// Start a connection directly from a known connector handle side.
  /// Called when the hit tester already identified a connector handle hit.
  void startConnectionFromHandle(ConnectorSide side) {
    if (selectedNodeId == null) return;
    final node = diagram.nodes[selectedNodeId!];
    if (node == null) return;
    final handleCenter = connectorHandleCenter(node, side);
    _startConnection(handleCenter, side: side);
  }

  /// Prepare for a potential drag. Actual dragging starts on first move.
  /// Uses closest-point logic: if a connector handle is closer than the
  /// node center, start a connection; otherwise prepare a node drag.
  void onDragStart(Offset canvasPoint) {
    if (isConnecting) return;

    // Prepare node drag. The canvas handles connector handles separately.
    final nodeHit = _closestHitNode(canvasPoint, forDrag: true);
    if (nodeHit != null) {
      _pendingDragNodeId = nodeHit;
      _dragStartNodeCenter = diagram.nodes[nodeHit]!.center;
      notifyListeners(); // Disable InteractiveViewer pan immediately.
      return;
    }
  }

  void onDragUpdate(Offset canvasPoint) {
    if (isConnecting) {
      connectionEnd = canvasPoint;
      notifyListeners();
      return;
    }

    // Promote pending drag to actual drag on first move.
    if (!isDragging && _pendingDragNodeId != null) {
      isDragging = true;
      selectedNodeId = _pendingDragNodeId;
      selectedEdgeId = null;
      notifyListeners();
    }

    if (isDragging && selectedNodeId != null) {
      final node = diagram.nodes[selectedNodeId!]!;
      final delta = canvasPoint - node.center;
      node.rect = node.rect.shift(delta);
      _updateSnapGuides(node);
      notifyListeners();
    }
  }

  void onDragEnd(Offset canvasPoint) {
    if (isConnecting) {
      _finishConnection(canvasPoint);
      return;
    }

    if (isDragging && selectedNodeId != null && _dragStartNodeCenter != null) {
      final node = diagram.nodes[selectedNodeId!]!;

      // Snap to guide lines if visible.
      double snapDx = 0;
      double snapDy = 0;
      if (snapGuideX != null) {
        snapDx = snapGuideX! - node.center.dx;
      }
      if (snapGuideY != null) {
        snapDy = snapGuideY! - node.center.dy;
      }
      if (snapDx != 0 || snapDy != 0) {
        node.rect = node.rect.shift(Offset(snapDx, snapDy));
      }

      final totalDelta = node.center - _dragStartNodeCenter!;
      // Undo the live drag, then apply via command for undo support.
      node.rect = node.rect.shift(-totalDelta);
      if (totalDelta != Offset.zero) {
        _exec(MoveNodeCommand(selectedNodeId!, totalDelta));
      }
    }
    isDragging = false;
    _pendingDragNodeId = null;
    _dragStartNodeCenter = null;
    snapGuideX = null;
    snapGuideY = null;
  }

  /// Among all nodes whose hit area contains [point], return the one
  /// whose center is closest. Returns null if no node is hit.
  String? _closestHitNode(Offset point, {bool forDrag = false}) {
    String? bestId;
    double bestDist = double.infinity;
    for (final node in diagram.nodes.values) {
      final hit = _hitTester.test(point, DiagramModel(nodes: {node.id: node}),
          forDrag: forDrag);
      if (hit.hitNode) {
        final d = (point - node.center).distance;
        if (d < bestDist) {
          bestDist = d;
          bestId = node.id;
        }
      }
    }
    return bestId;
  }

  /// Snap guide threshold in logical pixels.
  static const double _snapGuideThreshold = 20.0;

  void _updateSnapGuides(NodeModel dragged) {
    double? closestDx;
    double? bestX;
    double? closestDy;
    double? bestY;

    for (final other in diagram.nodes.values) {
      if (other.id == dragged.id) continue;

      final dx = (dragged.center.dx - other.center.dx).abs();
      if (dx < _snapGuideThreshold && (closestDx == null || dx < closestDx)) {
        closestDx = dx;
        bestX = other.center.dx;
      }

      final dy = (dragged.center.dy - other.center.dy).abs();
      if (dy < _snapGuideThreshold && (closestDy == null || dy < closestDy)) {
        closestDy = dy;
        bestY = other.center.dy;
      }
    }

    snapGuideX = bestX;
    snapGuideY = bestY;
  }

  void _placeNode(Offset position) {
    NodeType type;
    String prefix;
    switch (activeTool) {
      case EditorTool.addStart:
        type = NodeType.startEvent;
        prefix = 'start';
        break;
      case EditorTool.addEnd:
        type = NodeType.endEvent;
        prefix = 'end';
        break;
      case EditorTool.addTask:
        type = NodeType.task;
        prefix = 'task';
        break;
      case EditorTool.addGateway:
        type = NodeType.exclusiveGateway;
        prefix = 'gateway';
        break;
      default:
        return;
    }

    final id = _idGen.next(prefix);
    final node = NodeModel(
      id: id,
      type: type,
      rect: NodeModel.defaultRect(type, position),
    );
    _exec(AddNodeCommand(node));
    selectedNodeId = id;
    activeTool = EditorTool.select;
  }

  void addNodeAtPosition(NodeType type, Offset position) {
    final prefix = switch (type) {
      NodeType.startEvent => 'start',
      NodeType.endEvent => 'end',
      NodeType.task => 'task',
      NodeType.exclusiveGateway => 'gateway',
    };
    final id = _idGen.next(prefix);
    final node = NodeModel(
      id: id,
      type: type,
      rect: NodeModel.defaultRect(type, position),
    );
    _exec(AddNodeCommand(node));
    selectedNodeId = id;
    activeTool = EditorTool.select;
  }

  void deleteSelected() {
    if (selectedNodeId != null) {
      _exec(DeleteNodeCommand(selectedNodeId!));
      selectedNodeId = null;
    } else if (selectedEdgeId != null) {
      _exec(DeleteEdgeCommand(selectedEdgeId!));
      selectedEdgeId = null;
    }
    notifyListeners();
  }

  void renameNode(String nodeId, String newName) {
    _exec(RenameNodeCommand(nodeId, newName));
  }

  void _startConnection(Offset point, {ConnectorSide? side}) {
    isConnecting = true;
    connectionSourceId = selectedNodeId;
    connectionSourceSide = side;
    connectionEnd = point;
    notifyListeners();
  }

  void _finishConnection(Offset point) {
    if (connectionSourceId == null) {
      _cancelConnection();
      return;
    }

    final hit = _hitTester.test(point, diagram);
    if (hit.hitNode && hit.nodeId != connectionSourceId) {
      final edgeId = _idGen.next('flow');
      final edge = EdgeModel(
        id: edgeId,
        sourceId: connectionSourceId!,
        targetId: hit.nodeId!,
      );
      _exec(AddEdgeCommand(edge));
    }

    _cancelConnection();
  }

  void _cancelConnection() {
    isConnecting = false;
    connectionEnd = null;
    connectionSourceId = null;
    connectionSourceSide = null;
    notifyListeners();
  }

  /// Load a new diagram (e.g. from import).
  void loadDiagram(DiagramModel newDiagram) {
    diagram = newDiagram;
    _commandStack.clear();
    selectedNodeId = null;
    selectedEdgeId = null;
    _idGen.seedFrom(diagram.nodes.keys.followedBy(diagram.edges.keys));
    notifyListeners();
  }
}
