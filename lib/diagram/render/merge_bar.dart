import 'dart:math';
import 'dart:ui';
import '../model/diagram_model.dart';
import '../edit/hit_test.dart';

/// Constants for merge bar layout.
const double mergeBarOffset = 25.0;

/// Info about a merge bar for a node with multiple incoming edges.
class MergeBarInfo {
  final ConnectorSide side;
  final double barPos;       // position along the incoming axis
  final double minCross;     // bar span start (perpendicular axis)
  final double maxCross;     // bar span end (perpendicular axis)
  final Offset connectorNodePoint; // where connector meets the node border
  final Offset nodeCenter;
  final bool isHorizontal;   // bar is horizontal (top/bottom incoming)
  final Map<String, Offset> edgeSlots; // edge id -> point on the bar

  const MergeBarInfo({
    required this.side,
    required this.barPos,
    required this.minCross,
    required this.maxCross,
    required this.connectorNodePoint,
    required this.nodeCenter,
    required this.isHorizontal,
    required this.edgeSlots,
  });
}

/// Computes merge bar info for all nodes with 2+ incoming edges.
Map<String, MergeBarInfo> computeMergeBars(DiagramModel diagram) {
  final Map<String, MergeBarInfo> bars = {};

  for (final node in diagram.nodes.values) {
    final incoming = diagram.incomingEdges(node.id);
    if (incoming.length < 2) continue;

    // Determine the incoming side from the last segment of each edge.
    final sideCounts = <ConnectorSide, int>{};

    for (final edge in incoming) {
      final wps = edge.waypoints.isNotEmpty
          ? edge.waypoints
          : [diagram.nodes[edge.sourceId]?.center ?? Offset.zero, node.center];
      if (wps.length < 2) continue;

      final side = inferSide(node, wps[wps.length - 2]);
      sideCounts[side] = (sideCounts[side] ?? 0) + 1;
    }

    // Pick the most common incoming side.
    ConnectorSide barSide = ConnectorSide.top;
    int maxCount = 0;
    for (final entry in sideCounts.entries) {
      if (entry.value > maxCount) {
        maxCount = entry.value;
        barSide = entry.key;
      }
    }

    final isHorizontal = barSide == ConnectorSide.top || barSide == ConnectorSide.bottom;
    final nodeCenter = node.center;

    // Bar position along the incoming axis.
    double barPos;
    switch (barSide) {
      case ConnectorSide.top:
        barPos = node.rect.top - mergeBarOffset;
        break;
      case ConnectorSide.bottom:
        barPos = node.rect.bottom + mergeBarOffset;
        break;
      case ConnectorSide.left:
        barPos = node.rect.left - mergeBarOffset;
        break;
      case ConnectorSide.right:
        barPos = node.rect.right + mergeBarOffset;
        break;
    }

    // Bar width = half the node's cross-axis dimension, centered on node.
    final halfBar = isHorizontal
        ? node.rect.width / 4
        : node.rect.height / 4;
    final crossCenter = isHorizontal ? nodeCenter.dx : nodeCenter.dy;
    final minCross = crossCenter - halfBar;
    final maxCross = crossCenter + halfBar;

    // Sort incoming edges by their approach cross-axis position so left
    // edges get left slots, right edges get right slots (no crossing).
    final sorted = List<EdgeModel>.from(incoming);
    sorted.sort((a, b) {
      final aWps = a.waypoints.isNotEmpty
          ? a.waypoints
          : [diagram.nodes[a.sourceId]?.center ?? Offset.zero, node.center];
      final bWps = b.waypoints.isNotEmpty
          ? b.waypoints
          : [diagram.nodes[b.sourceId]?.center ?? Offset.zero, node.center];
      final aCross = isHorizontal ? aWps[aWps.length - 2].dx : aWps[aWps.length - 2].dy;
      final bCross = isHorizontal ? bWps[bWps.length - 2].dx : bWps[bWps.length - 2].dy;
      return aCross.compareTo(bCross);
    });

    // Assign evenly-spaced slot positions on the bar.
    final n = sorted.length;
    final edgeSlots = <String, Offset>{};
    for (int i = 0; i < n; i++) {
      final t = (i + 0.5) / n;
      final crossPos = minCross + t * (maxCross - minCross);
      edgeSlots[sorted[i].id] = isHorizontal
          ? Offset(crossPos, barPos)
          : Offset(barPos, crossPos);
    }

    // Connector point: where the bar connects to the node.
    final connectorNodePoint = clipToNodeBorder(node, isHorizontal
        ? Offset(nodeCenter.dx, barPos)
        : Offset(barPos, nodeCenter.dy));

    bars[node.id] = MergeBarInfo(
      side: barSide,
      barPos: barPos,
      minCross: minCross,
      maxCross: maxCross,
      connectorNodePoint: connectorNodePoint,
      nodeCenter: nodeCenter,
      isHorizontal: isHorizontal,
      edgeSlots: edgeSlots,
    );
  }

  return bars;
}

