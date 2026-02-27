import 'dart:ui';
import '../model/diagram_model.dart';
import '../edit/hit_test.dart';

/// Margin around nodes for route clearance.
const double _routeMargin = 20.0;

/// Length of the mandatory stub segment exiting a connector.
const double _stubLength = 20.0;

/// Tolerance for considering two coordinates aligned.
const double _alignTolerance = 5.0;

/// Computes orthogonal (Manhattan-style) waypoints between two nodes.
///
/// Returns a list of [Offset] points including the source anchor and
/// target anchor. The path consists only of horizontal and vertical segments.
class OrthogonalRouter {
  /// Route an edge between [source] and [target], avoiding [obstacles].
  List<Offset> route({
    required NodeModel source,
    required NodeModel target,
    ConnectorSide? sourceSide,
    ConnectorSide? targetSide,
    List<NodeModel> obstacles = const [],
  }) {
    sourceSide ??= bestSourceSide(source, target);
    targetSide ??= bestTargetSide(source, target, sourceSide);

    final srcAnchor = _anchorPoint(source, sourceSide);
    final tgtAnchor = _anchorPoint(target, targetSide);

    // Check for straight-through: same axis, aligned, no obstacles in the way.
    if (_isVertical(sourceSide) && _isVertical(targetSide) &&
        (srcAnchor.dx - tgtAnchor.dx).abs() < _alignTolerance) {
      final straight = [srcAnchor, tgtAnchor];
      if (!_routeHitsObstacle(straight, source, target, obstacles)) {
        return straight;
      }
    }
    if (_isHorizontal(sourceSide) && _isHorizontal(targetSide) &&
        (srcAnchor.dy - tgtAnchor.dy).abs() < _alignTolerance) {
      final straight = [srcAnchor, tgtAnchor];
      if (!_routeHitsObstacle(straight, source, target, obstacles)) {
        return straight;
      }
    }

    // Try L-shape first (fewest bends).
    final lRoute = _tryLShape(srcAnchor, tgtAnchor, sourceSide, targetSide,
        source, target, obstacles);
    if (lRoute != null) return _simplify(lRoute);

    // Try Z-shape (one intermediate channel).
    final zRoute = _tryZShape(srcAnchor, tgtAnchor, sourceSide, targetSide,
        source, target, obstacles);
    if (zRoute != null) return _simplify(zRoute);

    // Fallback: U-turn.
    final uRoute = _makeUTurn(srcAnchor, tgtAnchor, sourceSide, targetSide,
        source, target, obstacles);
    return _simplify(uRoute);
  }

  /// Auto-detect the best source side facing the target.
  ConnectorSide bestSourceSide(NodeModel source, NodeModel target) {
    return _bestSideFacing(source, target.center);
  }

  /// Auto-detect the best target side facing the source.
  ConnectorSide bestTargetSide(
      NodeModel source, NodeModel target, ConnectorSide sourceSide) {
    return _bestSideFacing(target, source.center);
  }

  ConnectorSide _bestSideFacing(NodeModel node, Offset toward) {
    final dx = toward.dx - node.center.dx;
    final dy = toward.dy - node.center.dy;

    if (dx.abs() >= dy.abs()) {
      return dx >= 0 ? ConnectorSide.right : ConnectorSide.left;
    } else {
      return dy >= 0 ? ConnectorSide.bottom : ConnectorSide.top;
    }
  }

