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

    // Skip merge bar when 3+ incoming edges but no side has at least 2 —
    // edges approach from too many different directions for a single bar.
    // For exactly 2 incoming edges, always show a merge bar.
    if (maxCount < 2 && incoming.length > 2) {
      continue;
    }

    // When no side has a clear majority (e.g. 2 edges from different sides),
    // pick the side facing the average source direction for best visuals.
    if (maxCount < 2) {
      double avgDx = 0, avgDy = 0;
      for (final edge in incoming) {
        final source = diagram.nodes[edge.sourceId];
        if (source != null) {
          avgDx += source.center.dx - node.center.dx;
          avgDy += source.center.dy - node.center.dy;
        }
      }
      barSide = inferSide(node, Offset(node.center.dx + avgDx, node.center.dy + avgDy));
    }

    final isHorizontal = barSide == ConnectorSide.top || barSide == ConnectorSide.bottom ||
        barSide == ConnectorSide.topRight || barSide == ConnectorSide.topLeft ||
        barSide == ConnectorSide.bottomRight || barSide == ConnectorSide.bottomLeft;
    final nodeCenter = node.center;

    // Bar position along the incoming axis (only cardinal sides produce bars).
    double barPos;
    switch (barSide) {
      case ConnectorSide.top:
      case ConnectorSide.topRight:
      case ConnectorSide.topLeft:
        barPos = node.rect.top - mergeBarOffset;
        break;
      case ConnectorSide.bottom:
      case ConnectorSide.bottomRight:
      case ConnectorSide.bottomLeft:
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
///
/// "Past" means the waypoint is between the bar and the node (or inside the
/// node).  For a left-side bar at x = 805, the node is to the right, so
/// past means x > 805.
bool isPastBar(Offset wp, MergeBarInfo bar) {
  switch (bar.side) {
    case ConnectorSide.top:
    case ConnectorSide.topRight:
    case ConnectorSide.topLeft:
      return wp.dy > bar.barPos;    // bar is above node; past = below bar
    case ConnectorSide.bottom:
    case ConnectorSide.bottomRight:
    case ConnectorSide.bottomLeft:
      return wp.dy < bar.barPos;    // bar is below node; past = above bar
    case ConnectorSide.left:
      return wp.dx > bar.barPos;    // bar is left of node; past = right of bar
    case ConnectorSide.right:
      return wp.dx < bar.barPos;    // bar is right of node; past = left of bar
  }
}

/// Adjusts edge waypoints for a merge bar target.
///
/// Tries a perpendicular bend approach first (best aesthetics). If that
/// would cross any [obstacles], falls back to clipping at the bar line
/// (preserves the router's obstacle-avoidance path).
List<Offset> adjustEdgeForMergeBar(
    List<Offset> rawWps, Offset clippedStart, MergeBarInfo bar, String edgeId,
    {List<NodeModel> obstacles = const [], String sourceId = '', String targetId = ''}) {
  final slotPoint = bar.edgeSlots[edgeId]!;

  // Try 1: Perpendicular bend (preferred aesthetics).
  final perpPath = _perpendicularApproach(rawWps, clippedStart, bar, slotPoint);
  if (!_pathCrossesObstacle(perpPath, obstacles, sourceId, targetId)) {
    return perpPath;
  }

  // Try 2: Clip at bar crossing (preserves obstacle avoidance).
  return _clipAtBar(rawWps, clippedStart, bar, slotPoint);
}

/// Build a perpendicular-approach path: keep non-past-bar waypoints, then
/// add a bend so the final segment is perpendicular to the bar.
List<Offset> _perpendicularApproach(
    List<Offset> rawWps, Offset clippedStart, MergeBarInfo bar, Offset slotPoint) {
  final result = <Offset>[clippedStart];
  final inner = rawWps.sublist(1, rawWps.length - 1);
  for (final wp in inner) {
    if (!isPastBar(wp, bar)) {
      result.add(wp);
    }
  }

  // Adjust the last segment to align with the slot's cross-axis position.
  // This handles both overshoots (truncate) and small undershoots (extend)
  // to avoid tiny "buck" segments near the merge bar.
  if (result.length >= 2) {
    final prev2 = result[result.length - 2];
    final last = result.last;
    if (bar.isHorizontal) {
      // Bar is horizontal: adjust horizontal segments on the slot's X.
      if ((prev2.dy - last.dy).abs() < 0.5) {
        final minX = prev2.dx < last.dx ? prev2.dx : last.dx;
        final maxX = prev2.dx > last.dx ? prev2.dx : last.dx;
        // Truncate if slot is between endpoints.
        if (slotPoint.dx >= minX && slotPoint.dx <= maxX) {
          result[result.length - 1] = Offset(slotPoint.dx, last.dy);
        }
        // Extend if slot is slightly past the end (within bar offset distance).
        else if ((slotPoint.dx - last.dx).abs() < mergeBarOffset) {
          result[result.length - 1] = Offset(slotPoint.dx, last.dy);
        }
      }
    } else {
      // Bar is vertical: adjust vertical segments on the slot's Y.
      if ((prev2.dx - last.dx).abs() < 0.5) {
        final minY = prev2.dy < last.dy ? prev2.dy : last.dy;
        final maxY = prev2.dy > last.dy ? prev2.dy : last.dy;
        // Truncate if slot is between endpoints.
        if (slotPoint.dy >= minY && slotPoint.dy <= maxY) {
          result[result.length - 1] = Offset(last.dx, slotPoint.dy);
        }
        // Extend if slot is slightly past the end (within bar offset distance).
        else if ((slotPoint.dy - last.dy).abs() < mergeBarOffset) {
          result[result.length - 1] = Offset(last.dx, slotPoint.dy);
        }
      }
    }
  }

  final prev = result.last;
  final bendPoint = bar.isHorizontal
      ? Offset(slotPoint.dx, prev.dy)
      : Offset(prev.dx, slotPoint.dy);

  if ((bendPoint - prev).distance > 1.0 && (bendPoint - slotPoint).distance > 1.0) {
    result.add(bendPoint);
  }
  result.add(slotPoint);
  return result;
}

/// Build a clip-at-bar path: follow the original route until it crosses the
/// bar line, then bend perpendicularly into the slot so the edge approaches
/// from the front rather than running along the bar.
List<Offset> _clipAtBar(
    List<Offset> rawWps, Offset clippedStart, MergeBarInfo bar, Offset slotPoint) {
  final result = <Offset>[clippedStart];

  for (int i = 1; i < rawWps.length; i++) {
    final prev = result.last;
    final wp = rawWps[i];

    final crossing = _segmentBarCrossing(prev, wp, bar);
    if (crossing != null) {
      // Step back from the bar so the final approach is perpendicular.
      // If stepping back would create a zigzag (crossing is past the slot
      // on the cross axis), skip the crossing and bend directly from prev.
      final stepped = _stepBackFromBar(crossing, bar);
      if (!_wouldZigzag(prev, stepped, slotPoint, bar)) {
        if ((stepped - prev).distance > 1.0) {
          result.add(stepped);
        }
      }
      _addBendToSlot(result, slotPoint, bar);
      return result;
    }

    if (isPastBar(wp, bar)) {
      _addBendToSlot(result, slotPoint, bar);
      return result;
    }

    if ((wp - prev).distance > 0.5) {
      result.add(wp);
    }
  }

  _addBendToSlot(result, slotPoint, bar);
  return result;
}

/// Returns a point slightly in front of the bar (away from the node).
Offset _stepBackFromBar(Offset crossing, MergeBarInfo bar) {
  const stepBack = 10.0;
  if (bar.isHorizontal) {
    final isTop = bar.side == ConnectorSide.top ||
        bar.side == ConnectorSide.topRight ||
        bar.side == ConnectorSide.topLeft;
    return Offset(crossing.dx, isTop ? crossing.dy - stepBack : crossing.dy + stepBack);
  } else {
    return Offset(
      bar.side == ConnectorSide.left ? crossing.dx - stepBack : crossing.dx + stepBack,
      crossing.dy,
    );
  }
}

/// Check if going prev → stepped → bend-to-slot would create a zigzag
/// (direction reversal on the bar's cross axis).
bool _wouldZigzag(Offset prev, Offset stepped, Offset slotPoint, MergeBarInfo bar) {
  if (bar.isHorizontal) {
    final toStepped = stepped.dx - prev.dx;
    final toSlot = slotPoint.dx - stepped.dx;
    return toStepped * toSlot < 0 && toStepped.abs() > 1.0 && toSlot.abs() > 1.0;
  } else {
    final toStepped = stepped.dy - prev.dy;
    final toSlot = slotPoint.dy - stepped.dy;
    return toStepped * toSlot < 0 && toStepped.abs() > 1.0 && toSlot.abs() > 1.0;
  }
}

/// Check if any segment of a path crosses through an obstacle node rect.
bool _pathCrossesObstacle(
    List<Offset> path, List<NodeModel> obstacles, String sourceId, String targetId) {
  for (final node in obstacles) {
    if (node.id == sourceId || node.id == targetId) continue;
    final r = node.rect.inflate(-2.0);
    for (int i = 0; i < path.length - 1; i++) {
      if (_segmentCrossesRect(path[i], path[i + 1], r)) return true;
    }
  }
  return false;
}

bool _segmentCrossesRect(Offset a, Offset b, Rect rect) {
  final isH = (a.dy - b.dy).abs() < 0.5;
  final isV = (a.dx - b.dx).abs() < 0.5;
  if (isH) {
    final y = a.dy;
    if (y <= rect.top || y >= rect.bottom) return false;
    final minX = a.dx < b.dx ? a.dx : b.dx;
    final maxX = a.dx > b.dx ? a.dx : b.dx;
    return maxX > rect.left && minX < rect.right;
  }
  if (isV) {
    final x = a.dx;
    if (x <= rect.left || x >= rect.right) return false;
    final minY = a.dy < b.dy ? a.dy : b.dy;
    final maxY = a.dy > b.dy ? a.dy : b.dy;
    return maxY > rect.top && minY < rect.bottom;
  }
  return false;
}

/// Find where an orthogonal segment crosses the bar line.
Offset? _segmentBarCrossing(Offset a, Offset b, MergeBarInfo bar) {
  if (bar.isHorizontal) {
    if ((a.dx - b.dx).abs() < 0.5) {
      final minY = a.dy < b.dy ? a.dy : b.dy;
      final maxY = a.dy > b.dy ? a.dy : b.dy;
      if (minY < bar.barPos && maxY > bar.barPos) {
        return Offset(a.dx, bar.barPos);
      }
    }
  } else {
    if ((a.dy - b.dy).abs() < 0.5) {
      final minX = a.dx < b.dx ? a.dx : b.dx;
      final maxX = a.dx > b.dx ? a.dx : b.dx;
      if (minX < bar.barPos && maxX > bar.barPos) {
        return Offset(bar.barPos, a.dy);
      }
    }
  }
  return null;
}

/// Add a perpendicular bend from the last waypoint to the slot.
void _addBendToSlot(List<Offset> result, Offset slotPoint, MergeBarInfo bar) {
  final prev = result.last;
  final bendPoint = bar.isHorizontal
      ? Offset(slotPoint.dx, prev.dy)
      : Offset(prev.dx, slotPoint.dy);

  if ((bendPoint - prev).distance > 1.0 && (bendPoint - slotPoint).distance > 1.0) {
    result.add(bendPoint);
  }
  result.add(slotPoint);
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
