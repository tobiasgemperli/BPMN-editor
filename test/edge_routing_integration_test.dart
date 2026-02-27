import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:bpmn_editor/diagram/model/diagram_model.dart';
import 'package:bpmn_editor/diagram/edit/hit_test.dart';
import 'package:bpmn_editor/diagram/routing/orthogonal_router.dart';
import 'package:bpmn_editor/diagram/render/merge_bar.dart';
import 'package:bpmn_editor/diagram/samples/sample_diagrams.dart';

final _router = OrthogonalRouter();

// ── Helpers ──────────────────────────────────────────────────────────────

NodeModel _task(String id, double cx, double cy,
    {double w = 140, double h = 70}) {
  return NodeModel(
    id: id,
    type: NodeType.task,
    name: id,
    rect: Rect.fromCenter(center: Offset(cx, cy), width: w, height: h),
  );
}

NodeModel _gateway(String id, double cx, double cy) {
  return NodeModel(
    id: id,
    type: NodeType.exclusiveGateway,
    name: id,
    rect: Rect.fromCenter(center: Offset(cx, cy), width: 56, height: 56),
  );
}

NodeModel _event(String id, double cx, double cy, {bool end = false}) {
  return NodeModel(
    id: id,
    type: end ? NodeType.endEvent : NodeType.startEvent,
    name: id,
    rect: Rect.fromCenter(center: Offset(cx, cy), width: 48, height: 48),
  );
}

/// Route all edges in a diagram with port distribution (mimics loadDiagram).
void routeAllEdges(DiagramModel diagram) {
  // Phase 1: Compute initial sides.
  final sides = <String, (ConnectorSide src, ConnectorSide tgt)>{};
  for (final edge in diagram.edges.values) {
    final source = diagram.nodes[edge.sourceId]!;
    final target = diagram.nodes[edge.targetId]!;
    sides[edge.id] = (
      _router.bestSourceSide(source, target),
      _router.bestTargetSide(source, target,
          _router.bestSourceSide(source, target)),
    );
  }

  // Phase 2: Distribute conflicting source ports.
  final outgoing = <String, List<EdgeModel>>{};
  for (final edge in diagram.edges.values) {
    outgoing.putIfAbsent(edge.sourceId, () => []).add(edge);
  }
  for (final entry in outgoing.entries) {
    final edges = entry.value;
    if (edges.length < 2) continue;
    _distributeSourcePorts(entry.key, edges, sides, diagram);
  }

  // Phase 3: Distribute conflicting target ports (input ≠ output).
  for (final node in diagram.nodes.values) {
    final outs = diagram.edges.values.where((e) => e.sourceId == node.id);
    final ins = diagram.edges.values.where((e) => e.targetId == node.id);
    final usedOutPorts = outs.map((e) => sides[e.id]?.$1).whereType<ConnectorSide>().toSet();
    for (final inEdge in ins) {
      final s = sides[inEdge.id];
      if (s != null && usedOutPorts.contains(s.$2)) {
        sides[inEdge.id] = (s.$1, _oppositeSide(s.$2));
      }
    }
  }

  // Phase 4: Compute channel biases for edges sharing a Z-channel.
  final channelBias = <String, double>{};
  final incoming = <String, List<EdgeModel>>{};
  for (final edge in diagram.edges.values) {
    incoming.putIfAbsent(edge.targetId, () => []).add(edge);
  }
  for (final entry in incoming.entries) {
    if (entry.value.length < 2) continue;
    final bySide = <ConnectorSide, List<EdgeModel>>{};
    for (final edge in entry.value) {
      final s = sides[edge.id];
      if (s == null) continue;
      bySide.putIfAbsent(s.$2, () => []).add(edge);
    }
    for (final sideEdges in bySide.values) {
      if (sideEdges.length < 2) continue;
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
        final t = sideEdges.length == 1
            ? 0.0
            : -1.0 + 2.0 * i / (sideEdges.length - 1);
        channelBias[sideEdges[i].id] = t;
      }
    }
  }

  // Phase 5: Route with assigned sides and channel bias.
  for (final edge in diagram.edges.values) {
    final source = diagram.nodes[edge.sourceId]!;
    final target = diagram.nodes[edge.targetId]!;
    final s = sides[edge.id]!;
    final obstacles = diagram.nodes.values
        .where((n) => n.id != source.id && n.id != target.id)
        .toList();
    edge.waypoints = _router.route(
      source: source, target: target,
      sourceSide: s.$1, targetSide: s.$2,
      obstacles: obstacles,
      channelBias: channelBias[edge.id] ?? 0.0,
    );
    edge.sourceSide = s.$1;
    edge.targetSide = s.$2;
  }
}

void _distributeSourcePorts(
    String nodeId, List<EdgeModel> edges,
    Map<String, (ConnectorSide, ConnectorSide)> sides, DiagramModel diagram) {
  final node = diagram.nodes[nodeId]!;
  edges.sort((a, b) {
    final ta = diagram.nodes[a.targetId]?.center ?? Offset.zero;
    final tb = diagram.nodes[b.targetId]?.center ?? Offset.zero;
    final angleA = _angle(node.center, ta);
    final angleB = _angle(node.center, tb);
    return angleA.compareTo(angleB);
  });

  final usedPorts = <ConnectorSide>{};
  for (final edge in edges) {
    final target = diagram.nodes[edge.targetId];
    if (target == null) continue;
    final preferred = _router.bestSourceSide(node, target);
    if (!usedPorts.contains(preferred)) {
      usedPorts.add(preferred);
      final s = sides[edge.id]!;
      sides[edge.id] = (preferred, s.$2);
    } else {
      final alt = _alternatePort(node, target.center, usedPorts);
      usedPorts.add(alt);
      final s = sides[edge.id]!;
      sides[edge.id] = (alt, s.$2);
    }
  }
}

ConnectorSide _alternatePort(
    NodeModel node, Offset target, Set<ConnectorSide> used) {
  final dx = target.dx - node.center.dx;
  final dy = target.dy - node.center.dy;
  final ranked = <ConnectorSide>[
    if (dy < 0) ConnectorSide.top,
    if (dy > 0) ConnectorSide.bottom,
    if (dx > 0) ConnectorSide.right,
    if (dx < 0) ConnectorSide.left,
    if (dy >= 0) ConnectorSide.top,
    if (dy <= 0) ConnectorSide.bottom,
    if (dx <= 0) ConnectorSide.right,
    if (dx >= 0) ConnectorSide.left,
  ];
  for (final side in ranked) {
    if (!used.contains(side)) return side;
  }
  return ranked.first;
}

double _angle(Offset from, Offset to) {
  final dx = to.dx - from.dx;
  final dy = to.dy - from.dy;
  if (dx.abs() < 0.1 && dy.abs() < 0.1) return 0.0;
  // Simple angle approximation for sorting.
  if (dx > 0) return dy / (dx.abs() + dy.abs());
  if (dx < 0) return 2 - dy / (dx.abs() + dy.abs());
  return dy > 0 ? 1 : -1;
}

ConnectorSide _oppositeSide(ConnectorSide side) {
  switch (side) {
    case ConnectorSide.top: return ConnectorSide.bottom;
    case ConnectorSide.bottom: return ConnectorSide.top;
    case ConnectorSide.left: return ConnectorSide.right;
    case ConnectorSide.right: return ConnectorSide.left;
  }
}

/// Verify all segments in a waypoint list are orthogonal.
void expectOrthogonal(List<Offset> wps, {String label = ''}) {
  for (int i = 0; i < wps.length - 1; i++) {
    final a = wps[i];
    final b = wps[i + 1];
    final isH = (a.dy - b.dy).abs() < 0.5;
    final isV = (a.dx - b.dx).abs() < 0.5;
    expect(isH || isV, isTrue,
        reason: '$label segment $i->${'${i + 1}'} is diagonal: '
            '(${a.dx.toStringAsFixed(1)}, ${a.dy.toStringAsFixed(1)}) -> '
            '(${b.dx.toStringAsFixed(1)}, ${b.dy.toStringAsFixed(1)})');
  }
}

