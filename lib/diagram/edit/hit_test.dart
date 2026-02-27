import 'dart:ui';
import '../model/diagram_model.dart';

/// Which side of a node the connector handle is on.
enum ConnectorSide { top, right, bottom, left }

/// Returns the center position of a connector handle for a given node and side.
/// Handles touch the node border and extend outward.
Offset connectorHandleCenter(NodeModel node, ConnectorSide side) {
  const r = 6.0; // dot radius — center is offset outward by this amount
  switch (side) {
    case ConnectorSide.top:
      return Offset(node.rect.center.dx, node.rect.top - r);
    case ConnectorSide.right:
      return Offset(node.rect.right + r, node.rect.center.dy);
    case ConnectorSide.bottom:
      return Offset(node.rect.center.dx, node.rect.bottom + r);
    case ConnectorSide.left:
      return Offset(node.rect.left - r, node.rect.center.dy);
  }
}

/// Result of a hit test on the diagram canvas.
class HitTestResult {
  final String? nodeId;
  final String? edgeId;
  final bool isConnectorHandle;
  final ConnectorSide? connectorSide;

  const HitTestResult({
    this.nodeId,
    this.edgeId,
    this.isConnectorHandle = false,
    this.connectorSide,
  });

  bool get hitNode => nodeId != null;
  bool get hitEdge => edgeId != null;
  bool get hitNothing => !hitNode && !hitEdge;
}

/// Performs hit-testing against diagram elements.
class HitTester {
  static const double _edgeHitThreshold = 24.0;
  static const double _connectorHandleRadius = 24.0;
  static const double _connectorHandleRadiusDrag = 54.0;
  static const double _nodeInflate = 14.0;
  static const double _nodeInflateDrag = 26.0;

  /// Test a point against the diagram. Nodes are checked first.
  /// Use [forDrag] = true for drag-start to allow a more forgiving hit area.
  HitTestResult test(Offset point, DiagramModel model,
      {String? selectedNodeId, bool forDrag = false}) {
    // Check connector handles if a node is selected.
    // Only report a handle hit if the touch is closer to the handle
    // than to the node center (handles sit on the border now).
    if (selectedNodeId != null) {
      final node = model.nodes[selectedNodeId];
      if (node != null) {
        final handleRadius =
            forDrag ? _connectorHandleRadiusDrag : _connectorHandleRadius;
        final centerDist = (point - node.center).distance;
        double bestHandleDist = double.infinity;
        ConnectorSide? bestSide;
        for (final side in ConnectorSide.values) {
          final center = connectorHandleCenter(node, side);
          final d = (point - center).distance;
          if (d <= handleRadius && d < bestHandleDist) {
            bestHandleDist = d;
            bestSide = side;
          }
        }
        if (bestSide != null && bestHandleDist < centerDist) {
          return HitTestResult(
            nodeId: selectedNodeId,
            isConnectorHandle: true,
            connectorSide: bestSide,
          );
        }
      }
    }

    // Check nodes (reverse order for z-order).
    final inflate = forDrag ? _nodeInflateDrag : _nodeInflate;
    for (final node in model.nodes.values.toList().reversed) {
      if (_hitTestNode(point, node, inflate)) {
        return HitTestResult(nodeId: node.id);
      }
    }

    // Check edges.
    for (final edge in model.edges.values) {
      if (_hitTestEdge(point, edge, model)) {
        return HitTestResult(edgeId: edge.id);
      }
    }

    return const HitTestResult();
  }

  bool _hitTestNode(Offset point, NodeModel node, double inflate) {
    final inflated = node.rect.inflate(inflate);

    if (node.type == NodeType.startEvent || node.type == NodeType.endEvent) {
      // Circle hit test.
      return (point - node.center).distance <= inflated.width / 2;
    }

    if (node.type == NodeType.exclusiveGateway) {
      // Diamond hit test: check if point is inside the diamond.
      final cx = node.center.dx;
      final cy = node.center.dy;
      final hw = inflated.width / 2;
      final hh = inflated.height / 2;
      final dx = (point.dx - cx).abs();
      final dy = (point.dy - cy).abs();
      return (dx / hw + dy / hh) <= 1.0;
    }

    // Rectangle hit test for tasks.
    return inflated.contains(point);
  }

  bool _hitTestEdge(Offset point, EdgeModel edge, DiagramModel model) {
    final wps = edge.waypoints.isNotEmpty
        ? edge.waypoints
        : _defaultWaypoints(edge, model);
    if (wps.length < 2) return false;

    for (int i = 0; i < wps.length - 1; i++) {
      if (_distToSegment(point, wps[i], wps[i + 1]) < _edgeHitThreshold) {
        return true;
      }
    }
    return false;
  }

  List<Offset> _defaultWaypoints(EdgeModel edge, DiagramModel model) {
    final s = model.nodes[edge.sourceId];
    final t = model.nodes[edge.targetId];
    if (s == null || t == null) return [];
    return [s.center, t.center];
  }

  double _distToSegment(Offset p, Offset a, Offset b) {
    final ab = b - a;
    final ap = p - a;
    final lenSq = ab.dx * ab.dx + ab.dy * ab.dy;
    if (lenSq == 0) return (p - a).distance;
    var t = (ap.dx * ab.dx + ap.dy * ab.dy) / lenSq;
    t = t.clamp(0.0, 1.0);
    final proj = Offset(a.dx + t * ab.dx, a.dy + t * ab.dy);
    return (p - proj).distance;
  }
}
