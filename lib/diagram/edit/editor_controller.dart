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
  Offset? connectionStart;
  Offset? connectionEnd;
  String? connectionSourceId;

  /// Node drag state.
  bool isDragging = false;
  Offset? _dragStartNodeCenter;

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

  /// Called when the user taps on the canvas.
  void onTapDown(Offset canvasPoint) {
    if (activeTool != EditorTool.select) {
      _placeNode(canvasPoint);
      return;
    }

    final hit = _hitTester.test(canvasPoint, diagram, selectedNodeId: selectedNodeId);
    if (hit.isConnectorHandle) {
      _startConnection(canvasPoint);
      return;
    }

    if (hit.hitNode) {
      selectedNodeId = hit.nodeId;
      selectedEdgeId = null;
    } else if (hit.hitEdge) {
      selectedEdgeId = hit.edgeId;
      selectedNodeId = null;
    } else {
      clearSelection();
    }
    notifyListeners();
  }

  /// Called when a long-press occurs on empty space.
  /// Returns true if no element was hit (for showing context menu).
  bool onLongPress(Offset canvasPoint) {
    final hit = _hitTester.test(canvasPoint, diagram);
    return hit.hitNothing;
  }

  /// Start dragging a node.
  void onDragStart(Offset canvasPoint) {
    if (isConnecting) return;

    final hit = _hitTester.test(canvasPoint, diagram, selectedNodeId: selectedNodeId);

    if (hit.isConnectorHandle) {
      _startConnection(canvasPoint);
      return;
    }

    if (hit.hitNode) {
      selectedNodeId = hit.nodeId;
      selectedEdgeId = null;
      isDragging = true;
      _dragStartNodeCenter = diagram.nodes[hit.nodeId!]!.center;
      notifyListeners();
    }
  }

  void onDragUpdate(Offset canvasPoint) {
    if (isConnecting) {
      connectionEnd = canvasPoint;
      notifyListeners();
      return;
    }

    if (isDragging && selectedNodeId != null) {
      final node = diagram.nodes[selectedNodeId!]!;
      final oldCenter = node.center;
      final delta = canvasPoint - oldCenter;
      node.rect = node.rect.shift(delta);
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
      final totalDelta = node.center - _dragStartNodeCenter!;
      // Undo the live drag, then apply via command for undo support.
      node.rect = node.rect.shift(-totalDelta);
      if (totalDelta != Offset.zero) {
        _exec(MoveNodeCommand(selectedNodeId!, totalDelta));
      }
    }
    isDragging = false;
    _dragStartNodeCenter = null;
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

  void _startConnection(Offset point) {
    isConnecting = true;
    connectionSourceId = selectedNodeId;
    final node = diagram.nodes[selectedNodeId!]!;
    connectionStart = Offset(node.rect.right + 16, node.rect.center.dy);
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
    connectionStart = null;
    connectionEnd = null;
    connectionSourceId = null;
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