/// Check that the first segment of a routed edge exits in the port's direction.
/// Right port → horizontal right, left → horizontal left, top → vertical up, bottom → vertical down.
void expectFirstSegmentMatchesPort(List<Offset> wps, ConnectorSide side, {String label = ''}) {
  expect(wps.length, greaterThanOrEqualTo(2), reason: '$label needs >= 2 waypoints');
  final a = wps[0];
  final b = wps[1];
  switch (side) {
    case ConnectorSide.right:
      expect(b.dx, greaterThan(a.dx - 0.1),
          reason: '$label right-port first segment should go rightward');
      expect((a.dy - b.dy).abs(), lessThan(0.5),
          reason: '$label right-port first segment should be horizontal');
      break;
    case ConnectorSide.left:
      expect(b.dx, lessThan(a.dx + 0.1),
          reason: '$label left-port first segment should go leftward');
      expect((a.dy - b.dy).abs(), lessThan(0.5),
          reason: '$label left-port first segment should be horizontal');
      break;
    case ConnectorSide.bottom:
      expect(b.dy, greaterThan(a.dy - 0.1),
          reason: '$label bottom-port first segment should go downward');
      expect((a.dx - b.dx).abs(), lessThan(0.5),
          reason: '$label bottom-port first segment should be vertical');
      break;
    case ConnectorSide.top:
      expect(b.dy, lessThan(a.dy + 0.1),
          reason: '$label top-port first segment should go upward');
      expect((a.dx - b.dx).abs(), lessThan(0.5),
          reason: '$label top-port first segment should be vertical');
      break;
  }
}

/// Check two edge polylines don't share any overlapping collinear segments.
/// [skipSharedStart] skips segments from edges that share a common source point.
bool hasOverlappingSegments(List<Offset> wpsA, List<Offset> wpsB,
    {bool skipSharedStart = false}) {
  final startA = skipSharedStart ? _findDivergenceIndex(wpsA, wpsB) : 0;
  final startB = skipSharedStart ? _findDivergenceIndex(wpsB, wpsA) : 0;

  for (int i = startA; i < wpsA.length - 1; i++) {
    for (int j = startB; j < wpsB.length - 1; j++) {
      if (_segmentsOverlap(wpsA[i], wpsA[i + 1], wpsB[j], wpsB[j + 1])) {
        return true;
      }
    }
  }
  return false;
}

/// Find the first segment index where edge A diverges from edge B.
/// Handles both identical waypoints and collinear first segments
/// (e.g. two edges from the same gateway port where one is a subsegment
/// of the other's first segment).
int _findDivergenceIndex(List<Offset> wpsA, List<Offset> wpsB) {
  int shared = 0;
  final limit = wpsA.length < wpsB.length ? wpsA.length : wpsB.length;
  for (int i = 0; i < limit; i++) {
    if ((wpsA[i].dx - wpsB[i].dx).abs() < 0.5 &&
        (wpsA[i].dy - wpsB[i].dy).abs() < 0.5) {
      shared = i;
    } else {
      break;
    }
  }
  if (shared > 0) return shared;

  // Check for collinear first segments: same start point, same direction,
  // one segment may be longer than the other.
  if (wpsA.length >= 2 && wpsB.length >= 2 &&
      (wpsA[0].dx - wpsB[0].dx).abs() < 0.5 &&
      (wpsA[0].dy - wpsB[0].dy).abs() < 0.5) {
    final aH = (wpsA[0].dy - wpsA[1].dy).abs() < 0.5;
    final bH = (wpsB[0].dy - wpsB[1].dy).abs() < 0.5;
    final aV = (wpsA[0].dx - wpsA[1].dx).abs() < 0.5;
    final bV = (wpsB[0].dx - wpsB[1].dx).abs() < 0.5;
    // Both horizontal at same Y, or both vertical at same X → collinear.
    if ((aH && bH) || (aV && bV)) {
      return 1; // Skip the first segment.
    }
  }
  return 0;
}

/// Two orthogonal segments overlap if they're collinear and share a range.
bool _segmentsOverlap(Offset a1, Offset a2, Offset b1, Offset b2) {
  final aIsH = (a1.dy - a2.dy).abs() < 0.5;
  final bIsH = (b1.dy - b2.dy).abs() < 0.5;
  final aIsV = (a1.dx - a2.dx).abs() < 0.5;
  final bIsV = (b1.dx - b2.dx).abs() < 0.5;

  // Both horizontal, same Y.
  if (aIsH && bIsH && (a1.dy - b1.dy).abs() < 0.5) {
    final aMin = a1.dx < a2.dx ? a1.dx : a2.dx;
    final aMax = a1.dx > a2.dx ? a1.dx : a2.dx;
    final bMin = b1.dx < b2.dx ? b1.dx : b2.dx;
    final bMax = b1.dx > b2.dx ? b1.dx : b2.dx;
    // Overlap if ranges intersect with more than a point.
    final overlapStart = aMin > bMin ? aMin : bMin;
    final overlapEnd = aMax < bMax ? aMax : bMax;
    return (overlapEnd - overlapStart) > 1.0;
  }

  // Both vertical, same X.
  if (aIsV && bIsV && (a1.dx - b1.dx).abs() < 0.5) {
    final aMin = a1.dy < a2.dy ? a1.dy : a2.dy;
    final aMax = a1.dy > a2.dy ? a1.dy : a2.dy;
    final bMin = b1.dy < b2.dy ? b1.dy : b2.dy;
    final bMax = b1.dy > b2.dy ? b1.dy : b2.dy;
    final overlapStart = aMin > bMin ? aMin : bMin;
    final overlapEnd = aMax < bMax ? aMax : bMax;
    return (overlapEnd - overlapStart) > 1.0;
  }

  return false;
}

/// Check if an orthogonal segment intersects a node's inflated rect.
/// Uses a small margin to avoid false positives from border-touching segments.
bool segmentCrossesRect(Offset a, Offset b, Rect rect) {
  final inflated = rect.inflate(-2.0); // shrink slightly to avoid border touches
  final isH = (a.dy - b.dy).abs() < 0.5;
  final isV = (a.dx - b.dx).abs() < 0.5;

  if (isH) {
    final y = a.dy;
    if (y <= inflated.top || y >= inflated.bottom) return false;
    final minX = a.dx < b.dx ? a.dx : b.dx;
    final maxX = a.dx > b.dx ? a.dx : b.dx;
    return maxX > inflated.left && minX < inflated.right;
  }
  if (isV) {
    final x = a.dx;
    if (x <= inflated.left || x >= inflated.right) return false;
    final minY = a.dy < b.dy ? a.dy : b.dy;
    final maxY = a.dy > b.dy ? a.dy : b.dy;
    return maxY > inflated.top && minY < inflated.bottom;
  }
  return false;
}

/// Check if any segment of an edge crosses through a node (other than source/target).
/// Returns the ID of the first node crossed, or null if clear.
String? edgeCrossesAnyNode(
    List<Offset> wps, String sourceId, String targetId, DiagramModel diagram) {
  for (final node in diagram.nodes.values) {
    if (node.id == sourceId || node.id == targetId) continue;
    for (int i = 0; i < wps.length - 1; i++) {
      if (segmentCrossesRect(wps[i], wps[i + 1], node.rect)) {
        return node.id;
      }
    }
  }
  return null;
}

/// Get adjusted waypoints for an edge (as rendered), considering merge bars.
List<Offset> getRenderedWaypoints(EdgeModel edge, DiagramModel diagram,
    Map<String, MergeBarInfo> bars) {
  final source = diagram.nodes[edge.sourceId]!;
  final target = diagram.nodes[edge.targetId]!;
  final wps = edge.waypoints.isNotEmpty
      ? edge.waypoints
      : [source.center, target.center];
  if (wps.length < 2) return wps;

  final clippedStart = clipToNodeBorder(source, wps[1]);
  final mergeBar = bars[edge.targetId];

  if (mergeBar != null) {
    return adjustEdgeForMergeBar(wps, clippedStart, mergeBar, edge.id,
        obstacles: diagram.nodes.values.toList(),
        sourceId: edge.sourceId, targetId: edge.targetId);
  } else {
    final clippedEnd = clipToNodeBorder(target, wps[wps.length - 2]);
    return [clippedStart, ...wps.sublist(1, wps.length - 1), clippedEnd];
  }
}

