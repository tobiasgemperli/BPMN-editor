import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:bpmn_editor/diagram/model/diagram_model.dart';
import 'package:bpmn_editor/diagram/edit/hit_test.dart';
import 'package:bpmn_editor/diagram/routing/orthogonal_router.dart';

/// Helper to make a task node at a center position.
NodeModel _task(String id, double cx, double cy,
    {double w = 140, double h = 70}) {
  return NodeModel(
    id: id,
    type: NodeType.task,
    name: id,
    rect: Rect.fromCenter(center: Offset(cx, cy), width: w, height: h),
  );
}

/// Helper to make a gateway node at a center position.
NodeModel _gateway(String id, double cx, double cy) {
  return NodeModel(
    id: id,
    type: NodeType.exclusiveGateway,
    name: id,
    rect: Rect.fromCenter(center: Offset(cx, cy), width: 56, height: 56),
  );
}

/// Helper to make a circle event node at a center position.
NodeModel _event(String id, double cx, double cy, {bool end = false}) {
  return NodeModel(
    id: id,
    type: end ? NodeType.endEvent : NodeType.startEvent,
    name: id,
    rect: Rect.fromCenter(center: Offset(cx, cy), width: 48, height: 48),
  );
}

/// Verify all segments are orthogonal (horizontal or vertical).
void _expectOrthogonal(List<Offset> wps) {
  for (int i = 0; i < wps.length - 1; i++) {
    final a = wps[i];
    final b = wps[i + 1];
    final isHorizontal = (a.dy - b.dy).abs() < 0.1;
    final isVertical = (a.dx - b.dx).abs() < 0.1;
    expect(isHorizontal || isVertical, isTrue,
        reason:
            'Segment $i->${'${i + 1}'} is diagonal: (${'${a.dx.toStringAsFixed(1)}'}, ${'${a.dy.toStringAsFixed(1)}'}) -> (${'${b.dx.toStringAsFixed(1)}'}, ${'${b.dy.toStringAsFixed(1)}'})');
  }
}

/// Verify no segment passes through a node rect (inflated by margin).
void _expectNoOverlap(List<Offset> wps, List<NodeModel> avoidNodes,
    {double margin = 10.0}) {
  for (final node in avoidNodes) {
    final r = node.rect.inflate(margin);
    for (int i = 0; i < wps.length - 1; i++) {
      final a = wps[i];
      final b = wps[i + 1];
      // Horizontal segment.
      if ((a.dy - b.dy).abs() < 0.1) {
        final y = a.dy;
        if (y <= r.top || y >= r.bottom) continue;
        final minX = a.dx < b.dx ? a.dx : b.dx;
        final maxX = a.dx > b.dx ? a.dx : b.dx;
        if (maxX > r.left && minX < r.right) {
          fail(
              'Segment $i->${'${i + 1}'} crosses node ${node.id}: y=${'${y.toStringAsFixed(1)}'} through rect ${node.rect}');
        }
      }
      // Vertical segment.
      if ((a.dx - b.dx).abs() < 0.1) {
        final x = a.dx;
        if (x <= r.left || x >= r.right) continue;
        final minY = a.dy < b.dy ? a.dy : b.dy;
        final maxY = a.dy > b.dy ? a.dy : b.dy;
        if (maxY > r.top && minY < r.bottom) {
          fail(
              'Segment $i->${'${i + 1}'} crosses node ${node.id}: x=${'${x.toStringAsFixed(1)}'} through rect ${node.rect}');
        }
      }
    }
  }
}