  Offset _anchorPoint(NodeModel node, ConnectorSide side) {
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

  Offset _stubPoint(Offset anchor, ConnectorSide side) {
    switch (side) {
      case ConnectorSide.top:
        return Offset(anchor.dx, anchor.dy - _stubLength);
      case ConnectorSide.right:
        return Offset(anchor.dx + _stubLength, anchor.dy);
      case ConnectorSide.bottom:
        return Offset(anchor.dx, anchor.dy + _stubLength);
      case ConnectorSide.left:
        return Offset(anchor.dx - _stubLength, anchor.dy);
    }
  }

  bool _isHorizontal(ConnectorSide side) =>
      side == ConnectorSide.left || side == ConnectorSide.right;

  bool _isVertical(ConnectorSide side) =>
      side == ConnectorSide.top || side == ConnectorSide.bottom;

  /// Try an L-shape: stub from source, one corner, stub into target.
  /// Works when source and target exit on perpendicular sides,
  /// or when one side is vertical and the other horizontal.
  List<Offset>? _tryLShape(
    Offset srcAnchor,
    Offset tgtAnchor,
    ConnectorSide srcSide,
    ConnectorSide tgtSide,
    NodeModel source,
    NodeModel target,
    List<NodeModel> obstacles,
  ) {
    final srcStub = _stubPoint(srcAnchor, srcSide);
    final tgtStub = _stubPoint(tgtAnchor, tgtSide);

    // For mixed H/V sides, try both corner options and pick the best.
    if (_isHorizontal(srcSide) != _isHorizontal(tgtSide)) {
      // Corner A: extends source stub direction, then bends toward target.
      // Corner B: the alternative L-shape orientation.
      final cornerA = _isHorizontal(srcSide)
          ? Offset(tgtStub.dx, srcStub.dy)
          : Offset(srcStub.dx, tgtStub.dy);
      final cornerB = _isHorizontal(srcSide)
          ? Offset(srcStub.dx, tgtStub.dy)
          : Offset(tgtStub.dx, srcStub.dy);

      final routeA = [srcAnchor, srcStub, cornerA, tgtStub, tgtAnchor];
      final routeB = [srcAnchor, srcStub, cornerB, tgtStub, tgtAnchor];

      final aOk = !_routeHitsObstacle(routeA, source, target, obstacles);
      final bOk = !_routeHitsObstacle(routeB, source, target, obstacles);

      if (aOk && bOk) {
        // Prefer the corner that doesn't create a U-turn (going backward
        // past the anchor on the stub axis).
        final aBacktrack = _createsBacktrack(srcAnchor, srcStub, cornerA) ||
            _createsBacktrack(tgtAnchor, tgtStub, cornerA);
        final bBacktrack = _createsBacktrack(srcAnchor, srcStub, cornerB) ||
            _createsBacktrack(tgtAnchor, tgtStub, cornerB);
        if (aBacktrack && !bBacktrack) return _simplify(routeB);
        if (bBacktrack && !aBacktrack) return _simplify(routeA);
        return routeA; // both fine, prefer A
      }
      if (aOk) return routeA;
      if (bOk) return _simplify(routeB);
    }

    // For same-axis sides (both V or both H) with slight offset,
    // convert to an L by using one stub direction + a perpendicular jog.
    if (_isVertical(srcSide) && _isVertical(tgtSide)) {
      // Source exits vertically, bend horizontally to align with target, then enter.
      final route = [
        srcAnchor,
        srcStub,
        Offset(tgtAnchor.dx, srcStub.dy),
        tgtAnchor,
      ];
      if (!_routeHitsObstacle(route, source, target, obstacles)) {
        return route;
      }
      // Try the other way: go straight from source, bend at target stub level.
      final route2 = [
        srcAnchor,
        Offset(srcAnchor.dx, tgtStub.dy),
        tgtStub,
        tgtAnchor,
      ];
      if (!_routeHitsObstacle(route2, source, target, obstacles)) {
        return route2;
      }
    }

    if (_isHorizontal(srcSide) && _isHorizontal(tgtSide)) {
      final route = [
        srcAnchor,
        srcStub,
        Offset(srcStub.dx, tgtAnchor.dy),
        tgtAnchor,
      ];
      if (!_routeHitsObstacle(route, source, target, obstacles)) {
        return route;
      }
      final route2 = [
        srcAnchor,
        Offset(srcAnchor.dx, tgtStub.dy),
        tgtStub,
        tgtAnchor,
      ];
      if (!_routeHitsObstacle(route2, source, target, obstacles)) {
        return route2;
      }
    }

    return null;
  }

  /// Try a Z-shape: stub, horizontal/vertical channel, stub.
  List<Offset>? _tryZShape(
    Offset srcAnchor,
    Offset tgtAnchor,
    ConnectorSide srcSide,
    ConnectorSide tgtSide,
    NodeModel source,
    NodeModel target,
    List<NodeModel> obstacles,
  ) {
    final srcStub = _stubPoint(srcAnchor, srcSide);
    final tgtStub = _stubPoint(tgtAnchor, tgtSide);

    if (_isVertical(srcSide) && _isVertical(tgtSide)) {
      // Z with a horizontal channel at the midpoint Y.
      var midY = (srcStub.dy + tgtStub.dy) / 2;
      final route = [
        srcAnchor,
        srcStub,
        Offset(srcStub.dx, midY),
        Offset(tgtStub.dx, midY),
        tgtStub,
        tgtAnchor,
      ];
      if (!_routeHitsObstacle(route, source, target, obstacles)) {
        return route;
      }
    }

    if (_isHorizontal(srcSide) && _isHorizontal(tgtSide)) {
      var midX = (srcStub.dx + tgtStub.dx) / 2;
      final route = [
        srcAnchor,
        srcStub,
        Offset(midX, srcStub.dy),
        Offset(midX, tgtStub.dy),
        tgtStub,
        tgtAnchor,
      ];
      if (!_routeHitsObstacle(route, source, target, obstacles)) {
        return route;
      }
    }

    return null;
  }

  /// Fallback U-turn: go around both nodes.
  List<Offset> _makeUTurn(
    Offset srcAnchor,
    Offset tgtAnchor,
    ConnectorSide srcSide,
    ConnectorSide tgtSide,
    NodeModel source,
    NodeModel target,
    List<NodeModel> obstacles,
  ) {
    final srcStub = _stubPoint(srcAnchor, srcSide);
    final tgtStub = _stubPoint(tgtAnchor, tgtSide);

    if (_isVertical(srcSide) || _isVertical(tgtSide)) {
      // Go left or right of both nodes.
      final leftClear = [source.rect.left, target.rect.left]
              .reduce((a, b) => a < b ? a : b) -
          _routeMargin - _stubLength;
      final rightClear = [source.rect.right, target.rect.right]
              .reduce((a, b) => a > b ? a : b) +
          _routeMargin + _stubLength;

      final avgX = (srcStub.dx + tgtStub.dx) / 2;
      final uX = (avgX - leftClear).abs() < (avgX - rightClear).abs()
          ? leftClear
          : rightClear;

      return [
        srcAnchor,
        srcStub,
        Offset(uX, srcStub.dy),
        Offset(uX, tgtStub.dy),
        tgtStub,
        tgtAnchor,
      ];
    } else {
      // Go above or below both nodes.
      final topClear = [source.rect.top, target.rect.top]
              .reduce((a, b) => a < b ? a : b) -
          _routeMargin - _stubLength;
      final bottomClear = [source.rect.bottom, target.rect.bottom]
              .reduce((a, b) => a > b ? a : b) +
          _routeMargin + _stubLength;

      final avgY = (srcStub.dy + tgtStub.dy) / 2;
      final uY = (avgY - topClear).abs() < (avgY - bottomClear).abs()
          ? topClear
          : bottomClear;

      return [
        srcAnchor,
        srcStub,
        Offset(srcStub.dx, uY),
        Offset(tgtStub.dx, uY),
        tgtStub,
        tgtAnchor,
      ];
    }
  }

  /// Check if any segment of the route crosses an inflated obstacle rect.
  bool _routeHitsObstacle(List<Offset> route, NodeModel source,
      NodeModel target, List<NodeModel> obstacles) {
    for (final obs in obstacles) {
      if (obs.id == source.id || obs.id == target.id) continue;
      final inflated = obs.rect.inflate(_routeMargin);
      for (int i = 0; i < route.length - 1; i++) {
        if (_segmentIntersectsRect(route[i], route[i + 1], inflated)) {
          return true;
        }
      }
    }
    return false;
  }

  /// Check if going from anchor→stub→corner creates a backtrack (U-turn)
  /// on the stub's axis.
  bool _createsBacktrack(Offset anchor, Offset stub, Offset corner) {
    // Vertical stub: check if corner.dy is between anchor.dy and stub.dy
    // (i.e. the corner goes back toward the anchor).
    if ((anchor.dx - stub.dx).abs() < 0.1) {
      // Stub goes up (stub.dy < anchor.dy) → backtrack if corner.dy > stub.dy toward anchor.
      // Stub goes down (stub.dy > anchor.dy) → backtrack if corner.dy < stub.dy toward anchor.
      final stubDir = stub.dy - anchor.dy;
      final cornerDir = corner.dy - stub.dy;
      return stubDir * cornerDir < 0; // opposite directions = backtrack
    }
    // Horizontal stub.
    if ((anchor.dy - stub.dy).abs() < 0.1) {
      final stubDir = stub.dx - anchor.dx;
      final cornerDir = corner.dx - stub.dx;
      return stubDir * cornerDir < 0;
    }
    return false;
  }

  bool _segmentIntersectsRect(Offset a, Offset b, Rect rect) {
    // Horizontal segment.
    if ((a.dy - b.dy).abs() < 0.1) {
      final y = a.dy;
      if (y < rect.top || y > rect.bottom) return false;
      final minX = a.dx < b.dx ? a.dx : b.dx;
      final maxX = a.dx > b.dx ? a.dx : b.dx;
      return maxX > rect.left && minX < rect.right;
    }
    // Vertical segment.
    if ((a.dx - b.dx).abs() < 0.1) {
      final x = a.dx;
      if (x < rect.left || x > rect.right) return false;
      final minY = a.dy < b.dy ? a.dy : b.dy;
      final maxY = a.dy > b.dy ? a.dy : b.dy;
      return maxY > rect.top && minY < rect.bottom;
    }
    return false;
  }

  /// Remove redundant collinear waypoints.
  List<Offset> _simplify(List<Offset> points) {
    if (points.length <= 2) return points;

    final result = <Offset>[points.first];
    for (int i = 1; i < points.length - 1; i++) {
      final prev = result.last;
      final curr = points[i];
      final next = points[i + 1];

      // Skip if collinear (all on same horizontal or vertical line).
      final sameX = (prev.dx - curr.dx).abs() < 0.1 &&
          (curr.dx - next.dx).abs() < 0.1;
      final sameY = (prev.dy - curr.dy).abs() < 0.1 &&
          (curr.dy - next.dy).abs() < 0.1;
      if (sameX || sameY) continue;

      // Skip zero-length segments.
      if ((prev.dx - curr.dx).abs() < 0.1 &&
          (prev.dy - curr.dy).abs() < 0.1) {
        continue;
      }

      result.add(curr);
    }
    result.add(points.last);

    // Remove any remaining zero-length segments.
    if (result.length > 1) {
      final cleaned = <Offset>[result.first];
      for (int i = 1; i < result.length; i++) {
        if ((result[i].dx - cleaned.last.dx).abs() > 0.1 ||
            (result[i].dy - cleaned.last.dy).abs() > 0.1) {
          cleaned.add(result[i]);
        }
      }
      return cleaned;
    }

    return result;
  }
}
