import 'dart:ui';
import '../model/diagram_model.dart';
import '../edit/hit_test.dart';

/// Margin around nodes for route clearance.
const double _routeMargin = 20.0;

/// Length of the mandatory stub segment exiting a connector.
const double _stubLength = 30.0;

/// Tolerance for considering two coordinates aligned.
const double _alignTolerance = 5.0;

/// Computes orthogonal (Manhattan-style) waypoints between two nodes.
///
/// Returns a list of [Offset] points including the source anchor and
/// target anchor. The path consists only of horizontal and vertical segments.
class OrthogonalRouter {
  /// Route an edge between [source] and [target], avoiding [obstacles].
  ///
  /// [sourceSide] and [targetSide] specify which side of each node the
  /// connection exits/enters. If null, they are auto-detected.
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

    final srcStub = _stubPoint(srcAnchor, sourceSide);
    final tgtStub = _stubPoint(tgtAnchor, targetSide);

    List<Offset> waypoints;

    // Check for straight-through: same axis, aligned.
    if (_isHorizontal(sourceSide) && _isHorizontal(targetSide)) {
      if ((srcAnchor.dy - tgtAnchor.dy).abs() < _alignTolerance) {
        // Straight horizontal line.
        waypoints = [srcAnchor, tgtAnchor];
      } else {
        waypoints = _routeHH(srcAnchor, srcStub, tgtAnchor, tgtStub,
            sourceSide, targetSide, source, target, obstacles);
      }
    } else if (_isVertical(sourceSide) && _isVertical(targetSide)) {
      if ((srcAnchor.dx - tgtAnchor.dx).abs() < _alignTolerance) {
        // Straight vertical line.
        waypoints = [srcAnchor, tgtAnchor];
      } else {
        waypoints = _routeVV(srcAnchor, srcStub, tgtAnchor, tgtStub,
            sourceSide, targetSide, source, target, obstacles);
      }
    } else {
      waypoints = _routeHV(srcAnchor, srcStub, tgtAnchor, tgtStub,
          sourceSide, targetSide, source, target, obstacles);
    }

    waypoints = _simplify(waypoints);
    return waypoints;
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

  /// Anchor point on the node border for a given side.
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

  /// Point at the end of the mandatory stub segment.
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

  /// Both sides are horizontal: Z-shape or U-turn.
  List<Offset> _routeHH(
    Offset srcAnchor,
    Offset srcStub,
    Offset tgtAnchor,
    Offset tgtStub,
    ConnectorSide srcSide,
    ConnectorSide tgtSide,
    NodeModel source,
    NodeModel target,
    List<NodeModel> obstacles,
  ) {
    // Normal case: source exits right, target enters left (or vice versa)
    // and there's space between them.
    final facingEachOther =
        (srcSide == ConnectorSide.right && tgtSide == ConnectorSide.left) ||
        (srcSide == ConnectorSide.left && tgtSide == ConnectorSide.right);

    if (facingEachOther && _stubsHaveSpace(srcStub, tgtStub, srcSide)) {
      // Z-shape: vertical channel at midpoint X.
      var midX = (srcStub.dx + tgtStub.dx) / 2;
      midX = _adjustMidChannelX(midX, srcStub.dy, tgtStub.dy, source, target, obstacles);
      return [
        srcAnchor,
        srcStub,
        Offset(midX, srcStub.dy),
        Offset(midX, tgtStub.dy),
        tgtStub,
        tgtAnchor,
      ];
    }

    // U-turn: both exiting same direction or target is behind source.
    final uY = _uTurnY(srcStub, tgtStub, source, target, obstacles);
    return [
      srcAnchor,
      srcStub,
      Offset(srcStub.dx, uY),
      Offset(tgtStub.dx, uY),
      tgtStub,
      tgtAnchor,
    ];
  }

  /// Both sides are vertical: same logic rotated 90 degrees.
  List<Offset> _routeVV(
    Offset srcAnchor,
    Offset srcStub,
    Offset tgtAnchor,
    Offset tgtStub,
    ConnectorSide srcSide,
    ConnectorSide tgtSide,
    NodeModel source,
    NodeModel target,
    List<NodeModel> obstacles,
  ) {
    final facingEachOther =
        (srcSide == ConnectorSide.bottom && tgtSide == ConnectorSide.top) ||
        (srcSide == ConnectorSide.top && tgtSide == ConnectorSide.bottom);

    if (facingEachOther && _stubsHaveSpaceV(srcStub, tgtStub, srcSide)) {
      var midY = (srcStub.dy + tgtStub.dy) / 2;
      midY = _adjustMidChannelY(midY, srcStub.dx, tgtStub.dx, source, target, obstacles);
      return [
        srcAnchor,
        srcStub,
        Offset(srcStub.dx, midY),
        Offset(tgtStub.dx, midY),
        tgtStub,
        tgtAnchor,
      ];
    }

    final uX = _uTurnX(srcStub, tgtStub, source, target, obstacles);
    return [
      srcAnchor,
      srcStub,
      Offset(uX, srcStub.dy),
      Offset(uX, tgtStub.dy),
      tgtStub,
      tgtAnchor,
    ];
  }