/// Verify the first waypoint is on the source node border and the last
/// is on the target node border.
void _expectEndpointsOnBorder(
    List<Offset> wps, NodeModel source, NodeModel target) {
  expect(wps.length, greaterThanOrEqualTo(2));

  // First point should be on source border (within 1px tolerance).
  final first = wps.first;
  expect(
    _isOnBorder(first, source),
    isTrue,
    reason:
        'Start (${'${first.dx.toStringAsFixed(1)}'}, ${'${first.dy.toStringAsFixed(1)}'}) not on source ${source.id} border ${source.rect}',
  );

  // Last point should be on target border.
  final last = wps.last;
  expect(
    _isOnBorder(last, target),
    isTrue,
    reason:
        'End (${'${last.dx.toStringAsFixed(1)}'}, ${'${last.dy.toStringAsFixed(1)}'}) not on target ${target.id} border ${target.rect}',
  );
}

bool _isOnBorder(Offset p, NodeModel node) {
  const tol = 1.0;
  final r = node.rect;
  final onLeft = (p.dx - r.left).abs() < tol;
  final onRight = (p.dx - r.right).abs() < tol;
  final onTop = (p.dy - r.top).abs() < tol;
  final onBottom = (p.dy - r.bottom).abs() < tol;
  final withinX = p.dx >= r.left - tol && p.dx <= r.right + tol;
  final withinY = p.dy >= r.top - tol && p.dy <= r.bottom + tol;
  return (onLeft && withinY) ||
      (onRight && withinY) ||
      (onTop && withinX) ||
      (onBottom && withinX);
}

/// Compute total path length.
double _pathLength(List<Offset> wps) {
  double len = 0;
  for (int i = 0; i < wps.length - 1; i++) {
    len += (wps[i + 1] - wps[i]).distance;
  }
  return len;
}

