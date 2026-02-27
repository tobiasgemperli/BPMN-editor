import 'dart:ui';
import '../model/diagram_model.dart';

/// Result of a hit test on the diagram canvas.
class HitTestResult {
  final String? nodeId;
  final String? edgeId;
  final bool isConnectorHandle;

  const HitTestResult({this.nodeId, this.edgeId, this.isConnectorHandle = false});

  bool get hitNode => nodeId != null;
  bool get hitEdge => edgeId != null;
  bool get hitNothing => !hitNode && !hitEdge;
}

/// Performs hit-testing against diagram elements.
class HitTester {
  static const double _edgeHitThreshold = 12.0;
  static const double _connectorHandleRadius = 14.0;

  /// Test a point against the diagram. Nodes are checked first.
  HitTestResult test(Offset point, DiagramModel model, {String? selectedNodeId}) {
    // Check connector handle first if a node is selected.
    if (selectedNodeId != null) {
      final node = model.nodes[selectedNodeId];
      if (node != null) {
        final handleCenter = Offset(node.rect.right + 16, node.rect.center.dy);
        if ((point - handleCenter).distance <= _connectorHandleRadius) {
          return HitTestResult(nodeId: selectedNodeId, isConnectorHandle: true);
        }
      }
    }

    // Check nodes (reverse order for z-order).
    for (final node in model.nodes.values.toList().reversed) {
      if (_hitTestNode(point, node)) {
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

  bool _hitTestNode(Offset point, NodeModel node) {
    // Inflate rect slightly for touch friendliness.
    final inflated = node.rect.inflate(6);

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
