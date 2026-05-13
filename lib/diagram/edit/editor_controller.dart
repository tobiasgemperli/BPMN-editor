import 'package:flutter/foundation.dart';
import 'dart:ui';
import '../model/diagram_model.dart';
import '../../common/id_generator.dart';
import '../routing/orthogonal_router.dart';
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
  final OrthogonalRouter _router = OrthogonalRouter();

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

  /// The node the connection line would snap to (highlighted during draw).
  String? connectionTargetId;

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

  /// Clear pending drag state (e.g. when a tap completes without dragging).
  void cancelPendingDrag() {
    _pendingDragNodeId = null;
    _dragStartNodeCenter = null;
    notifyListeners();
  }

  /// Snap guide lines visible during drag.
  double? snapGuideX; // vertical line at this x
  double? snapGuideY; // horizontal line at this y

  /// Debug: the closest target point (node center or connector handle).
  Offset? debugClosestPoint;

  /// ID of the node to bounce-animate, and a counter to retrigger.
  String? bounceNodeId;
  int _bounceCounter = 0;
  int get bounceCounter => _bounceCounter;

  /// Blob animation state — the painter reads these to scale the node.
  String? blobNodeId;
  double blobScale = 1.0;

  /// Lift (touch-down grow) state — separate from bounce.
  String? liftNodeId;
  double liftScale = 1.0;

  /// Trigger a bounce animation on a node.
  void _triggerBounce(String nodeId) {
    bounceNodeId = nodeId;
    _bounceCounter++;
  }

  /// Update the blob scale and repaint. Called by the animation controller.
  void updateBlobScale(double scale) {
    blobScale = scale;
    notifyListeners();
  }

  /// Update the lift scale and repaint. Called by the lift animation.
  void updateLiftScale(double scale) {
    liftScale = scale;
    notifyListeners();
  }

  /// Start lift animation on a node (touch down on node body, not connector).
  void startLift(String nodeId) {
    liftNodeId = nodeId;
    // liftScale will be animated by the canvas.
  }

  /// End lift (drop).
  void endLift() {
    liftNodeId = null;
    liftScale = 1.0;
  }

  EditorController({DiagramModel? diagram})
      : diagram = diagram ?? DiagramModel() {
    _idGen.seedFrom(this.diagram.nodes.keys.followedBy(this.diagram.edges.keys));
  }

  bool get canUndo => _commandStack.canUndo;
  bool get canRedo => _commandStack.canRedo;

  /// Whether the diagram already contains a start event.
  bool get hasStartEvent =>
      diagram.nodes.values.any((n) => n.type == NodeType.startEvent);

  /// Whether the given node can still have outgoing connections drawn.
  bool canDrawFrom(String nodeId) {
    final node = diagram.nodes[nodeId];
    if (node == null) return false;
    // End events never have outputs.
    if (node.type == NodeType.endEvent) return false;
    // Start and Task: max 1 outgoing.
    if (node.type == NodeType.startEvent || node.type == NodeType.task) {
      return diagram.outgoingEdges(nodeId).isEmpty;
    }
    // Gateway: unlimited.
    return true;
  }

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
      _triggerBounce(closestNode);
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
      // Find valid snap target under the finger.
      final hit = _hitTester.test(canvasPoint, diagram);
      if (hit.hitNode &&
          hit.nodeId != connectionSourceId &&
          canConnect(connectionSourceId!, hit.nodeId!)) {
        connectionTargetId = hit.nodeId;
      } else {
        connectionTargetId = null;
      }
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
      _assignPortsAndRoute();
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
      final dropCenter = node.center;
      // Undo the live drag, then apply via command for undo support.
      node.rect = node.rect.shift(-totalDelta);

      if (totalDelta != Offset.zero) {
        // Check if dropped on an edge (only Task and Gateway can split).
        final splitEdge = _findEdgeAtPoint(dropCenter, selectedNodeId!);
        if (splitEdge != null &&
            (node.type == NodeType.task ||
                node.type == NodeType.exclusiveGateway) &&
            _canSplitEdge(splitEdge, selectedNodeId!)) {
          _splitEdgeWithNode(selectedNodeId!, totalDelta, splitEdge);
        } else {
          _exec(MoveNodeCommand(selectedNodeId!, totalDelta));
        }
        _assignPortsAndRoute();
      }
      _triggerBounce(selectedNodeId!);
    }
    isDragging = false;
    _pendingDragNodeId = null;
    _dragStartNodeCenter = null;
    snapGuideX = null;
    snapGuideY = null;
  }

  /// Among all nodes whose hit area contains [point], return the one
  /// whose center is closest. Returns null if no node is hit.
  /// Find an edge under [point], excluding edges connected to [excludeNodeId].
  EdgeModel? _findEdgeAtPoint(Offset point, String excludeNodeId) {
    // Collect edge IDs connected to the excluded node.
    final excludeEdgeIds = diagram.edges.values
        .where((e) => e.sourceId == excludeNodeId || e.targetId == excludeNodeId)
        .map((e) => e.id)
        .toSet();
    final hit = _hitTester.testEdgesOnly(point, diagram,
        excludeEdgeIds: excludeEdgeIds);
    if (hit.hitEdge) {
      return diagram.edges[hit.edgeId];
    }
    return null;
  }

  /// Check if we can split this edge with the given node.
  bool _canSplitEdge(EdgeModel edge, String nodeId) {
    final node = diagram.nodes[nodeId];
    if (node == null) return false;
    // Node must accept at least 1 input and 1 output.
    final outgoing = diagram.outgoingEdges(nodeId);
    // Task: max 1 outgoing.
    if (node.type == NodeType.task && outgoing.isNotEmpty) return false;
    // Check that incoming is allowed (tasks/gateways accept multiple).
    return true;
  }

  /// Split an edge by inserting a node into it.
  /// Moves the node, deletes the old edge, creates two new edges.
  void _splitEdgeWithNode(
      String nodeId, Offset delta, EdgeModel edge) {
    final edge1Id = _idGen.next('flow');
    final edge2Id = _idGen.next('flow');

    final commands = <Command>[
      MoveNodeCommand(nodeId, delta),
      DeleteEdgeCommand(edge.id),
      AddEdgeCommand(EdgeModel(
        id: edge1Id,
        sourceId: edge.sourceId,
        targetId: nodeId,
      )),
      AddEdgeCommand(EdgeModel(
        id: edge2Id,
        sourceId: nodeId,
        targetId: edge.targetId,
      )),
    ];

    _exec(CompositeCommand(commands, description: 'Split edge with node'));

    // Route the two new edges.
    _assignPortsAndRoute();
  }

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
    _triggerBounce(id);
    activeTool = EditorTool.select;
  }

  /// Add a node at the visible [screenCenter]. If a node is selected and can
  /// connect, place the new node below it and auto-connect.
  void addNodeNear(NodeType type, Offset screenCenter) {
    // If a node is selected and can have outgoing edges, place below & connect.
    if (selectedNodeId != null) {
      final source = diagram.nodes[selectedNodeId!];
      if (source != null && _canAddOutgoing(source, type)) {
        _addConnectedNode(type, source);
        return;
      }
    }

    final position = _findFreePosition(type, screenCenter, 170.0, '');
    addNodeAtPosition(type, position);
  }

  /// Whether [source] can have an outgoing edge to a new node of [targetType].
  bool _canAddOutgoing(NodeModel source, NodeType targetType) {
    if (source.type == NodeType.endEvent) return false;
    if (targetType == NodeType.startEvent) return false;
    final outgoing = diagram.outgoingEdges(source.id);
    if (source.type == NodeType.startEvent && outgoing.isNotEmpty) return false;
    if (source.type == NodeType.task && outgoing.isNotEmpty) return false;
    // Gateways can have multiple outgoing.
    return true;
  }

  /// Add a new node below [source], connect them, and select the new node.
  void _addConnectedNode(NodeType type, NodeModel source) {
    const spacing = 130.0;
    const lateralOffset = 170.0;

    final belowCenter = Offset(source.center.dx, source.center.dy + spacing);
    final position = _findFreePosition(type, belowCenter, lateralOffset, source.id);

    final prefix = switch (type) {
      NodeType.startEvent => 'start',
      NodeType.endEvent => 'end',
      NodeType.task => 'task',
      NodeType.exclusiveGateway => 'gateway',
    };
    final nodeId = _idGen.next(prefix);
    final node = NodeModel(
      id: nodeId,
      type: type,
      rect: NodeModel.defaultRect(type, position),
    );
    _exec(AddNodeCommand(node));

    // Connect source → new node.
    final edgeId = _idGen.next('flow');
    final edge = EdgeModel(
      id: edgeId,
      sourceId: source.id,
      targetId: nodeId,
    );
    _exec(AddEdgeCommand(edge));
    _assignPortsAndRoute();

    selectedNodeId = nodeId;
    _triggerBounce(nodeId);
    activeTool = EditorTool.select;
  }

  /// Find a free position starting from [preferred]. If occupied, try right
  /// and left of the blocking node, expanding outward.
  Offset _findFreePosition(NodeType type, Offset preferred, double lateral, String excludeId) {
    const maxAttempts = 10;
    var candidate = preferred;
    for (var i = 0; i < maxAttempts; i++) {
      final rect = NodeModel.defaultRect(type, candidate);
      final blocker = _findBlocker(rect, excludeId);
      if (blocker == null) return candidate;

      // Try right of the blocker, then left.
      final rightPos = Offset(blocker.center.dx + lateral, candidate.dy);
      final rightRect = NodeModel.defaultRect(type, rightPos);
      if (_findBlocker(rightRect, excludeId) == null) return rightPos;

      final leftPos = Offset(blocker.center.dx - lateral, candidate.dy);
      final leftRect = NodeModel.defaultRect(type, leftPos);
      if (_findBlocker(leftRect, excludeId) == null) return leftPos;

      // Both sides blocked — shift right and try again next iteration.
      candidate = Offset(rightPos.dx + lateral, candidate.dy);
    }
    return candidate;
  }

  /// Returns the first node whose rect overlaps [rect], or null.
  NodeModel? _findBlocker(Rect rect, String excludeId) {
    const margin = 20.0;
    final expanded = rect.inflate(margin);
    for (final node in diagram.nodes.values) {
      if (node.id == excludeId) continue;
      if (expanded.overlaps(node.rect)) return node;
    }
    return null;
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

  void updateTaskContent(String nodeId, TaskContent? content) {
    _exec(UpdateTaskContentCommand(nodeId, content));
  }

  void _startConnection(Offset point, {ConnectorSide? side}) {
    isConnecting = true;
    connectionSourceId = selectedNodeId;
    connectionSourceSide = side;
    connectionEnd = point;
    notifyListeners();
  }

  /// Check whether a connection from [sourceId] to [targetId] is allowed.
  bool canConnect(String sourceId, String targetId) {
    final source = diagram.nodes[sourceId];
    final target = diagram.nodes[targetId];
    if (source == null || target == null) return false;

    // End events cannot have outputs.
    if (source.type == NodeType.endEvent) return false;
    // Start events cannot have inputs.
    if (target.type == NodeType.startEvent) return false;

    final outgoing = diagram.outgoingEdges(sourceId);
    final incoming = diagram.incomingEdges(targetId);

    // Start: max 1 output.
    if (source.type == NodeType.startEvent && outgoing.isNotEmpty) return false;
    // Task (Step): max 1 output.
    if (source.type == NodeType.task && outgoing.isNotEmpty) return false;
    // End: max 1 input.
    if (target.type == NodeType.endEvent && incoming.isNotEmpty) return false;

    return true;
  }

  void _finishConnection(Offset point) {
    if (connectionSourceId == null) {
      _cancelConnection();
      return;
    }

    final hit = _hitTester.test(point, diagram);
    if (hit.hitNode &&
        hit.nodeId != connectionSourceId &&
        canConnect(connectionSourceId!, hit.nodeId!)) {
      final edgeId = _idGen.next('flow');
      final edge = EdgeModel(
        id: edgeId,
        sourceId: connectionSourceId!,
        targetId: hit.nodeId!,
      );
      _exec(AddEdgeCommand(edge));
      // Reroute all edges with port distribution.
      _assignPortsAndRoute();
    }

    _cancelConnection();
  }

  /// Reroute all edges in the diagram.
  void rerouteAllEdges() {
    _assignPortsAndRoute();
    notifyListeners();
  }

  /// Auto-layout: clean grid-based layered layout.
  ///
  /// 1. Longest-path layering from roots (topological)
  /// 2. Order nodes within each layer by parent position
  /// 3. Place on a clean grid with round coordinates
  /// 4. Center single-child chains and merge nodes
  /// 5. Reroute all edges
  void autoLayout() {
    if (diagram.nodes.isEmpty) return;

    const colW = 180.0; // horizontal spacing between node centers
    const rowH = 130.0; // vertical spacing between layers
    const startY = 100.0;

    // ── Build adjacency ──
    final childMap = <String, List<String>>{};
    final parentMap = <String, List<String>>{};
    for (final edge in diagram.edges.values) {
      childMap.putIfAbsent(edge.sourceId, () => []).add(edge.targetId);
      parentMap.putIfAbsent(edge.targetId, () => []).add(edge.sourceId);
    }

    // ── Find roots (prefer startEvent) ──
    var roots = diagram.nodes.keys
        .where((id) => (parentMap[id]?.isEmpty ?? true))
        .toList();
    roots.sort((a, b) {
      final aS = diagram.nodes[a]?.type == NodeType.startEvent ? 0 : 1;
      final bS = diagram.nodes[b]?.type == NodeType.startEvent ? 0 : 1;
      return aS.compareTo(bS);
    });
    if (roots.isEmpty) roots = [diagram.nodes.keys.first];

    // ── 1. Longest-path layering (push nodes as deep as possible) ──
    final layer = <String, int>{};
    void assignLayer(String id, int depth) {
      if (layer.containsKey(id) && layer[id]! >= depth) return;
      layer[id] = depth;
      for (final kid in childMap[id] ?? <String>[]) {
        assignLayer(kid, depth + 1);
      }
    }
    for (final root in roots) {
      assignLayer(root, 0);
    }
    // Orphan nodes go at the end.
    var orphanLayer = (layer.values.fold(0, (a, b) => a > b ? a : b)) + 1;
    for (final id in diagram.nodes.keys) {
      layer.putIfAbsent(id, () => orphanLayer++);
    }

    // Forward children = children in a deeper layer.
    List<String> fwdKids(String id) =>
        (childMap[id] ?? <String>[])
            .where((k) => layer.containsKey(k) && layer[k]! > layer[id]!)
            .toList();

    // ── 2. Compute subtree widths (in slots) ──
    final subtreeW = <String, int>{};
    final computing = <String>{};
    int getSubtreeWidth(String id) {
      if (subtreeW.containsKey(id)) return subtreeW[id]!;
      if (computing.contains(id)) {
        subtreeW[id] = 1;
        return 1;
      }
      computing.add(id);
      final kids = fwdKids(id);
      if (kids.isEmpty) {
        subtreeW[id] = 1;
        return 1;
      }
      var w = 0;
      for (final k in kids) {
        w += getSubtreeWidth(k);
      }
      subtreeW[id] = w;
      return w;
    }
    for (final r in roots) {
      getSubtreeWidth(r);
    }
    for (final id in diagram.nodes.keys) {
      subtreeW.putIfAbsent(id, () => 1);
    }

    // ── 3. Place tree top-down, centering each node in its subtree span ──
    final xSlot = <String, double>{}; // slot position (multiply by colW later)
    final placed = <String>{};

    void placeSubtree(String id, double leftSlot) {
      if (placed.contains(id)) return;
      placed.add(id);
      final w = subtreeW[id]!;
      xSlot[id] = leftSlot + w / 2.0;

      final kids = fwdKids(id).where((k) => !placed.contains(k)).toList();
      // Sort kids by subtree width descending so wider subtrees go center.
      // Actually, keep original edge order for predictable layout.
      var kidLeft = leftSlot;
      for (final k in kids) {
        placeSubtree(k, kidLeft);
        kidLeft += subtreeW[k]!;
      }
    }

    var nextRootSlot = 0.0;
    for (final r in roots) {
      placeSubtree(r, nextRootSlot);
      nextRootSlot += subtreeW[r]! + 1; // gap between root trees
    }
    // Place any remaining unplaced nodes.
    for (final id in diagram.nodes.keys) {
      if (!placed.contains(id)) {
        xSlot[id] = nextRootSlot;
        nextRootSlot += 1;
      }
    }

    // ── 4. Refinement: center parents over children, merge nodes between parents ──
    // Build layer lists sorted by current x.
    Map<int, List<String>> buildLayers() {
      final layers = <int, List<String>>{};
      for (final e in layer.entries) {
        layers.putIfAbsent(e.value, () => []).add(e.key);
      }
      for (final l in layers.values) {
        l.sort((a, b) => xSlot[a]!.compareTo(xSlot[b]!));
      }
      return layers;
    }

    // Identify merge nodes (2+ forward parents) — these need centering.
    final mergeNodes = <String>{};
    for (final id in diagram.nodes.keys) {
      final parents = (parentMap[id] ?? [])
          .where((p) => layer.containsKey(p) && layer[p]! < layer[id]!)
          .toList();
      if (parents.length >= 2) mergeNodes.add(id);
    }

    // Shift a node and all its unique descendants by delta.
    void shiftSubtree(String id, double delta, Set<String> visited) {
      for (final kid in fwdKids(id)) {
        if (visited.contains(kid)) continue;
        visited.add(kid);
        xSlot[kid] = (xSlot[kid] ?? 0) + delta;
        shiftSubtree(kid, delta, visited);
      }
    }

    for (var pass = 0; pass < 6; pass++) {
      final layers = buildLayers();
      final sortedKeys = layers.keys.toList()..sort();

      // Bottom-up first: center branch points (2+ children) over children.
      // This establishes good positions for branch nodes.
      for (final li in sortedKeys.reversed) {
        for (final id in layers[li]!) {
          final kids = fwdKids(id)
              .where((k) => xSlot.containsKey(k))
              .toList();
          if (kids.length < 2) continue;
          final avgChildX =
              kids.map((k) => xSlot[k]!).reduce((a, b) => a + b) /
                  kids.length;
          xSlot[id] = avgChildX;
        }
      }

      // Top-down: align single-child chains and center merge nodes.
      // When a merge node moves, shift its entire subtree.
      for (final li in sortedKeys) {
        for (final id in layers[li]!) {
          final parents = (parentMap[id] ?? [])
              .where((p) => xSlot.containsKey(p) &&
                  layer.containsKey(p) && layer[p]! < layer[id]!)
              .toList();
          if (parents.isEmpty) continue;

          if (mergeNodes.contains(id)) {
            // Merge node: center between all parents.
            final avgX =
                parents.map((p) => xSlot[p]!).reduce((a, b) => a + b) /
                    parents.length;
            final oldX = xSlot[id]!;
            xSlot[id] = avgX;
            // Shift descendants so they move with the merge node.
            if ((avgX - oldX).abs() > 0.01) {
              shiftSubtree(id, avgX - oldX, {id});
            }
          } else if (parents.length == 1) {
            // Single parent → single child: align directly under parent.
            final pid = parents.first;
            if (fwdKids(pid).length == 1) {
              final oldX = xSlot[id]!;
              xSlot[id] = xSlot[pid]!;
              if ((xSlot[pid]! - oldX).abs() > 0.01) {
                shiftSubtree(id, xSlot[pid]! - oldX, {id});
              }
            }
          }
        }
      }

      // Push apart overlaps within each layer (minimum 1 slot apart).
      for (final li in sortedKeys) {
        final ids = layers[li]!;
        ids.sort((a, b) => xSlot[a]!.compareTo(xSlot[b]!));
        for (var i = 1; i < ids.length; i++) {
          if (xSlot[ids[i]]! - xSlot[ids[i - 1]]! < 1.0) {
            xSlot[ids[i]] = xSlot[ids[i - 1]]! + 1.0;
          }
        }
      }
    }

    // ── 5. Convert slots to pixel coordinates, round to integers ──
    // Center the diagram around x=400.
    final allSlots = xSlot.values.toList();
    final minSlot = allSlots.reduce((a, b) => a < b ? a : b);
    final maxSlot = allSlots.reduce((a, b) => a > b ? a : b);
    final centerSlot = (minSlot + maxSlot) / 2;

    for (final id in diagram.nodes.keys) {
      final node = diagram.nodes[id]!;
      final x = 400.0 + (xSlot[id]! - centerSlot) * colW;
      final y = startY + layer[id]! * rowH;
      // Round to nearest 10 for clean coordinates.
      final rx = (x / 10).round() * 10.0;
      final ry = (y / 10).round() * 10.0;
      node.rect = NodeModel.defaultRect(node.type, Offset(rx, ry));
    }

    // Clear all waypoints so they get freshly routed.
    for (final edge in diagram.edges.values) {
      edge.waypoints = [];
    }

    _assignPortsAndRoute();
    notifyListeners();
  }

  /// Assign ports to all edges, distributing outputs from the same node
  /// across different sides, then route each edge.
  void _assignPortsAndRoute() {
    // Phase 1: Compute initial sides for each edge.
    final sides = <String, (ConnectorSide src, ConnectorSide tgt)>{};
    for (final edge in diagram.edges.values) {
      final source = diagram.nodes[edge.sourceId];
      final target = diagram.nodes[edge.targetId];
      if (source == null || target == null) continue;
      sides[edge.id] = (
        _router.bestSourceSide(source, target),
        _router.bestTargetSide(source, target,
            _router.bestSourceSide(source, target)),
      );
    }

    // Phase 2: Distribute conflicting source ports.
    // Group outgoing edges by source node.
    final outgoing = <String, List<EdgeModel>>{};
    for (final edge in diagram.edges.values) {
      outgoing.putIfAbsent(edge.sourceId, () => []).add(edge);
    }
    for (final entry in outgoing.entries) {
      final edges = entry.value;
      if (edges.length < 2) continue;
      _distributeSourcePorts(entry.key, edges, sides);
    }

    // Phase 3: Ensure input ports don't collide with output ports.
    // Multiple inputs on the same port are fine (merge bars handle them).
    for (final node in diagram.nodes.values) {
      final outs = diagram.edges.values.where((e) => e.sourceId == node.id);
      final ins = diagram.edges.values.where((e) => e.targetId == node.id).toList();
      final usedOutPorts = outs.map((e) => sides[e.id]?.$1).whereType<ConnectorSide>().toSet();
      for (final inEdge in ins) {
        final s = sides[inEdge.id];
        if (s == null) continue;
        if (usedOutPorts.contains(s.$2)) {
          // Try best alternate side facing the source, avoiding output ports.
          final source = diagram.nodes[inEdge.sourceId];
          if (source != null) {
            final alt = _alternatePort(node, source.center, usedOutPorts);
            if (!usedOutPorts.contains(alt)) {
              sides[inEdge.id] = (s.$1, alt);
              continue;
            }
          }
          // Fallback: try opposite side.
          final opp = _opposite(s.$2);
          if (!usedOutPorts.contains(opp)) {
            sides[inEdge.id] = (s.$1, opp);
          }
        }
      }
    }

    // Phase 4: Compute channel biases for edges sharing a Z-channel.
    // Group incoming edges by target node and target side.
    final channelBias = <String, double>{};
    final incoming = <String, List<EdgeModel>>{};
    for (final edge in diagram.edges.values) {
      incoming.putIfAbsent(edge.targetId, () => []).add(edge);
    }
    for (final entry in incoming.entries) {
      if (entry.value.length < 2) continue;
      // Group by target side (edges entering from the same side share a channel).
      final bySide = <ConnectorSide, List<EdgeModel>>{};
      for (final edge in entry.value) {
        final s = sides[edge.id];
        if (s == null) continue;
        bySide.putIfAbsent(s.$2, () => []).add(edge);
      }
      for (final sideEdges in bySide.values) {
        if (sideEdges.length < 2) continue;
        // Sort by source cross-axis position for consistent ordering.
        final tgtSide = sides[sideEdges.first.id]!.$2;
        final isH = tgtSide == ConnectorSide.left || tgtSide == ConnectorSide.right;
        sideEdges.sort((a, b) {
          final sa = diagram.nodes[a.sourceId]?.center ?? Offset.zero;
          final sb = diagram.nodes[b.sourceId]?.center ?? Offset.zero;
          return isH
              ? sa.dy.compareTo(sb.dy)
              : sa.dx.compareTo(sb.dx);
        });
        for (int i = 0; i < sideEdges.length; i++) {
          // Spread from -1 to +1 evenly.
          final t = sideEdges.length == 1
              ? 0.0
              : -1.0 + 2.0 * i / (sideEdges.length - 1);
          channelBias[sideEdges[i].id] = t;
        }
      }
    }

    // Phase 5: Route each edge with its assigned sides and channel bias.
    // Skip edges that already have manually defined waypoints.
    for (final edge in diagram.edges.values) {
      final source = diagram.nodes[edge.sourceId];
      final target = diagram.nodes[edge.targetId];
      if (source == null || target == null) continue;

      final s = sides[edge.id]!;

      if (edge.waypoints.isEmpty) {
        final obstacles = diagram.nodes.values
            .where((n) => n.id != source.id && n.id != target.id)
            .toList();

        edge.waypoints = _router.route(
          source: source,
          target: target,
          sourceSide: s.$1,
          targetSide: s.$2,
          obstacles: obstacles,
          channelBias: channelBias[edge.id] ?? 0.0,
        );
      }
      edge.sourceSide = s.$1;
      edge.targetSide = s.$2;
    }
  }

  /// Distribute outgoing edges from a node across different source ports.
  void _distributeSourcePorts(
      String nodeId,
      List<EdgeModel> edges,
      Map<String, (ConnectorSide, ConnectorSide)> sides) {
    final node = diagram.nodes[nodeId];
    if (node == null) return;

    // Pre-reserve ports used by incoming edges so outputs avoid them.
    final incomingPorts = <ConnectorSide>{};
    for (final inEdge in diagram.edges.values) {
      if (inEdge.targetId == nodeId) {
        final s = sides[inEdge.id];
        if (s != null) incomingPorts.add(s.$2);
      }
    }

    // Sort by angle from node center to target center.
    edges.sort((a, b) {
      final ta = diagram.nodes[a.targetId]?.center ?? Offset.zero;
      final tb = diagram.nodes[b.targetId]?.center ?? Offset.zero;
      final angleA = _angle(node.center, ta);
      final angleB = _angle(node.center, tb);
      return angleA.compareTo(angleB);
    });

    // Assign each edge to the port closest to its target direction,
    // avoiding duplicates and incoming ports when possible.
    final usedPorts = <ConnectorSide>{};
    for (final edge in edges) {
      final target = diagram.nodes[edge.targetId];
      if (target == null) continue;

      final preferred = _router.bestSourceSide(node, target);
      if (!usedPorts.contains(preferred) && !incomingPorts.contains(preferred)) {
        usedPorts.add(preferred);
        final s = sides[edge.id]!;
        sides[edge.id] = (preferred, s.$2);
      } else if (!usedPorts.contains(preferred)) {
        // Port is used by incoming but not by another outgoing — use it as fallback.
        usedPorts.add(preferred);
        final s = sides[edge.id]!;
        sides[edge.id] = (preferred, s.$2);
      } else {
        // Pick the next best unused port, preferring non-incoming ports.
        final avoidSet = <ConnectorSide>{...usedPorts, ...incomingPorts};
        var alt = _alternatePort(node, target.center, avoidSet);
        // If all non-incoming ports are used, fall back to any unused port.
        if (usedPorts.contains(alt)) {
          alt = _alternatePort(node, target.center, usedPorts);
        }
        usedPorts.add(alt);
        final s = sides[edge.id]!;
        sides[edge.id] = (alt, s.$2);
      }
    }
  }

  /// Pick the best alternative port for a node→target that avoids [used] ports.
  ConnectorSide _alternatePort(
      NodeModel node, Offset target, Set<ConnectorSide> used) {
    final dx = target.dx - node.center.dx;
    final dy = target.dy - node.center.dy;

    // Rank all 4 sides by how well they face the target.
    final ranked = <ConnectorSide>[
      if (dy < 0) ConnectorSide.top,
      if (dy > 0) ConnectorSide.bottom,
      if (dx > 0) ConnectorSide.right,
      if (dx < 0) ConnectorSide.left,
      // Fill in remaining sides.
      if (dy >= 0) ConnectorSide.top,
      if (dy <= 0) ConnectorSide.bottom,
      if (dx <= 0) ConnectorSide.right,
      if (dx >= 0) ConnectorSide.left,
    ];

    for (final side in ranked) {
      if (!used.contains(side)) return side;
    }
    // All used — return primary direction.
    return ranked.first;
  }

  double _angle(Offset from, Offset to) {
    return (to.dy - from.dy).abs() < 0.1 && (to.dx - from.dx).abs() < 0.1
        ? 0.0
        : _atan2(to.dy - from.dy, to.dx - from.dx);
  }

  double _atan2(double y, double x) {
    // Simple atan2 without importing dart:math in this file.
    if (x > 0) return y / (x.abs() + y.abs());
    if (x < 0) return 2 - y / (x.abs() + y.abs());
    return y > 0 ? 1 : -1;
  }

  ConnectorSide _opposite(ConnectorSide side) {
    switch (side) {
      case ConnectorSide.top: return ConnectorSide.bottom;
      case ConnectorSide.bottom: return ConnectorSide.top;
      case ConnectorSide.left: return ConnectorSide.right;
      case ConnectorSide.right: return ConnectorSide.left;
    }
  }

  void _cancelConnection() {
    isConnecting = false;
    connectionEnd = null;
    connectionSourceId = null;
    connectionSourceSide = null;
    connectionTargetId = null;
    notifyListeners();
  }

  /// Load a new diagram (e.g. from import).
  void loadDiagram(DiagramModel newDiagram) {
    diagram = newDiagram;
    _commandStack.clear();
    selectedNodeId = null;
    selectedEdgeId = null;
    _idGen.seedFrom(diagram.nodes.keys.followedBy(diagram.edges.keys));
    // Route edges with port distribution.
    _assignPortsAndRoute();
    notifyListeners();
  }
}