/// Infer which side of a node an approaching point comes from.
ConnectorSide inferSide(NodeModel node, Offset approach) {
  final c = node.center;
  final dx = approach.dx - c.dx;
  final dy = approach.dy - c.dy;
  if (dx.abs() > dy.abs()) {
    return dx > 0 ? ConnectorSide.right : ConnectorSide.left;
  } else {
    return dy > 0 ? ConnectorSide.bottom : ConnectorSide.top;
  }
}

/// Returns true if a waypoint has crossed past the merge bar toward the node.
bool isPastBar(Offset wp, MergeBarInfo bar) {
  switch (bar.side) {
    case ConnectorSide.top:
      return wp.dy <= bar.barPos;
    case ConnectorSide.bottom:
      return wp.dy >= bar.barPos;
    case ConnectorSide.left:
      return wp.dx <= bar.barPos;
    case ConnectorSide.right:
      return wp.dx >= bar.barPos;
  }
}

/// Adjusts edge waypoints for a merge bar target: trims past-bar waypoints,
/// adds a perpendicular bend to the assigned slot.
List<Offset> adjustEdgeForMergeBar(
    List<Offset> rawWps, Offset clippedStart, MergeBarInfo bar, String edgeId) {
  final slotPoint = bar.edgeSlots[edgeId]!;

  // Build waypoints, trimming any that extend past the bar.
  final result = <Offset>[clippedStart];
  final inner = rawWps.sublist(1, rawWps.length - 1);
  for (final wp in inner) {
    if (!isPastBar(wp, bar)) {
      result.add(wp);
    }
  }

  // Add perpendicular approach: bend then slot.
  final prev = result.last;
  final bendPoint = bar.isHorizontal
      ? Offset(slotPoint.dx, prev.dy)
      : Offset(prev.dx, slotPoint.dy);

  // Only add bend if it creates a meaningful segment.
  if ((bendPoint - prev).distance > 1.0 && (bendPoint - slotPoint).distance > 1.0) {
    result.add(bendPoint);
  }
  result.add(slotPoint);
  return result;
}

/// Clips a point to the border of a node shape.
Offset clipToNodeBorder(NodeModel node, Offset other) {
  final c = node.center;
  final dx = other.dx - c.dx;
  final dy = other.dy - c.dy;

  if (node.type == NodeType.startEvent || node.type == NodeType.endEvent) {
    final r = node.rect.width / 2;
    final dist = sqrt(dx * dx + dy * dy);
    if (dist == 0) return c;
    return Offset(c.dx + dx / dist * r, c.dy + dy / dist * r);
  }

  if (node.type == NodeType.exclusiveGateway) {
    final hw = node.rect.width / 2;
    final hh = node.rect.height / 2;
    if (dx == 0 && dy == 0) return c;
    final adx = dx.abs();
    final ady = dy.abs();
    final scale = 1.0 / (adx / hw + ady / hh);
    return Offset(c.dx + dx * scale, c.dy + dy * scale);
  }

  // Rectangle clipping for tasks.
  final hw = node.rect.width / 2;
  final hh = node.rect.height / 2;
  if (dx == 0 && dy == 0) return c;
  final scaleX = dx != 0 ? (hw / dx.abs()) : double.infinity;
  final scaleY = dy != 0 ? (hh / dy.abs()) : double.infinity;
  final scale = min(scaleX, scaleY);
  return Offset(c.dx + dx * scale, c.dy + dy * scale);
}