void main() {
  late OrthogonalRouter router;

  setUp(() {
    router = OrthogonalRouter();
  });

  group('Straight lines', () {
    test('vertically aligned nodes produce a straight 2-point route', () {
      final a = _task('A', 200, 100);
      final b = _task('B', 200, 300);
      final wps = router.route(source: a, target: b);

      _expectOrthogonal(wps);
      _expectEndpointsOnBorder(wps, a, b);
      expect(wps.length, 2, reason: 'Aligned vertical should be 2 points');
      // Should be a straight vertical line.
      expect((wps[0].dx - wps[1].dx).abs(), lessThan(1.0));
    });

    test('horizontally aligned nodes produce a straight 2-point route', () {
      final a = _task('A', 100, 200);
      final b = _task('B', 400, 200);
      final wps = router.route(source: a, target: b);

      _expectOrthogonal(wps);
      _expectEndpointsOnBorder(wps, a, b);
      expect(wps.length, 2, reason: 'Aligned horizontal should be 2 points');
      expect((wps[0].dy - wps[1].dy).abs(), lessThan(1.0));
    });
  });

  group('L-shaped routes (offset nodes)', () {
    test('target is below-right: should make an L or Z with few bends', () {
      final a = _task('A', 100, 100);
      final b = _task('B', 300, 300);
      final wps = router.route(source: a, target: b);

      _expectOrthogonal(wps);
      _expectEndpointsOnBorder(wps, a, b);
      // Should not have more than 5 waypoints (anchor, stub, corner, stub, anchor).
      expect(wps.length, lessThanOrEqualTo(5),
          reason: 'Simple offset should not zigzag: got ${wps.length} points');
    });

    test('target is above-left: should route cleanly', () {
      final a = _task('A', 300, 300);
      final b = _task('B', 100, 100);
      final wps = router.route(source: a, target: b);

      _expectOrthogonal(wps);
      _expectEndpointsOnBorder(wps, a, b);
      expect(wps.length, lessThanOrEqualTo(5),
          reason: 'Reverse offset should not zigzag: got ${wps.length} points');
    });
  });

  group('Slightly offset nodes (the drag scenario)', () {
    test('node moved slightly right from vertical alignment', () {
      // This is the real-world case: Sprint 1 at x=180, Sprint 2 dragged to x=230.
      final a = _task('A', 180, 385);
      final b = _task('B', 230, 495);
      final wps = router.route(source: a, target: b);

      _expectOrthogonal(wps);
      _expectEndpointsOnBorder(wps, a, b);

      // Key assertion: for a small horizontal offset (~50px), route should be
      // simple — at most one horizontal jog, not a U-turn.
      expect(wps.length, lessThanOrEqualTo(4),
          reason:
              'Slight offset should be L-shape (4 pts max), got ${wps.length}: $wps');

      // Path should be reasonably short — not going far away.
      final directDist = (b.center - a.center).distance;
      final pathLen = _pathLength(wps);
      expect(pathLen, lessThan(directDist * 2.5),
          reason:
              'Path length ${pathLen.toStringAsFixed(0)} is too long vs direct ${directDist.toStringAsFixed(0)}');
    });

    test('node moved slightly left from vertical alignment', () {
      final a = _task('A', 180, 385);
      final b = _task('B', 130, 495);
      final wps = router.route(source: a, target: b);

      _expectOrthogonal(wps);
      _expectEndpointsOnBorder(wps, a, b);
      expect(wps.length, lessThanOrEqualTo(4),
          reason:
              'Slight left offset should be L-shape, got ${wps.length}: $wps');
    });

    test('node moved to same Y but different X', () {
      // Side-by-side: should route horizontally.
      final a = _task('A', 100, 200);
      final b = _task('B', 350, 200);
      final wps = router.route(source: a, target: b);

      _expectOrthogonal(wps);
      _expectEndpointsOnBorder(wps, a, b);
      expect(wps.length, 2);
    });
  });

  group('U-turn scenarios', () {
    test('target directly above source: route goes up', () {
      final a = _task('A', 200, 400);
      final b = _task('B', 200, 100);
      final wps = router.route(source: a, target: b);

      _expectOrthogonal(wps);
      _expectEndpointsOnBorder(wps, a, b);
      // Source exits top, target enters bottom — straight up.
      expect(wps.length, 2);
    });

    test('target to the left of source: route goes left', () {
      final a = _task('A', 400, 200);
      final b = _task('B', 100, 200);
      final wps = router.route(source: a, target: b);

      _expectOrthogonal(wps);
      _expectEndpointsOnBorder(wps, a, b);
      expect(wps.length, 2);
    });
  });

  group('Obstacle avoidance', () {
    test('route avoids an obstacle between source and target', () {
      final a = _task('A', 200, 100);
      final c = _task('C', 200, 300); // obstacle in the middle
      final b = _task('B', 200, 500);
      final wps = router.route(source: a, target: b, obstacles: [c]);

      _expectOrthogonal(wps);
      _expectEndpointsOnBorder(wps, a, b);
      _expectNoOverlap(wps, [c]);
    });
  });

  group('Mixed node types', () {
    test('gateway to task routes cleanly', () {
      final gw = _gateway('GW', 180, 272);
      final task = _task('T', 180, 385);
      final wps = router.route(
        source: gw,
        target: task,
        sourceSide: ConnectorSide.bottom,
        targetSide: ConnectorSide.top,
      );

      _expectOrthogonal(wps);
      expect(wps.length, 2, reason: 'Aligned gateway->task should be straight');
    });

    test('gateway to event (horizontal branch) routes cleanly', () {
      final gw = _gateway('GW', 180, 272);
      final end = _event('End', 344, 272, end: true);
      final wps = router.route(
        source: gw,
        target: end,
        sourceSide: ConnectorSide.right,
        targetSide: ConnectorSide.left,
      );

      _expectOrthogonal(wps);
      _expectEndpointsOnBorder(wps, gw, end);
      expect(wps.length, 2,
          reason: 'Aligned horizontal gateway->event should be straight');
    });
  });

  group('Path quality for real diagram positions', () {
    // These test the actual positions from the sample BPMN diagram.
    test('Sprint 1 to Sprint 2 (vertically aligned)', () {
      final s1 = _task('s1', 180, 385);
      final s2 = _task('s2', 180, 495);
      final wps = router.route(source: s1, target: s2);

      _expectOrthogonal(wps);
      expect(wps.length, 2);
    });

    test('Sprint 2 moved 50px right still routes simply', () {
      final s1 = _task('s1', 180, 385);
      final s2 = _task('s2', 230, 495);
      final wps = router.route(source: s1, target: s2);

      _expectOrthogonal(wps);
      // Should be at most an L-shape.
      expect(wps.length, lessThanOrEqualTo(4),
          reason: 'Got $wps');
    });

    test('Sprint 2 moved 100px right still routes simply', () {
      final s1 = _task('s1', 180, 385);
      final s2 = _task('s2', 280, 495);
      final wps = router.route(source: s1, target: s2);

      _expectOrthogonal(wps);
      expect(wps.length, lessThanOrEqualTo(5),
          reason: 'Got $wps');

      final directDist = (s2.center - s1.center).distance;
      final pathLen = _pathLength(wps);
      expect(pathLen, lessThan(directDist * 3),
          reason: 'Path too long: $pathLen vs direct $directDist');
    });

    test('Sprint 2 moved 50px left still routes simply', () {
      final s1 = _task('s1', 180, 385);
      final s2 = _task('s2', 130, 495);
      final wps = router.route(source: s1, target: s2);

      _expectOrthogonal(wps);
      expect(wps.length, lessThanOrEqualTo(4),
          reason: 'Got $wps');
    });

    test('Sprint 2 moved beside Sprint 1 (same Y) routes horizontally', () {
      final s1 = _task('s1', 180, 385);
      final s2 = _task('s2', 400, 385);
      final wps = router.route(source: s1, target: s2);

      _expectOrthogonal(wps);
      _expectEndpointsOnBorder(wps, s1, s2);
      expect(wps.length, 2);
    });

    test('Sprint 2 moved above Sprint 1', () {
      final s1 = _task('s1', 180, 385);
      final s2 = _task('s2', 280, 300);
      final wps = router.route(source: s1, target: s2);

      _expectOrthogonal(wps);
      _expectEndpointsOnBorder(wps, s1, s2);
      // Should route reasonably even though target is above.
      final directDist = (s2.center - s1.center).distance;
      final pathLen = _pathLength(wps);
      expect(pathLen, lessThan(directDist * 3),
          reason: 'Path too long: $pathLen vs direct $directDist');
    });
  });

  group('Side detection', () {
    test('bestSourceSide picks bottom when target is below', () {
      final a = _task('A', 200, 100);
      final b = _task('B', 200, 300);
      expect(router.bestSourceSide(a, b), ConnectorSide.bottom);
    });

    test('bestSourceSide picks right when target is to the right', () {
      final a = _task('A', 100, 200);
      final b = _task('B', 400, 200);
      expect(router.bestSourceSide(a, b), ConnectorSide.right);
    });

    test('bestSourceSide picks top when target is above', () {
      final a = _task('A', 200, 400);
      final b = _task('B', 200, 100);
      expect(router.bestSourceSide(a, b), ConnectorSide.top);
    });

    test('bestSourceSide picks left when target is to the left', () {
      final a = _task('A', 400, 200);
      final b = _task('B', 100, 200);
      expect(router.bestSourceSide(a, b), ConnectorSide.left);
    });

    test('diagonal bias: prefers vertical when dy > dx', () {
      final a = _task('A', 200, 100);
      final b = _task('B', 250, 400); // dx=50, dy=300 → vertical
      expect(router.bestSourceSide(a, b), ConnectorSide.bottom);
    });

    test('diagonal bias: prefers horizontal when dx > dy', () {
      final a = _task('A', 100, 200);
      final b = _task('B', 500, 250); // dx=400, dy=50 → horizontal
      expect(router.bestSourceSide(a, b), ConnectorSide.right);
    });
  });
}