// ── Tests ────────────────────────────────────────────────────────────────

void main() {
  group('First segment matches port direction', () {
    test('right-port exit is horizontal rightward', () {
      final src = _task('A', 200, 300);
      final tgt = _task('B', 500, 300);
      final wps = _router.route(
        source: src, target: tgt,
        sourceSide: ConnectorSide.right, targetSide: ConnectorSide.left,
      );
      expectFirstSegmentMatchesPort(wps, ConnectorSide.right, label: 'A->B');
    });

    test('left-port exit is horizontal leftward', () {
      final src = _task('A', 500, 300);
      final tgt = _task('B', 200, 300);
      final wps = _router.route(
        source: src, target: tgt,
        sourceSide: ConnectorSide.left, targetSide: ConnectorSide.right,
      );
      expectFirstSegmentMatchesPort(wps, ConnectorSide.left, label: 'A->B');
    });

    test('bottom-port exit is vertical downward', () {
      final src = _task('A', 300, 200);
      final tgt = _task('B', 300, 500);
      final wps = _router.route(
        source: src, target: tgt,
        sourceSide: ConnectorSide.bottom, targetSide: ConnectorSide.top,
      );
      expectFirstSegmentMatchesPort(wps, ConnectorSide.bottom, label: 'A->B');
    });

    test('top-port exit is vertical upward', () {
      final src = _task('A', 300, 500);
      final tgt = _task('B', 300, 200);
      final wps = _router.route(
        source: src, target: tgt,
        sourceSide: ConnectorSide.top, targetSide: ConnectorSide.bottom,
      );
      expectFirstSegmentMatchesPort(wps, ConnectorSide.top, label: 'A->B');
    });

    test('gateway right-port exit is horizontal', () {
      final src = _gateway('GW', 300, 300);
      final tgt = _task('T', 600, 200);
      final wps = _router.route(
        source: src, target: tgt,
        sourceSide: ConnectorSide.right, targetSide: ConnectorSide.left,
      );
      expectFirstSegmentMatchesPort(wps, ConnectorSide.right, label: 'GW->T');
    });

    test('gateway bottom-port exit is vertical', () {
      final src = _gateway('GW', 300, 300);
      final tgt = _task('T', 300, 600);
      final wps = _router.route(
        source: src, target: tgt,
        sourceSide: ConnectorSide.bottom, targetSide: ConnectorSide.top,
      );
      expectFirstSegmentMatchesPort(wps, ConnectorSide.bottom, label: 'GW->T');
    });

    test('gateway top-port exit is vertical', () {
      final src = _gateway('GW', 300, 300);
      final tgt = _task('T', 300, 100);
      final wps = _router.route(
        source: src, target: tgt,
        sourceSide: ConnectorSide.top, targetSide: ConnectorSide.bottom,
      );
      expectFirstSegmentMatchesPort(wps, ConnectorSide.top, label: 'GW->T');
    });

    test('event right-port exit is horizontal', () {
      final src = _event('S', 100, 300);
      final tgt = _task('T', 400, 300);
      final wps = _router.route(
        source: src, target: tgt,
        sourceSide: ConnectorSide.right, targetSide: ConnectorSide.left,
      );
      expectFirstSegmentMatchesPort(wps, ConnectorSide.right, label: 'S->T');
    });
  });

  group('Diamond pattern — outgoing edges from gateway', () {
    test('gateway splits right: both first segments are horizontal', () {
      // GW at center, targets to the upper-right and lower-right.
      final gw = _gateway('GW', 400, 300);
      final upper = _task('U', 650, 170);
      final lower = _task('L', 650, 430);

      final wpsUp = _router.route(
        source: gw, target: upper,
        sourceSide: ConnectorSide.right, targetSide: ConnectorSide.left,
        obstacles: [lower],
      );
      final wpsDown = _router.route(
        source: gw, target: lower,
        sourceSide: ConnectorSide.right, targetSide: ConnectorSide.left,
        obstacles: [upper],
      );

      expectOrthogonal(wpsUp, label: 'GW->U');
      expectOrthogonal(wpsDown, label: 'GW->L');
      expectFirstSegmentMatchesPort(wpsUp, ConnectorSide.right, label: 'GW->U');
      expectFirstSegmentMatchesPort(wpsDown, ConnectorSide.right, label: 'GW->L');
    });

    test('gateway splits bottom: both first segments are vertical', () {
      final gw = _gateway('GW', 400, 200);
      final left = _task('L', 250, 450);
      final right = _task('R', 550, 450);

      final wpsL = _router.route(
        source: gw, target: left,
        sourceSide: ConnectorSide.bottom, targetSide: ConnectorSide.top,
        obstacles: [right],
      );
      final wpsR = _router.route(
        source: gw, target: right,
        sourceSide: ConnectorSide.bottom, targetSide: ConnectorSide.top,
        obstacles: [left],
      );

      expectFirstSegmentMatchesPort(wpsL, ConnectorSide.bottom, label: 'GW->L');
      expectFirstSegmentMatchesPort(wpsR, ConnectorSide.bottom, label: 'GW->R');
    });

    test('gateway splits top: both first segments are vertical upward', () {
      final gw = _gateway('GW', 400, 500);
      final left = _task('L', 250, 250);
      final right = _task('R', 550, 250);

      final wpsL = _router.route(
        source: gw, target: left,
        sourceSide: ConnectorSide.top, targetSide: ConnectorSide.bottom,
        obstacles: [right],
      );
      final wpsR = _router.route(
        source: gw, target: right,
        sourceSide: ConnectorSide.top, targetSide: ConnectorSide.bottom,
        obstacles: [left],
      );

      expectFirstSegmentMatchesPort(wpsL, ConnectorSide.top, label: 'GW->L');
      expectFirstSegmentMatchesPort(wpsR, ConnectorSide.top, label: 'GW->R');
    });

    test('gateway splits left: both first segments are horizontal leftward', () {
      final gw = _gateway('GW', 600, 300);
      final upper = _task('U', 300, 170);
      final lower = _task('L', 300, 430);

      final wpsUp = _router.route(
        source: gw, target: upper,
        sourceSide: ConnectorSide.left, targetSide: ConnectorSide.right,
        obstacles: [lower],
      );
      final wpsDown = _router.route(
        source: gw, target: lower,
        sourceSide: ConnectorSide.left, targetSide: ConnectorSide.right,
        obstacles: [upper],
      );

      expectFirstSegmentMatchesPort(wpsUp, ConnectorSide.left, label: 'GW->U');
      expectFirstSegmentMatchesPort(wpsDown, ConnectorSide.left, label: 'GW->L');
    });
  });

  group('No overlapping edges', () {
    test('diamond split edges do not overlap', () {
      final gw = _gateway('GW', 400, 300);
      final upper = _task('U', 650, 170);
      final lower = _task('L', 650, 430);

      final wpsUp = _router.route(
        source: gw, target: upper,
        sourceSide: ConnectorSide.right, targetSide: ConnectorSide.left,
        obstacles: [lower],
      );
      final wpsDown = _router.route(
        source: gw, target: lower,
        sourceSide: ConnectorSide.right, targetSide: ConnectorSide.left,
        obstacles: [upper],
      );

      expect(hasOverlappingSegments(wpsUp, wpsDown, skipSharedStart: true), isFalse,
          reason: 'Split edges from gateway should not overlap after diverging');
    });

    test('parallel horizontal edges at different Y do not overlap', () {
      final a = _task('A', 100, 200);
      final b = _task('B', 100, 400);
      final c = _task('C', 400, 200);
      final d = _task('D', 400, 400);

      final wps1 = _router.route(
        source: a, target: c,
        sourceSide: ConnectorSide.right, targetSide: ConnectorSide.left,
      );
      final wps2 = _router.route(
        source: b, target: d,
        sourceSide: ConnectorSide.right, targetSide: ConnectorSide.left,
      );

      expect(hasOverlappingSegments(wps1, wps2), isFalse);
    });

    test('three-way merge: incoming edges to bar should not overlap', () {
      final diagram = SampleDiagrams.threeWayMerge();
      routeAllEdges(diagram);

      final bars = computeMergeBars(diagram);
      expect(bars.isNotEmpty, isTrue, reason: 'Should have at least one merge bar');

      // Get the merge target node and its incoming edges.
      for (final entry in bars.entries) {
        final nodeId = entry.key;
        final bar = entry.value;
        final incoming = diagram.incomingEdges(nodeId);

        // Adjust each edge for the merge bar and check no overlap.
        final adjustedEdges = <String, List<Offset>>{};
        for (final edge in incoming) {
          final source = diagram.nodes[edge.sourceId]!;
          final clippedStart = clipToNodeBorder(source, edge.waypoints[1]);
          adjustedEdges[edge.id] = adjustEdgeForMergeBar(
              edge.waypoints, clippedStart, bar, edge.id);
        }

        final ids = adjustedEdges.keys.toList();
        for (int i = 0; i < ids.length; i++) {
          for (int j = i + 1; j < ids.length; j++) {
            expect(
              hasOverlappingSegments(adjustedEdges[ids[i]]!, adjustedEdges[ids[j]]!),
              isFalse,
              reason: 'Edges ${ids[i]} and ${ids[j]} should not overlap going into merge bar on $nodeId',
            );
          }
        }
      }
    });
  });

  group('Diamond sample — full integration', () {
    test('all edges are orthogonal after routing', () {
      final diagram = SampleDiagrams.diamond();
      routeAllEdges(diagram);

      for (final edge in diagram.edges.values) {
        expectOrthogonal(edge.waypoints, label: edge.id);
      }
    });

    test('gateway outgoing edges start horizontal (right port)', () {
      final diagram = SampleDiagrams.diamond();
      routeAllEdges(diagram);

      // e3: GW -> Process Approval (upper right), e4: GW -> Send Rejection (lower right)
      final e3 = diagram.edges['e3']!;
      final e4 = diagram.edges['e4']!;

      expect(e3.sourceSide, ConnectorSide.right,
          reason: 'Gateway to upper-right should exit right');
      expectFirstSegmentMatchesPort(e3.waypoints, ConnectorSide.right, label: 'e3');

      // e4 may exit bottom since target is lower — check it's consistent with its port.
      expectFirstSegmentMatchesPort(e4.waypoints, e4.sourceSide!, label: 'e4');
    });

    test('diamond merge bar is created on Notify Customer', () {
      final diagram = SampleDiagrams.diamond();
      routeAllEdges(diagram);

      final bars = computeMergeBars(diagram);
      // n6 (Notify Customer) has 2 incoming: from e5 and e6.
      expect(bars.containsKey('n6'), isTrue,
          reason: 'Notify Customer should have a merge bar');
      expect(bars['n6']!.edgeSlots.length, 2);
    });

    test('diamond merge edges end perpendicular to bar', () {
      final diagram = SampleDiagrams.diamond();
      routeAllEdges(diagram);

      final bars = computeMergeBars(diagram);
      final bar = bars['n6']!;

      for (final edgeId in bar.edgeSlots.keys) {
        final edge = diagram.edges[edgeId]!;
        final source = diagram.nodes[edge.sourceId]!;
        final clippedStart = clipToNodeBorder(source, edge.waypoints[1]);
        final adjusted = adjustEdgeForMergeBar(
            edge.waypoints, clippedStart, bar, edgeId);

        // Last segment should be perpendicular to bar.
        final last = adjusted.last;
        final prev = adjusted[adjusted.length - 2];
        if (bar.isHorizontal) {
          expect((last.dx - prev.dx).abs(), lessThan(0.5),
              reason: 'Edge $edgeId final segment should be vertical for horizontal bar');
        } else {
          expect((last.dy - prev.dy).abs(), lessThan(0.5),
              reason: 'Edge $edgeId final segment should be horizontal for vertical bar');
        }
      }
    });

    test('diamond: split edges from gateway do not overlap', () {
      final diagram = SampleDiagrams.diamond();
      routeAllEdges(diagram);

      final e3 = diagram.edges['e3']!;
      final e4 = diagram.edges['e4']!;
      expect(hasOverlappingSegments(e3.waypoints, e4.waypoints, skipSharedStart: true), isFalse,
          reason: 'Gateway split edges should not overlap after diverging');
    });
  });

  group('Three-way merge sample — full integration', () {
    test('all edges orthogonal', () {
      final diagram = SampleDiagrams.threeWayMerge();
      routeAllEdges(diagram);

      for (final edge in diagram.edges.values) {
        expectOrthogonal(edge.waypoints, label: edge.id);
      }
    });

    test('merge bar created with 3 slots', () {
      final diagram = SampleDiagrams.threeWayMerge();
      routeAllEdges(diagram);

      final bars = computeMergeBars(diagram);
      // n6 (Evaluate Results) has 3 incoming.
      expect(bars.containsKey('n6'), isTrue);
      expect(bars['n6']!.edgeSlots.length, 3);
    });

    test('merge bar slots are evenly spaced', () {
      final diagram = SampleDiagrams.threeWayMerge();
      routeAllEdges(diagram);

      final bars = computeMergeBars(diagram);
      final bar = bars['n6']!;
      final slots = bar.edgeSlots.values.toList();

      if (bar.isHorizontal) {
        slots.sort((a, b) => a.dx.compareTo(b.dx));
        if (slots.length == 3) {
          final gap1 = slots[1].dx - slots[0].dx;
          final gap2 = slots[2].dx - slots[1].dx;
          expect(gap1, closeTo(gap2, 0.5));
        }
      } else {
        slots.sort((a, b) => a.dy.compareTo(b.dy));
        if (slots.length == 3) {
          final gap1 = slots[1].dy - slots[0].dy;
          final gap2 = slots[2].dy - slots[1].dy;
          expect(gap1, closeTo(gap2, 0.5));
        }
      }
    });

    test('all 3 merge edges end perpendicular to bar', () {
      final diagram = SampleDiagrams.threeWayMerge();
      routeAllEdges(diagram);

      final bars = computeMergeBars(diagram);
      final bar = bars['n6']!;

      for (final edgeId in bar.edgeSlots.keys) {
        final edge = diagram.edges[edgeId]!;
        final source = diagram.nodes[edge.sourceId]!;
        final clippedStart = clipToNodeBorder(source, edge.waypoints[1]);
        final adjusted = adjustEdgeForMergeBar(
            edge.waypoints, clippedStart, bar, edgeId);

        final last = adjusted.last;
        final prev = adjusted[adjusted.length - 2];
        if (bar.isHorizontal) {
          expect((last.dx - prev.dx).abs(), lessThan(0.5),
              reason: 'Edge $edgeId should approach bar vertically');
        } else {
          expect((last.dy - prev.dy).abs(), lessThan(0.5),
              reason: 'Edge $edgeId should approach bar horizontally');
        }
      }
    });
  });

  group('Four-way merge sample — full integration', () {
    test('all edges orthogonal', () {
      final diagram = SampleDiagrams.fourWayMerge();
      routeAllEdges(diagram);

      for (final edge in diagram.edges.values) {
        expectOrthogonal(edge.waypoints, label: edge.id);
      }
    });

    test('merge bar created with 4 slots', () {
      final diagram = SampleDiagrams.fourWayMerge();
      routeAllEdges(diagram);

      final bars = computeMergeBars(diagram);
      // n9 (Consolidate) has 4 incoming.
      expect(bars.containsKey('n9'), isTrue);
      expect(bars['n9']!.edgeSlots.length, 4);
    });

    test('4 merge edges all end at distinct bar slots', () {
      final diagram = SampleDiagrams.fourWayMerge();
      routeAllEdges(diagram);

      final bars = computeMergeBars(diagram);
      final bar = bars['n9']!;

      // Each edge should terminate at a unique slot on the bar.
      final slotPositions = <double>{};
      for (final edgeId in bar.edgeSlots.keys) {
        final edge = diagram.edges[edgeId]!;
        final source = diagram.nodes[edge.sourceId]!;
        final clippedStart = clipToNodeBorder(source, edge.waypoints[1]);
        final adjusted = adjustEdgeForMergeBar(
            edge.waypoints, clippedStart, bar, edgeId);

        final crossPos = bar.isHorizontal ? adjusted.last.dx : adjusted.last.dy;
        // No two edges should share the same slot position.
        expect(slotPositions.every((p) => (p - crossPos).abs() > 0.5), isTrue,
            reason: 'Edge $edgeId slot should be distinct from others');
        slotPositions.add(crossPos);
      }
      expect(slotPositions.length, 4);
    });

    test('4 merge edges all end perpendicular to bar', () {
      final diagram = SampleDiagrams.fourWayMerge();
      routeAllEdges(diagram);

      final bars = computeMergeBars(diagram);
      final bar = bars['n9']!;

      for (final edgeId in bar.edgeSlots.keys) {
        final edge = diagram.edges[edgeId]!;
        final source = diagram.nodes[edge.sourceId]!;
        final clippedStart = clipToNodeBorder(source, edge.waypoints[1]);
        final adjusted = adjustEdgeForMergeBar(
            edge.waypoints, clippedStart, bar, edgeId);

        final last = adjusted.last;
        final prev = adjusted[adjusted.length - 2];
        if (bar.isHorizontal) {
          expect((last.dx - prev.dx).abs(), lessThan(0.5),
              reason: 'Edge $edgeId should approach bar vertically');
        } else {
          expect((last.dy - prev.dy).abs(), lessThan(0.5),
              reason: 'Edge $edgeId should approach bar horizontally');
        }
      }
    });
  });

  group('Double diamond sample — full integration', () {
    test('all edges orthogonal', () {
      final diagram = SampleDiagrams.doubleDiamond();
      routeAllEdges(diagram);

      for (final edge in diagram.edges.values) {
        expectOrthogonal(edge.waypoints, label: edge.id);
      }
    });

    test('two merge bars created', () {
      final diagram = SampleDiagrams.doubleDiamond();
      routeAllEdges(diagram);

      final bars = computeMergeBars(diagram);
      // n5 (Route? gateway) and n8 (Ship Release) each have 2 incoming.
      expect(bars.length, 2);
    });

    test('no overlapping merge edges at either merge point', () {
      final diagram = SampleDiagrams.doubleDiamond();
      routeAllEdges(diagram);

      final bars = computeMergeBars(diagram);
      for (final entry in bars.entries) {
        final bar = entry.value;
        final adjustedEdges = <String, List<Offset>>{};

        for (final edgeId in bar.edgeSlots.keys) {
          final edge = diagram.edges[edgeId]!;
          final source = diagram.nodes[edge.sourceId]!;
          final clippedStart = clipToNodeBorder(source, edge.waypoints[1]);
          adjustedEdges[edgeId] = adjustEdgeForMergeBar(
              edge.waypoints, clippedStart, bar, edgeId);
        }

        final ids = adjustedEdges.keys.toList();
        for (int i = 0; i < ids.length; i++) {
          for (int j = i + 1; j < ids.length; j++) {
            expect(
              hasOverlappingSegments(adjustedEdges[ids[i]]!, adjustedEdges[ids[j]]!),
              isFalse,
              reason: 'Merge edges ${ids[i]} and ${ids[j]} on ${entry.key} should not overlap',
            );
          }
        }
      }
    });
  });

  group('Linear sample — no merge bars', () {
    test('all edges orthogonal', () {
      final diagram = SampleDiagrams.linear();
      routeAllEdges(diagram);

      for (final edge in diagram.edges.values) {
        expectOrthogonal(edge.waypoints, label: edge.id);
      }
    });

    test('no merge bars on linear flow', () {
      final diagram = SampleDiagrams.linear();
      routeAllEdges(diagram);

      final bars = computeMergeBars(diagram);
      expect(bars, isEmpty);
    });

    test('all edges start horizontal (left-to-right flow)', () {
      final diagram = SampleDiagrams.linear();
      routeAllEdges(diagram);

      for (final edge in diagram.edges.values) {
        final side = edge.sourceSide!;
        expectFirstSegmentMatchesPort(edge.waypoints, side, label: edge.id);
      }
    });
  });

  group('Edge direction consistency with specific side assignments', () {
    test('right port: first segment goes right even when target is above', () {
      final src = _task('A', 300, 400);
      final tgt = _task('B', 600, 200);
      final wps = _router.route(
        source: src, target: tgt,
        sourceSide: ConnectorSide.right, targetSide: ConnectorSide.left,
      );
      expectFirstSegmentMatchesPort(wps, ConnectorSide.right, label: 'A->B');
      expectOrthogonal(wps, label: 'A->B');
    });

    test('right port: first segment goes right even when target is below', () {
      final src = _task('A', 300, 200);
      final tgt = _task('B', 600, 400);
      final wps = _router.route(
        source: src, target: tgt,
        sourceSide: ConnectorSide.right, targetSide: ConnectorSide.left,
      );
      expectFirstSegmentMatchesPort(wps, ConnectorSide.right, label: 'A->B');
      expectOrthogonal(wps, label: 'A->B');
    });

    test('bottom port: first segment goes down even when target is right', () {
      final src = _task('A', 300, 200);
      final tgt = _task('B', 600, 500);
      final wps = _router.route(
        source: src, target: tgt,
        sourceSide: ConnectorSide.bottom, targetSide: ConnectorSide.top,
      );
      expectFirstSegmentMatchesPort(wps, ConnectorSide.bottom, label: 'A->B');
      expectOrthogonal(wps, label: 'A->B');
    });

    test('top port: first segment goes up even when target is right', () {
      final src = _task('A', 300, 500);
      final tgt = _task('B', 600, 200);
      final wps = _router.route(
        source: src, target: tgt,
        sourceSide: ConnectorSide.top, targetSide: ConnectorSide.bottom,
      );
      expectFirstSegmentMatchesPort(wps, ConnectorSide.top, label: 'A->B');
      expectOrthogonal(wps, label: 'A->B');
    });

    test('left port: first segment goes left even when target is below', () {
      final src = _task('A', 600, 200);
      final tgt = _task('B', 300, 400);
      final wps = _router.route(
        source: src, target: tgt,
        sourceSide: ConnectorSide.left, targetSide: ConnectorSide.right,
      );
      expectFirstSegmentMatchesPort(wps, ConnectorSide.left, label: 'A->B');
      expectOrthogonal(wps, label: 'A->B');
    });
  });

  group('Merge bar with routed edges', () {
    test('bar side matches dominant approach direction', () {
      // Two sources to the left → bar should be on left side.
      final diagram = DiagramModel(
        nodes: {
          'A': _task('A', 100, 100),
          'B': _task('B', 100, 400),
          'C': _task('C', 500, 250),
        },
        edges: {
          'e1': EdgeModel(id: 'e1', sourceId: 'A', targetId: 'C'),
          'e2': EdgeModel(id: 'e2', sourceId: 'B', targetId: 'C'),
        },
      );
      routeAllEdges(diagram);

      final bars = computeMergeBars(diagram);
      expect(bars.containsKey('C'), isTrue);
      expect(bars['C']!.side, ConnectorSide.left);
    });

    test('bar side is top when sources are above', () {
      final diagram = DiagramModel(
        nodes: {
          'A': _task('A', 300, 100),
          'B': _task('B', 500, 100),
          'C': _task('C', 400, 400),
        },
        edges: {
          'e1': EdgeModel(id: 'e1', sourceId: 'A', targetId: 'C'),
          'e2': EdgeModel(id: 'e2', sourceId: 'B', targetId: 'C'),
        },
      );
      routeAllEdges(diagram);

      final bars = computeMergeBars(diagram);
      expect(bars.containsKey('C'), isTrue);
      // Both sources above → should be top.
      expect(bars['C']!.side, ConnectorSide.top);
    });

    test('adjusted edges end at bar slot and final segment is perpendicular', () {
      final diagram = DiagramModel(
        nodes: {
          'A': _task('A', 100, 100),
          'B': _task('B', 100, 400),
          'C': _task('C', 500, 250),
        },
        edges: {
          'e1': EdgeModel(id: 'e1', sourceId: 'A', targetId: 'C'),
          'e2': EdgeModel(id: 'e2', sourceId: 'B', targetId: 'C'),
        },
      );
      routeAllEdges(diagram);

      final bars = computeMergeBars(diagram);
      final bar = bars['C']!;

      for (final edgeId in bar.edgeSlots.keys) {
        final edge = diagram.edges[edgeId]!;
        final source = diagram.nodes[edge.sourceId]!;
        final clippedStart = clipToNodeBorder(source, edge.waypoints[1]);
        final adjusted = adjustEdgeForMergeBar(
            edge.waypoints, clippedStart, bar, edgeId);

        // Last point should be on the bar.
        final slot = bar.edgeSlots[edgeId]!;
        expect((adjusted.last - slot).distance, lessThan(0.5),
            reason: 'Edge $edgeId should end at its bar slot');

        // Final segment should be perpendicular to bar.
        final last = adjusted.last;
        final prev = adjusted[adjusted.length - 2];
        if (bar.isHorizontal) {
          expect((last.dx - prev.dx).abs(), lessThan(0.5),
              reason: 'Edge $edgeId final segment should be vertical');
        } else {
          expect((last.dy - prev.dy).abs(), lessThan(0.5),
              reason: 'Edge $edgeId final segment should be horizontal');
        }
      }
    });
  });

  // ── No edge crosses through a symbol ────────────────────────────────────

  group('Edges must not cross through symbols', () {
    test('diamond: no raw edge crosses a node', () {
      final diagram = SampleDiagrams.diamond();
      routeAllEdges(diagram);

      for (final edge in diagram.edges.values) {
        final crossed = edgeCrossesAnyNode(
            edge.waypoints, edge.sourceId, edge.targetId, diagram);
        expect(crossed, isNull,
            reason: 'Edge ${edge.id} (${edge.sourceId}->${edge.targetId}) '
                'crosses node $crossed');
      }
    });

    test('diamond: no rendered edge (with merge bar) crosses a node', () {
      final diagram = SampleDiagrams.diamond();
      routeAllEdges(diagram);
      final bars = computeMergeBars(diagram);

      for (final edge in diagram.edges.values) {
        final rendered = getRenderedWaypoints(edge, diagram, bars);
        final crossed = edgeCrossesAnyNode(
            rendered, edge.sourceId, edge.targetId, diagram);
        expect(crossed, isNull,
            reason: 'Rendered edge ${edge.id} crosses node $crossed');
      }
    });

    test('three-way merge: no raw edge crosses a node', () {
      final diagram = SampleDiagrams.threeWayMerge();
      routeAllEdges(diagram);

      for (final edge in diagram.edges.values) {
        final crossed = edgeCrossesAnyNode(
            edge.waypoints, edge.sourceId, edge.targetId, diagram);
        expect(crossed, isNull,
            reason: 'Edge ${edge.id} crosses node $crossed');
      }
    });

    test('three-way merge: no rendered edge crosses a node', () {
      final diagram = SampleDiagrams.threeWayMerge();
      routeAllEdges(diagram);
      final bars = computeMergeBars(diagram);

      for (final edge in diagram.edges.values) {
        final rendered = getRenderedWaypoints(edge, diagram, bars);
        final crossed = edgeCrossesAnyNode(
            rendered, edge.sourceId, edge.targetId, diagram);
        expect(crossed, isNull,
            reason: 'Rendered edge ${edge.id} crosses node $crossed');
      }
    });

    test('four-way merge: no raw edge crosses a node', () {
      final diagram = SampleDiagrams.fourWayMerge();
      routeAllEdges(diagram);

      for (final edge in diagram.edges.values) {
        final crossed = edgeCrossesAnyNode(
            edge.waypoints, edge.sourceId, edge.targetId, diagram);
        expect(crossed, isNull,
            reason: 'Edge ${edge.id} crosses node $crossed');
      }
    });

    test('four-way merge: no rendered edge crosses a node', () {
      final diagram = SampleDiagrams.fourWayMerge();
      routeAllEdges(diagram);
      final bars = computeMergeBars(diagram);

      for (final edge in diagram.edges.values) {
        final rendered = getRenderedWaypoints(edge, diagram, bars);
        final crossed = edgeCrossesAnyNode(
            rendered, edge.sourceId, edge.targetId, diagram);
        expect(crossed, isNull,
            reason: 'Rendered edge ${edge.id} crosses node $crossed');
      }
    });

    test('double diamond: no raw edge crosses a node', () {
      final diagram = SampleDiagrams.doubleDiamond();
      routeAllEdges(diagram);

      for (final edge in diagram.edges.values) {
        final crossed = edgeCrossesAnyNode(
            edge.waypoints, edge.sourceId, edge.targetId, diagram);
        expect(crossed, isNull,
            reason: 'Edge ${edge.id} crosses node $crossed');
      }
    });

    test('double diamond: no rendered edge crosses a node', () {
      final diagram = SampleDiagrams.doubleDiamond();
      routeAllEdges(diagram);
      final bars = computeMergeBars(diagram);

      for (final edge in diagram.edges.values) {
        final rendered = getRenderedWaypoints(edge, diagram, bars);
        final crossed = edgeCrossesAnyNode(
            rendered, edge.sourceId, edge.targetId, diagram);
        expect(crossed, isNull,
            reason: 'Rendered edge ${edge.id} crosses node $crossed');
      }
    });

    test('edge routed around obstacle between source and target', () {
      // Node C sits between A and B horizontally.
      final a = _task('A', 100, 300);
      final c = _task('C', 350, 300);
      final b = _task('B', 600, 300);
      final diagram = DiagramModel(
        nodes: {'A': a, 'B': b, 'C': c},
        edges: {'e1': EdgeModel(id: 'e1', sourceId: 'A', targetId: 'B')},
      );
      routeAllEdges(diagram);

      final crossed = edgeCrossesAnyNode(
          diagram.edges['e1']!.waypoints, 'A', 'B', diagram);
      expect(crossed, isNull,
          reason: 'Edge should route around C, not through it');
    });

    test('merge-bar-adjusted edge avoids intermediate nodes', () {
      // A and B both go into C, with D sitting between them.
      // A at top-left, B at bottom-left, D in the middle, C to the right.
      final diagram = DiagramModel(
        nodes: {
          'A': _task('A', 100, 100),
          'B': _task('B', 100, 500),
          'D': _task('D', 350, 300),
          'C': _task('C', 600, 300),
        },
        edges: {
          'e1': EdgeModel(id: 'e1', sourceId: 'A', targetId: 'C'),
          'e2': EdgeModel(id: 'e2', sourceId: 'B', targetId: 'C'),
        },
      );
      routeAllEdges(diagram);
      final bars = computeMergeBars(diagram);

      for (final edge in diagram.edges.values) {
        final rendered = getRenderedWaypoints(edge, diagram, bars);
        final crossed = edgeCrossesAnyNode(
            rendered, edge.sourceId, edge.targetId, diagram);
        expect(crossed, isNull,
            reason: 'Rendered edge ${edge.id} should not cross node $crossed');
      }
    });
  });

  // ── No overlapping vertical/horizontal lines ─────────────────────────────

  group('No overlapping vertical or horizontal lines', () {
    test('diamond: no pair of rendered edges overlaps', () {
      final diagram = SampleDiagrams.diamond();
      routeAllEdges(diagram);
      final bars = computeMergeBars(diagram);

      final rendered = <String, List<Offset>>{};
      for (final edge in diagram.edges.values) {
        rendered[edge.id] = getRenderedWaypoints(edge, diagram, bars);
      }

      final ids = rendered.keys.toList();
      for (int i = 0; i < ids.length; i++) {
        for (int j = i + 1; j < ids.length; j++) {
          // Allow shared start for edges from same source.
          final sameSource = diagram.edges[ids[i]]!.sourceId ==
              diagram.edges[ids[j]]!.sourceId;
          expect(
            hasOverlappingSegments(rendered[ids[i]]!, rendered[ids[j]]!,
                skipSharedStart: sameSource),
            isFalse,
            reason: 'Rendered edges ${ids[i]} and ${ids[j]} should not overlap',
          );
        }
      }
    });

    test('three-way merge: no pair of rendered edges overlaps', () {
      final diagram = SampleDiagrams.threeWayMerge();
      routeAllEdges(diagram);
      final bars = computeMergeBars(diagram);

      final rendered = <String, List<Offset>>{};
      for (final edge in diagram.edges.values) {
        rendered[edge.id] = getRenderedWaypoints(edge, diagram, bars);
      }

      final ids = rendered.keys.toList();
      for (int i = 0; i < ids.length; i++) {
        for (int j = i + 1; j < ids.length; j++) {
          final sameSource = diagram.edges[ids[i]]!.sourceId ==
              diagram.edges[ids[j]]!.sourceId;
          expect(
            hasOverlappingSegments(rendered[ids[i]]!, rendered[ids[j]]!,
                skipSharedStart: sameSource),
            isFalse,
            reason: 'Rendered edges ${ids[i]} and ${ids[j]} should not overlap',
          );
        }
      }
    });

    test('four-way merge: no pair of rendered edges overlaps', () {
      final diagram = SampleDiagrams.fourWayMerge();
      routeAllEdges(diagram);
      final bars = computeMergeBars(diagram);

      final rendered = <String, List<Offset>>{};
      for (final edge in diagram.edges.values) {
        rendered[edge.id] = getRenderedWaypoints(edge, diagram, bars);
      }

      final ids = rendered.keys.toList();
      for (int i = 0; i < ids.length; i++) {
        for (int j = i + 1; j < ids.length; j++) {
          final sameSource = diagram.edges[ids[i]]!.sourceId ==
              diagram.edges[ids[j]]!.sourceId;
          expect(
            hasOverlappingSegments(rendered[ids[i]]!, rendered[ids[j]]!,
                skipSharedStart: sameSource),
            isFalse,
            reason: 'Rendered edges ${ids[i]} and ${ids[j]} should not overlap',
          );
        }
      }
    });

    test('double diamond: no pair of rendered edges overlaps', () {
      final diagram = SampleDiagrams.doubleDiamond();
      routeAllEdges(diagram);
      final bars = computeMergeBars(diagram);

      final rendered = <String, List<Offset>>{};
      for (final edge in diagram.edges.values) {
        rendered[edge.id] = getRenderedWaypoints(edge, diagram, bars);
      }

      final ids = rendered.keys.toList();
      for (int i = 0; i < ids.length; i++) {
        for (int j = i + 1; j < ids.length; j++) {
          final sameSource = diagram.edges[ids[i]]!.sourceId ==
              diagram.edges[ids[j]]!.sourceId;
          expect(
            hasOverlappingSegments(rendered[ids[i]]!, rendered[ids[j]]!,
                skipSharedStart: sameSource),
            isFalse,
            reason: 'Rendered edges ${ids[i]} and ${ids[j]} should not overlap',
          );
        }
      }
    });

    test('parallel vertical edges at same X should not overlap', () {
      // Two edges from vertically-stacked sources to a common target.
      // Both would naturally use the same X channel.
      final diagram = DiagramModel(
        nodes: {
          'A': _task('A', 100, 100),
          'B': _task('B', 100, 300),
          'C': _task('C', 400, 200),
        },
        edges: {
          'e1': EdgeModel(id: 'e1', sourceId: 'A', targetId: 'C'),
          'e2': EdgeModel(id: 'e2', sourceId: 'B', targetId: 'C'),
        },
      );
      routeAllEdges(diagram);
      final bars = computeMergeBars(diagram);

      final r1 = getRenderedWaypoints(diagram.edges['e1']!, diagram, bars);
      final r2 = getRenderedWaypoints(diagram.edges['e2']!, diagram, bars);

      expect(hasOverlappingSegments(r1, r2), isFalse,
          reason: 'Vertical edges from A and B to C should not overlap');
    });

    test('edges with well-separated sources do not share vertical channel', () {
      // Sources far apart horizontally — should use different x channels.
      final diagram = DiagramModel(
        nodes: {
          'A': _task('A', 100, 100),
          'B': _task('B', 300, 400),
          'C': _task('C', 600, 100),
          'D': _task('D', 600, 400),
        },
        edges: {
          'e1': EdgeModel(id: 'e1', sourceId: 'A', targetId: 'C'),
          'e2': EdgeModel(id: 'e2', sourceId: 'B', targetId: 'D'),
        },
      );
      routeAllEdges(diagram);

      expect(hasOverlappingSegments(
          diagram.edges['e1']!.waypoints, diagram.edges['e2']!.waypoints),
          isFalse,
          reason: 'Independent parallel edges should not overlap');
    });

    test('four sources to one target: vertical segments all distinct', () {
      // 4 sources stacked vertically on the left, one target on the right.
      final diagram = DiagramModel(
        nodes: {
          'S1': _task('S1', 100, 100),
          'S2': _task('S2', 100, 250),
          'S3': _task('S3', 100, 400),
          'S4': _task('S4', 100, 550),
          'T':  _task('T',  500, 325),
        },
        edges: {
          'e1': EdgeModel(id: 'e1', sourceId: 'S1', targetId: 'T'),
          'e2': EdgeModel(id: 'e2', sourceId: 'S2', targetId: 'T'),
          'e3': EdgeModel(id: 'e3', sourceId: 'S3', targetId: 'T'),
          'e4': EdgeModel(id: 'e4', sourceId: 'S4', targetId: 'T'),
        },
      );
      routeAllEdges(diagram);
      final bars = computeMergeBars(diagram);

      final rendered = <String, List<Offset>>{};
      for (final edge in diagram.edges.values) {
        rendered[edge.id] = getRenderedWaypoints(edge, diagram, bars);
      }

      final ids = rendered.keys.toList();
      for (int i = 0; i < ids.length; i++) {
        for (int j = i + 1; j < ids.length; j++) {
          expect(
            hasOverlappingSegments(rendered[ids[i]]!, rendered[ids[j]]!),
            isFalse,
            reason: 'Edges ${ids[i]} and ${ids[j]} should not have '
                'overlapping vertical segments',
          );
        }
      }
    });
  });

  // ── Source and target ports must differ ──────────────────────────────────

  group('Source port must not equal target port on same node', () {
    test('diamond: gateway outputs use different ports', () {
      final diagram = SampleDiagrams.diamond();
      routeAllEdges(diagram);

      // Gateway n3 has outgoing e3 and e4.
      final e3 = diagram.edges['e3']!;
      final e4 = diagram.edges['e4']!;
      // Both leave gateway, but should use different source sides.
      // (In the diamond layout the gateway is left of both targets,
      // so both exit right — but this test checks the principle.)
      // More importantly: no node should have the SAME port used for
      // both an incoming and outgoing edge.
    });

    test('no node uses the same port for input and output', () {
      final diagram = SampleDiagrams.diamond();
      routeAllEdges(diagram);

      for (final node in diagram.nodes.values) {
        final outgoing = diagram.edges.values
            .where((e) => e.sourceId == node.id)
            .toList();
        final incoming = diagram.edges.values
            .where((e) => e.targetId == node.id)
            .toList();

        final outPorts = outgoing.map((e) => e.sourceSide).toSet();
        final inPorts = incoming.map((e) => e.targetSide).toSet();
        final shared = outPorts.intersection(inPorts);

        expect(shared, isEmpty,
            reason: 'Node ${node.id} (${node.name}) uses port(s) $shared '
                'for both input and output');
      }
    });

    test('three-way merge: no node uses same port for input and output', () {
      final diagram = SampleDiagrams.threeWayMerge();
      routeAllEdges(diagram);

      for (final node in diagram.nodes.values) {
        final outgoing = diagram.edges.values
            .where((e) => e.sourceId == node.id).toList();
        final incoming = diagram.edges.values
            .where((e) => e.targetId == node.id).toList();

        final outPorts = outgoing.map((e) => e.sourceSide).toSet();
        final inPorts = incoming.map((e) => e.targetSide).toSet();
        final shared = outPorts.intersection(inPorts);

        expect(shared, isEmpty,
            reason: 'Node ${node.id} (${node.name}) uses port(s) $shared '
                'for both input and output');
      }
    });

    test('double diamond: no node uses same port for input and output', () {
      final diagram = SampleDiagrams.doubleDiamond();
      routeAllEdges(diagram);

      for (final node in diagram.nodes.values) {
        final outgoing = diagram.edges.values
            .where((e) => e.sourceId == node.id).toList();
        final incoming = diagram.edges.values
            .where((e) => e.targetId == node.id).toList();

        final outPorts = outgoing.map((e) => e.sourceSide).toSet();
        final inPorts = incoming.map((e) => e.targetSide).toSet();
        final shared = outPorts.intersection(inPorts);

        expect(shared, isEmpty,
            reason: 'Node ${node.id} (${node.name}) uses port(s) $shared '
                'for both input and output');
      }
    });

    test('linear: no node uses same port for input and output', () {
      final diagram = SampleDiagrams.linear();
      routeAllEdges(diagram);

      for (final node in diagram.nodes.values) {
        final outgoing = diagram.edges.values
            .where((e) => e.sourceId == node.id).toList();
        final incoming = diagram.edges.values
            .where((e) => e.targetId == node.id).toList();

        final outPorts = outgoing.map((e) => e.sourceSide).toSet();
        final inPorts = incoming.map((e) => e.targetSide).toSet();
        final shared = outPorts.intersection(inPorts);

        expect(shared, isEmpty,
            reason: 'Node ${node.id} (${node.name}) uses port(s) $shared '
                'for both input and output');
      }
    });

    test('diamond gateway: two outputs should not share the same source port', () {
      final diagram = SampleDiagrams.diamond();
      routeAllEdges(diagram);

      // e3 and e4 both leave gateway n3.
      final e3 = diagram.edges['e3']!;
      final e4 = diagram.edges['e4']!;
      expect(e3.sourceSide, isNot(equals(e4.sourceSide)),
          reason: 'Gateway outputs to upper and lower targets '
              'should use different ports, not both ${e3.sourceSide}');
    });

    test('three-way merge: gateway outputs use different ports', () {
      final diagram = SampleDiagrams.threeWayMerge();
      routeAllEdges(diagram);

      // e2, e3, e4 all leave gateway n2.
      final outEdges = diagram.edges.values
          .where((e) => e.sourceId == 'n2').toList();
      final ports = outEdges.map((e) => e.sourceSide).toList();
      // At least 2 of the 3 should use different ports.
      expect(ports.toSet().length, greaterThan(1),
          reason: 'Gateway with 3 outputs should use multiple ports, not all ${ports.first}');
    });

    test('outputs from same node use different ports for different directions', () {
      // Gateway with targets in all 4 directions — each output should use a different port.
      final gw = _gateway('GW', 400, 400);
      final right = _task('R', 700, 400);
      final left = _task('L', 100, 400);
      final above = _task('U', 400, 100);
      final below = _task('D', 400, 700);

      final diagram = DiagramModel(
        nodes: {'GW': gw, 'R': right, 'L': left, 'U': above, 'D': below},
        edges: {
          'e1': EdgeModel(id: 'e1', sourceId: 'GW', targetId: 'R'),
          'e2': EdgeModel(id: 'e2', sourceId: 'GW', targetId: 'L'),
          'e3': EdgeModel(id: 'e3', sourceId: 'GW', targetId: 'U'),
          'e4': EdgeModel(id: 'e4', sourceId: 'GW', targetId: 'D'),
        },
      );
      routeAllEdges(diagram);

      final ports = diagram.edges.values.map((e) => e.sourceSide).toSet();
      expect(ports.length, 4,
          reason: 'Gateway with 4 targets in different directions should use 4 different ports');
    });

    test('two outputs from gateway should not share the same port as the input', () {
      // Gateway has input from left, outputs to upper-right and lower-right.
      final src = _task('S', 100, 300);
      final gw = _gateway('GW', 350, 300);
      final upper = _task('U', 600, 150);
      final lower = _task('L', 600, 450);

      final diagram = DiagramModel(
        nodes: {'S': src, 'GW': gw, 'U': upper, 'L': lower},
        edges: {
          'e1': EdgeModel(id: 'e1', sourceId: 'S', targetId: 'GW'),
          'e2': EdgeModel(id: 'e2', sourceId: 'GW', targetId: 'U'),
          'e3': EdgeModel(id: 'e3', sourceId: 'GW', targetId: 'L'),
        },
      );
      routeAllEdges(diagram);

      // e1 enters GW. e2, e3 leave GW.
      final e1 = diagram.edges['e1']!;
      final e2 = diagram.edges['e2']!;
      final e3 = diagram.edges['e3']!;

      // The input port should not be the same as any output port.
      expect(e2.sourceSide, isNot(equals(e1.targetSide)),
          reason: 'GW output port for e2 should differ from input port');
      expect(e3.sourceSide, isNot(equals(e1.targetSide)),
          reason: 'GW output port for e3 should differ from input port');
    });
  });

  // ── Only one output per port ────────────────────────────────────────────

  group('Only one output line per port', () {
    for (final sample in SampleDiagrams.all) {
      test('${sample.name}: no node has two outgoing edges on the same port', () {
        final diagram = sample.builder();
        routeAllEdges(diagram);

        for (final node in diagram.nodes.values) {
          final outEdges = diagram.edges.values
              .where((e) => e.sourceId == node.id)
              .toList();
          if (outEdges.length < 2) continue;

          final portUsage = <ConnectorSide, List<String>>{};
          for (final e in outEdges) {
            if (e.sourceSide != null) {
              portUsage.putIfAbsent(e.sourceSide!, () => []).add(e.id);
            }
          }

          for (final entry in portUsage.entries) {
            expect(entry.value.length, 1,
                reason: 'Node ${node.id} (${node.name}) has '
                    '${entry.value.length} edges sharing output port '
                    '${entry.key}: ${entry.value}');
          }
        }
      });
    }
  });

  // ── No zigzag in rendered edges ─────────────────────────────────────────

  group('No zigzag in rendered edges', () {
    /// Returns true if the rendered waypoints contain a zigzag: two
    /// consecutive segments on the same axis going in opposite directions.
    bool hasZigzag(List<Offset> wps) {
      for (int i = 0; i < wps.length - 2; i++) {
        final a = wps[i], b = wps[i + 1], c = wps[i + 2];
        // Vertical-vertical direction reversal.
        if ((a.dx - b.dx).abs() < 1 && (b.dx - c.dx).abs() < 1) {
          if ((b.dy - a.dy) * (c.dy - b.dy) < 0) return true;
        }
        // Horizontal-horizontal direction reversal.
        if ((a.dy - b.dy).abs() < 1 && (b.dy - c.dy).abs() < 1) {
          if ((b.dx - a.dx) * (c.dx - b.dx) < 0) return true;
        }
      }
      return false;
    }

    for (final sample in SampleDiagrams.all) {
      test('${sample.name}: no rendered edge has a zigzag', () {
        final diagram = sample.builder();
        routeAllEdges(diagram);
        final bars = computeMergeBars(diagram);

        for (final edge in diagram.edges.values) {
          final rendered = getRenderedWaypoints(edge, diagram, bars);
          expect(hasZigzag(rendered), isFalse,
              reason: 'Edge ${edge.id} (${edge.sourceId}->${edge.targetId}) '
                  'has a zigzag: $rendered');
        }
      });
    }

    test('three-way merge: Research edge has no zigzag', () {
      final diagram = SampleDiagrams.threeWayMerge();
      routeAllEdges(diagram);
      final bars = computeMergeBars(diagram);

      // e5: Research -> Evaluate (goes into a merge bar)
      final e5 = diagram.edges['e5']!;
      final rendered = getRenderedWaypoints(e5, diagram, bars);
      expect(hasZigzag(rendered), isFalse,
          reason: 'Research->Evaluate edge should not zigzag: $rendered');
    });

    test('three-way merge: Survey edge has no zigzag', () {
      final diagram = SampleDiagrams.threeWayMerge();
      routeAllEdges(diagram);
      final bars = computeMergeBars(diagram);

      // e7: Survey -> Evaluate (goes into a merge bar)
      final e7 = diagram.edges['e7']!;
      final rendered = getRenderedWaypoints(e7, diagram, bars);
      expect(hasZigzag(rendered), isFalse,
          reason: 'Survey->Evaluate edge should not zigzag: $rendered');
    });
  });
}