  /// One horizontal, one vertical: L-shape with one corner.
  List<Offset> _routeHV(
    Offset srcAnchor,
    Offset srcStub,
    Offset tgtAnchor,
    Offset tgtStub,
    ConnectorSide srcSide,
    ConnectorSide tgtSide,
    NodeModel source,
    NodeModel target,
    List<NodeModel> obstacles,
  ) {
    // The corner point connects the horizontal stub to the vertical stub
    // (or vice versa).
    Offset corner;
    if (_isHorizontal(srcSide)) {
      // Source goes horizontal, target goes vertical.
      corner = Offset(tgtStub.dx, srcStub.dy);
    } else {
      // Source goes vertical, target goes horizontal.
      corner = Offset(srcStub.dx, tgtStub.dy);
    }

    final route = [srcAnchor, srcStub, corner, tgtStub, tgtAnchor];

    // Check if the L-shape corner region crosses any obstacle.
    if (_routeHitsObstacle(route, source, target, obstacles)) {
      // Fall back to S-shape through stubs.
      if (_isHorizontal(srcSide)) {
        final midX = (srcStub.dx + tgtStub.dx) / 2;
        return [
          srcAnchor,
          srcStub,
          Offset(midX, srcStub.dy),
          Offset(midX, tgtStub.dy),
          tgtStub,
          tgtAnchor,
        ];
      } else {
        final midY = (srcStub.dy + tgtStub.dy) / 2;
        return [
          srcAnchor,
          srcStub,
          Offset(srcStub.dx, midY),
          Offset(tgtStub.dx, midY),
          tgtStub,
          tgtAnchor,
        ];
      }
    }

    return route;
  }

  /// Check if stubs have enough space between them (horizontal case).
  bool _stubsHaveSpace(Offset srcStub, Offset tgtStub, ConnectorSide srcSide) {
    if (srcSide == ConnectorSide.right) {
      return tgtStub.dx > srcStub.dx + _routeMargin;
    } else {
      return tgtStub.dx < srcStub.dx - _routeMargin;
    }
  }

  /// Check if stubs have enough space between them (vertical case).
  bool _stubsHaveSpaceV(Offset srcStub, Offset tgtStub, ConnectorSide srcSide) {
    if (srcSide == ConnectorSide.bottom) {
      return tgtStub.dy > srcStub.dy + _routeMargin;
    } else {
      return tgtStub.dy < srcStub.dy - _routeMargin;
    }
  }

  /// Compute Y for a U-turn that clears both nodes.
  double _uTurnY(Offset srcStub, Offset tgtStub, NodeModel source,
      NodeModel target, List<NodeModel> obstacles) {
    // Go above or below both nodes.
    final topClear = [source.rect.top, target.rect.top]
            .reduce((a, b) => a < b ? a : b) -
        _routeMargin - _stubLength;
    final bottomClear = [source.rect.bottom, target.rect.bottom]
            .reduce((a, b) => a > b ? a : b) +
        _routeMargin + _stubLength;

    // Pick the side that's closer to the stubs.
    final avgStubY = (srcStub.dy + tgtStub.dy) / 2;
    return (avgStubY - topClear).abs() < (avgStubY - bottomClear).abs()
        ? topClear
        : bottomClear;
  }

  /// Compute X for a U-turn that clears both nodes (vertical case).
  double _uTurnX(Offset srcStub, Offset tgtStub, NodeModel source,
      NodeModel target, List<NodeModel> obstacles) {
    final leftClear = [source.rect.left, target.rect.left]
            .reduce((a, b) => a < b ? a : b) -
        _routeMargin - _stubLength;
    final rightClear = [source.rect.right, target.rect.right]
            .reduce((a, b) => a > b ? a : b) +
        _routeMargin + _stubLength;

    final avgStubX = (srcStub.dx + tgtStub.dx) / 2;
    return (avgStubX - leftClear).abs() < (avgStubX - rightClear).abs()
        ? leftClear
        : rightClear;
  }

  /// Adjust the mid-channel X to avoid obstacles.
  double _adjustMidChannelX(double midX, double y1, double y2,
      NodeModel source, NodeModel target, List<NodeModel> obstacles) {
    final minY = y1 < y2 ? y1 : y2;
    final maxY = y1 > y2 ? y1 : y2;

    for (final obs in obstacles) {
      if (obs.id == source.id || obs.id == target.id) continue;
      final inflated = obs.rect.inflate(_routeMargin);
      // Check if the vertical segment at midX would cross this obstacle.
      if (midX > inflated.left &&
          midX < inflated.right &&
          maxY > inflated.top &&
          minY < inflated.bottom) {
        // Shift midX to clear the obstacle.
        final shiftLeft = inflated.left - _routeMargin;
        final shiftRight = inflated.right + _routeMargin;
        midX = (midX - shiftLeft).abs() < (midX - shiftRight).abs()
            ? shiftLeft
            : shiftRight;
      }
    }
    return midX;
  }

  /// Adjust the mid-channel Y to avoid obstacles.
  double _adjustMidChannelY(double midY, double x1, double x2,
      NodeModel source, NodeModel target, List<NodeModel> obstacles) {
    final minX = x1 < x2 ? x1 : x2;
    final maxX = x1 > x2 ? x1 : x2;

    for (final obs in obstacles) {
      if (obs.id == source.id || obs.id == target.id) continue;
      final inflated = obs.rect.inflate(_routeMargin);
      if (midY > inflated.top &&
          midY < inflated.bottom &&
          maxX > inflated.left &&
          minX < inflated.right) {
        final shiftUp = inflated.top - _routeMargin;
        final shiftDown = inflated.bottom + _routeMargin;
        midY = (midY - shiftUp).abs() < (midY - shiftDown).abs()
            ? shiftUp
            : shiftDown;
      }
    }
    return midY;
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

  /// Test if an axis-aligned segment intersects a rectangle.
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
    // Diagonal — shouldn't happen with our router, but ignore.
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
      if ((prev.dx - curr.dx).abs() < 0.1 && (prev.dy - curr.dy).abs() < 0.1) {
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
