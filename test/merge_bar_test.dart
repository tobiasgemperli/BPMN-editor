import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:bpmn_editor/diagram/model/diagram_model.dart';
import 'package:bpmn_editor/diagram/edit/hit_test.dart';
import 'package:bpmn_editor/diagram/render/merge_bar.dart';

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

/// Helper to make a gateway node.
NodeModel _gateway(String id, double cx, double cy) {
  return NodeModel(
    id: id,
    type: NodeType.exclusiveGateway,
    name: id,
    rect: Rect.fromCenter(center: Offset(cx, cy), width: 56, height: 56),
  );
}

/// Helper to make a start event node.
NodeModel _event(String id, double cx, double cy) {
  return NodeModel(
    id: id,
    type: NodeType.startEvent,
    name: id,
    rect: Rect.fromCenter(center: Offset(cx, cy), width: 48, height: 48),
  );
}

void main() {
  group('computeMergeBars', () {
    test('no merge bar for nodes with 0 or 1 incoming edges', () {
      // A -> B -> C (each node has at most 1 incoming)
      final diagram = DiagramModel(
        nodes: {
          'A': _task('A', 100, 200),
          'B': _task('B', 300, 200),
          'C': _task('C', 500, 200),
        },
        edges: {
          'e1': EdgeModel(id: 'e1', sourceId: 'A', targetId: 'B',
              waypoints: [const Offset(100, 200), const Offset(300, 200)]),
          'e2': EdgeModel(id: 'e2', sourceId: 'B', targetId: 'C',
              waypoints: [const Offset(300, 200), const Offset(500, 200)]),
        },
      );
      final bars = computeMergeBars(diagram);
      expect(bars, isEmpty);
    });

    test('merge bar created for node with 2 incoming edges', () {
      // A -> C, B -> C
      final diagram = DiagramModel(
        nodes: {
          'A': _task('A', 100, 100),
          'B': _task('B', 100, 300),
          'C': _task('C', 400, 200),
        },
        edges: {
          'e1': EdgeModel(id: 'e1', sourceId: 'A', targetId: 'C',
              waypoints: [const Offset(100, 100), const Offset(300, 100), const Offset(300, 200), const Offset(400, 200)]),
          'e2': EdgeModel(id: 'e2', sourceId: 'B', targetId: 'C',
              waypoints: [const Offset(100, 300), const Offset(300, 300), const Offset(300, 200), const Offset(400, 200)]),
        },
      );
      final bars = computeMergeBars(diagram);
      expect(bars.length, 1);
      expect(bars.containsKey('C'), isTrue);
    });

    test('merge bar not created for node with exactly 1 incoming edge', () {
      final diagram = DiagramModel(
        nodes: {
          'A': _task('A', 100, 200),
          'B': _task('B', 400, 200),
        },
        edges: {
          'e1': EdgeModel(id: 'e1', sourceId: 'A', targetId: 'B',
              waypoints: [const Offset(100, 200), const Offset(400, 200)]),
        },
      );
      final bars = computeMergeBars(diagram);
      expect(bars, isEmpty);
    });

    test('merge bar created for node with 3 incoming edges', () {
      final diagram = DiagramModel(
        nodes: {
          'A': _task('A', 100, 100),
          'B': _task('B', 100, 300),
          'D': _task('D', 100, 500),
          'C': _task('C', 400, 300),
        },
        edges: {
          'e1': EdgeModel(id: 'e1', sourceId: 'A', targetId: 'C',
              waypoints: [const Offset(100, 100), const Offset(300, 100), const Offset(300, 300), const Offset(400, 300)]),
          'e2': EdgeModel(id: 'e2', sourceId: 'B', targetId: 'C',
              waypoints: [const Offset(100, 300), const Offset(400, 300)]),
          'e3': EdgeModel(id: 'e3', sourceId: 'D', targetId: 'C',
              waypoints: [const Offset(100, 500), const Offset(300, 500), const Offset(300, 300), const Offset(400, 300)]),
        },
      );
      final bars = computeMergeBars(diagram);
      expect(bars.length, 1);
      expect(bars['C']!.edgeSlots.length, 3);
    });

    test('merge bar has correct number of edge slots', () {
      final diagram = DiagramModel(
        nodes: {
          'A': _task('A', 100, 100),
          'B': _task('B', 100, 300),
          'C': _task('C', 400, 200),
        },
        edges: {
          'e1': EdgeModel(id: 'e1', sourceId: 'A', targetId: 'C',
              waypoints: [const Offset(100, 100), const Offset(300, 100), const Offset(300, 200), const Offset(400, 200)]),
          'e2': EdgeModel(id: 'e2', sourceId: 'B', targetId: 'C',
              waypoints: [const Offset(100, 300), const Offset(300, 300), const Offset(300, 200), const Offset(400, 200)]),
        },
      );
      final bars = computeMergeBars(diagram);
      final bar = bars['C']!;
      expect(bar.edgeSlots.containsKey('e1'), isTrue);
      expect(bar.edgeSlots.containsKey('e2'), isTrue);
      expect(bar.edgeSlots.length, 2);
    });
  });

  group('merge bar position', () {
    test('bar on left side when edges approach from the left', () {
      // Both A and B are to the left of C.
      final diagram = DiagramModel(
        nodes: {
          'A': _task('A', 100, 100),
          'B': _task('B', 100, 300),
          'C': _task('C', 400, 200),
        },
        edges: {
          'e1': EdgeModel(id: 'e1', sourceId: 'A', targetId: 'C',
              waypoints: [const Offset(100, 100), const Offset(300, 200), const Offset(400, 200)]),
          'e2': EdgeModel(id: 'e2', sourceId: 'B', targetId: 'C',
              waypoints: [const Offset(100, 300), const Offset(300, 200), const Offset(400, 200)]),
        },
      );
      final bars = computeMergeBars(diagram);
      final bar = bars['C']!;
      expect(bar.side, ConnectorSide.left);
      expect(bar.isHorizontal, isFalse);
      // Bar should be to the left of the node's left edge.
      expect(bar.barPos, lessThan(400 - 70)); // 400 - halfWidth = 330
    });

    test('bar on top when edges approach from above', () {
      // Both A and B are above C.
      final diagram = DiagramModel(
        nodes: {
          'A': _task('A', 300, 100),
          'B': _task('B', 500, 100),
          'C': _task('C', 400, 400),
        },
        edges: {
          'e1': EdgeModel(id: 'e1', sourceId: 'A', targetId: 'C',
              waypoints: [const Offset(300, 100), const Offset(400, 300), const Offset(400, 400)]),
          'e2': EdgeModel(id: 'e2', sourceId: 'B', targetId: 'C',
              waypoints: [const Offset(500, 100), const Offset(400, 300), const Offset(400, 400)]),
        },
      );
      final bars = computeMergeBars(diagram);
      final bar = bars['C']!;
      expect(bar.side, ConnectorSide.top);
      expect(bar.isHorizontal, isTrue);
      // Bar should be above the node's top edge.
      expect(bar.barPos, lessThan(400 - 35)); // 400 - halfHeight = 365
    });

    test('bar width is half the node width for horizontal bars', () {
      final diagram = DiagramModel(
        nodes: {
          'A': _task('A', 300, 100),
          'B': _task('B', 500, 100),
          'C': _task('C', 400, 400),
        },
        edges: {
          'e1': EdgeModel(id: 'e1', sourceId: 'A', targetId: 'C',
              waypoints: [const Offset(300, 100), const Offset(400, 300), const Offset(400, 400)]),
          'e2': EdgeModel(id: 'e2', sourceId: 'B', targetId: 'C',
              waypoints: [const Offset(500, 100), const Offset(400, 300), const Offset(400, 400)]),
        },
      );
      final bars = computeMergeBars(diagram);
      final bar = bars['C']!;
      final barWidth = bar.maxCross - bar.minCross;
      // Task width is 140, bar should be half = 70.
      expect(barWidth, closeTo(70, 0.1));
    });

    test('bar width is half the node height for vertical bars', () {
      final diagram = DiagramModel(
        nodes: {
          'A': _task('A', 100, 100),
          'B': _task('B', 100, 300),
          'C': _task('C', 400, 200),
        },
        edges: {
          'e1': EdgeModel(id: 'e1', sourceId: 'A', targetId: 'C',
              waypoints: [const Offset(100, 100), const Offset(300, 200), const Offset(400, 200)]),
          'e2': EdgeModel(id: 'e2', sourceId: 'B', targetId: 'C',
              waypoints: [const Offset(100, 300), const Offset(300, 200), const Offset(400, 200)]),
        },
      );
      final bars = computeMergeBars(diagram);
      final bar = bars['C']!;
      final barHeight = bar.maxCross - bar.minCross;
      // Task height is 70, bar should be half = 35.
      expect(barHeight, closeTo(35, 0.1));
    });

    test('bar is centered on the node', () {
      final diagram = DiagramModel(
        nodes: {
          'A': _task('A', 300, 100),
          'B': _task('B', 500, 100),
          'C': _task('C', 400, 400),
        },
        edges: {
          'e1': EdgeModel(id: 'e1', sourceId: 'A', targetId: 'C',
              waypoints: [const Offset(300, 100), const Offset(400, 300), const Offset(400, 400)]),
          'e2': EdgeModel(id: 'e2', sourceId: 'B', targetId: 'C',
              waypoints: [const Offset(500, 100), const Offset(400, 300), const Offset(400, 400)]),
        },
      );
      final bars = computeMergeBars(diagram);
      final bar = bars['C']!;
      final barCenter = (bar.minCross + bar.maxCross) / 2;
      // C is at x=400, bar should be centered on 400.
      expect(barCenter, closeTo(400, 0.1));
    });

    test('bar offset is mergeBarOffset from node border', () {
      final diagram = DiagramModel(
        nodes: {
          'A': _task('A', 300, 100),
          'B': _task('B', 500, 100),
          'C': _task('C', 400, 400),
        },
        edges: {
          'e1': EdgeModel(id: 'e1', sourceId: 'A', targetId: 'C',
              waypoints: [const Offset(300, 100), const Offset(400, 300), const Offset(400, 400)]),
          'e2': EdgeModel(id: 'e2', sourceId: 'B', targetId: 'C',
              waypoints: [const Offset(500, 100), const Offset(400, 300), const Offset(400, 400)]),
        },
      );
      final bars = computeMergeBars(diagram);
      final bar = bars['C']!;
      // C top = 400 - 35 = 365. Bar should be at 365 - 25 = 340.
      expect(bar.barPos, closeTo(365 - mergeBarOffset, 0.1));
    });
  });

  group('edge slot ordering', () {
    test('slots are sorted left-to-right for horizontal bars', () {
      // A is left of B, both approach C from above via different x positions.
      final diagram = DiagramModel(
        nodes: {
          'A': _task('A', 200, 100),
          'B': _task('B', 600, 100),
          'C': _task('C', 400, 400),
        },
        edges: {
          'e1': EdgeModel(id: 'e1', sourceId: 'A', targetId: 'C',
              waypoints: [const Offset(200, 100), const Offset(300, 300), const Offset(400, 400)]),
          'e2': EdgeModel(id: 'e2', sourceId: 'B', targetId: 'C',
              waypoints: [const Offset(600, 100), const Offset(500, 300), const Offset(400, 400)]),
        },
      );
      final bars = computeMergeBars(diagram);
      final bar = bars['C']!;
      // e1 second-to-last at x=300, e2 second-to-last at x=500.
      // e1 slot should have smaller x than e2 slot.
      expect(bar.edgeSlots['e1']!.dx, lessThan(bar.edgeSlots['e2']!.dx));
    });

    test('slots are sorted top-to-bottom for vertical bars', () {
      // A is above B, both approach C from the left via different y positions.
      final diagram = DiagramModel(
        nodes: {
          'A': _task('A', 100, 100),
          'B': _task('B', 100, 400),
          'C': _task('C', 500, 250),
        },
        edges: {
          'e1': EdgeModel(id: 'e1', sourceId: 'A', targetId: 'C',
              waypoints: [const Offset(100, 100), const Offset(300, 150), const Offset(500, 250)]),
          'e2': EdgeModel(id: 'e2', sourceId: 'B', targetId: 'C',
              waypoints: [const Offset(100, 400), const Offset(300, 350), const Offset(500, 250)]),
        },
      );
      final bars = computeMergeBars(diagram);
      final bar = bars['C']!;
      // e1 second-to-last at y=150, e2 second-to-last at y=350.
      // e1 slot should have smaller y than e2 slot.
      expect(bar.edgeSlots['e1']!.dy, lessThan(bar.edgeSlots['e2']!.dy));
    });

    test('edge slots are evenly spaced across bar width', () {
      final diagram = DiagramModel(
        nodes: {
          'A': _task('A', 200, 100),
          'B': _task('B', 400, 100),
          'D': _task('D', 600, 100),
          'C': _task('C', 400, 400),
        },
        edges: {
          'e1': EdgeModel(id: 'e1', sourceId: 'A', targetId: 'C',
              waypoints: [const Offset(200, 100), const Offset(200, 300), const Offset(400, 400)]),
          'e2': EdgeModel(id: 'e2', sourceId: 'B', targetId: 'C',
              waypoints: [const Offset(400, 100), const Offset(400, 300), const Offset(400, 400)]),
          'e3': EdgeModel(id: 'e3', sourceId: 'D', targetId: 'C',
              waypoints: [const Offset(600, 100), const Offset(600, 300), const Offset(400, 400)]),
        },
      );
      final bars = computeMergeBars(diagram);
      final bar = bars['C']!;
      // 3 slots should be evenly distributed.
      final slots = bar.edgeSlots.values.toList()
        ..sort((a, b) => a.dx.compareTo(b.dx));
      final gap1 = slots[1].dx - slots[0].dx;
      final gap2 = slots[2].dx - slots[1].dx;
      expect(gap1, closeTo(gap2, 0.1));
    });
  });

  group('inferSide', () {
    test('approach from left', () {
      final node = _task('T', 400, 300);
      expect(inferSide(node, const Offset(200, 300)), ConnectorSide.left);
    });

    test('approach from right', () {
      final node = _task('T', 400, 300);
      expect(inferSide(node, const Offset(600, 300)), ConnectorSide.right);
    });

    test('approach from top', () {
      final node = _task('T', 400, 300);
      expect(inferSide(node, const Offset(400, 100)), ConnectorSide.top);
    });

    test('approach from bottom', () {
      final node = _task('T', 400, 300);
      expect(inferSide(node, const Offset(400, 500)), ConnectorSide.bottom);
    });

    test('diagonal approach from top-left goes to top when dy > dx', () {
      final node = _task('T', 400, 400);
      expect(inferSide(node, const Offset(380, 200)), ConnectorSide.top);
    });

    test('diagonal approach from top-left goes to left when dx > dy', () {
      final node = _task('T', 400, 400);
      expect(inferSide(node, const Offset(200, 380)), ConnectorSide.left);
    });
  });

  group('isPastBar', () {
    test('waypoint past top bar', () {
      final bar = MergeBarInfo(
        side: ConnectorSide.top,
        barPos: 300,
        minCross: 350,
        maxCross: 450,
        connectorNodePoint: const Offset(400, 365),
        nodeCenter: const Offset(400, 400),
        isHorizontal: true,
        edgeSlots: {},
      );
      expect(isPastBar(const Offset(400, 250), bar), isTrue);
      expect(isPastBar(const Offset(400, 300), bar), isTrue);
      expect(isPastBar(const Offset(400, 350), bar), isFalse);
    });

    test('waypoint past left bar', () {
      final bar = MergeBarInfo(
        side: ConnectorSide.left,
        barPos: 200,
        minCross: 250,
        maxCross: 350,
        connectorNodePoint: const Offset(330, 300),
        nodeCenter: const Offset(400, 300),
        isHorizontal: false,
        edgeSlots: {},
      );
      expect(isPastBar(const Offset(150, 300), bar), isTrue);
      expect(isPastBar(const Offset(200, 300), bar), isTrue);
      expect(isPastBar(const Offset(250, 300), bar), isFalse);
    });

    test('waypoint past bottom bar', () {
      final bar = MergeBarInfo(
        side: ConnectorSide.bottom,
        barPos: 500,
        minCross: 350,
        maxCross: 450,
        connectorNodePoint: const Offset(400, 435),
        nodeCenter: const Offset(400, 400),
        isHorizontal: true,
        edgeSlots: {},
      );
      expect(isPastBar(const Offset(400, 550), bar), isTrue);
      expect(isPastBar(const Offset(400, 500), bar), isTrue);
      expect(isPastBar(const Offset(400, 450), bar), isFalse);
    });

    test('waypoint past right bar', () {
      final bar = MergeBarInfo(
        side: ConnectorSide.right,
        barPos: 500,
        minCross: 250,
        maxCross: 350,
        connectorNodePoint: const Offset(470, 300),
        nodeCenter: const Offset(400, 300),
        isHorizontal: false,
        edgeSlots: {},
      );
      expect(isPastBar(const Offset(550, 300), bar), isTrue);
      expect(isPastBar(const Offset(500, 300), bar), isTrue);
      expect(isPastBar(const Offset(450, 300), bar), isFalse);
    });
  });

  group('adjustEdgeForMergeBar', () {
    test('final segment is perpendicular to horizontal bar', () {
      final bar = MergeBarInfo(
        side: ConnectorSide.top,
        barPos: 340,
        minCross: 365,
        maxCross: 435,
        connectorNodePoint: const Offset(400, 365),
        nodeCenter: const Offset(400, 400),
        isHorizontal: true,
        edgeSlots: {'e1': const Offset(400, 340)},
      );
      final rawWps = [
        const Offset(200, 100), // source center
        const Offset(200, 200), // intermediate
        const Offset(400, 200), // intermediate
        const Offset(400, 400), // target center
      ];
      final clippedStart = const Offset(200, 135); // clipped source

      final result = adjustEdgeForMergeBar(rawWps, clippedStart, bar, 'e1');

      // Last waypoint should be on the bar.
      expect(result.last.dy, closeTo(340, 0.1));
      // Last segment should be vertical (dx == 0).
      final lastSeg = result.last - result[result.length - 2];
      expect(lastSeg.dx.abs(), lessThan(1.0),
          reason: 'Final segment should be vertical for a horizontal bar');
    });

    test('final segment is perpendicular to vertical bar', () {
      final bar = MergeBarInfo(
        side: ConnectorSide.left,
        barPos: 305,
        minCross: 182.5,
        maxCross: 217.5,
        connectorNodePoint: const Offset(330, 200),
        nodeCenter: const Offset(400, 200),
        isHorizontal: false,
        edgeSlots: {'e1': const Offset(305, 200)},
      );
      final rawWps = [
        const Offset(100, 100), // source center
        const Offset(200, 100), // intermediate
        const Offset(200, 200), // intermediate
        const Offset(400, 200), // target center
      ];
      final clippedStart = const Offset(170, 100);

      final result = adjustEdgeForMergeBar(rawWps, clippedStart, bar, 'e1');

      // Last waypoint should be on the bar.
      expect(result.last.dx, closeTo(305, 0.1));
      // Last segment should be horizontal (dy == 0).
      final lastSeg = result.last - result[result.length - 2];
      expect(lastSeg.dy.abs(), lessThan(1.0),
          reason: 'Final segment should be horizontal for a vertical bar');
    });

    test('waypoints past bar are trimmed', () {
      final bar = MergeBarInfo(
        side: ConnectorSide.top,
        barPos: 340,
        minCross: 365,
        maxCross: 435,
        connectorNodePoint: const Offset(400, 365),
        nodeCenter: const Offset(400, 400),
        isHorizontal: true,
        edgeSlots: {'e1': const Offset(400, 340)},
      );
      // Edge has an inner waypoint that dips past the bar (y=320 < barPos=340).
      final rawWps = [
        const Offset(200, 100),
        const Offset(200, 500),  // inner: above bar, kept
        const Offset(400, 500),  // inner: above bar, kept
        const Offset(400, 320),  // inner: past bar (y < 340), should be trimmed
        const Offset(400, 400),  // target center (stripped by adjustEdge)
      ];
      final clippedStart = const Offset(200, 500);

      final result = adjustEdgeForMergeBar(rawWps, clippedStart, bar, 'e1');

      // The inner waypoint at y=320 should have been removed.
      // No inner waypoint should be past the bar.
      for (int i = 0; i < result.length - 1; i++) {
        expect(result[i].dy, greaterThanOrEqualTo(340),
            reason: 'Waypoint $i at y=${result[i].dy} should not be past the bar');
      }
      // Last point is the slot on the bar.
      expect(result.last.dy, closeTo(340, 0.1));
    });

    test('adjusted edge ends at the assigned slot position', () {
      final slotPos = const Offset(385, 340);
      final bar = MergeBarInfo(
        side: ConnectorSide.top,
        barPos: 340,
        minCross: 365,
        maxCross: 435,
        connectorNodePoint: const Offset(400, 365),
        nodeCenter: const Offset(400, 400),
        isHorizontal: true,
        edgeSlots: {'e1': slotPos},
      );
      final rawWps = [
        const Offset(200, 100),
        const Offset(300, 200),
        const Offset(400, 400),
      ];
      final clippedStart = const Offset(200, 135);

      final result = adjustEdgeForMergeBar(rawWps, clippedStart, bar, 'e1');

      expect(result.last.dx, closeTo(slotPos.dx, 0.1));
      expect(result.last.dy, closeTo(slotPos.dy, 0.1));
    });
  });

  group('multiple merge bars in one diagram', () {
    test('double diamond creates two merge bars', () {
      // GW -> A, GW -> B, A -> GW2, B -> GW2, GW2 -> C, GW2 -> D, C -> End, D -> End
      final diagram = DiagramModel(
        nodes: {
          'gw1': _gateway('gw1', 200, 300),
          'A': _task('A', 400, 170),
          'B': _task('B', 400, 430),
          'gw2': _gateway('gw2', 600, 300),
          'C': _task('C', 800, 170),
          'D': _task('D', 800, 430),
          'end': _task('end', 1000, 300),
        },
        edges: {
          'e1': EdgeModel(id: 'e1', sourceId: 'gw1', targetId: 'A',
              waypoints: [const Offset(200, 300), const Offset(300, 170), const Offset(400, 170)]),
          'e2': EdgeModel(id: 'e2', sourceId: 'gw1', targetId: 'B',
              waypoints: [const Offset(200, 300), const Offset(300, 430), const Offset(400, 430)]),
          'e3': EdgeModel(id: 'e3', sourceId: 'A', targetId: 'gw2',
              waypoints: [const Offset(400, 170), const Offset(500, 170), const Offset(500, 300), const Offset(600, 300)]),
          'e4': EdgeModel(id: 'e4', sourceId: 'B', targetId: 'gw2',
              waypoints: [const Offset(400, 430), const Offset(500, 430), const Offset(500, 300), const Offset(600, 300)]),
          'e5': EdgeModel(id: 'e5', sourceId: 'gw2', targetId: 'C',
              waypoints: [const Offset(600, 300), const Offset(700, 170), const Offset(800, 170)]),
          'e6': EdgeModel(id: 'e6', sourceId: 'gw2', targetId: 'D',
              waypoints: [const Offset(600, 300), const Offset(700, 430), const Offset(800, 430)]),
          'e7': EdgeModel(id: 'e7', sourceId: 'C', targetId: 'end',
              waypoints: [const Offset(800, 170), const Offset(900, 170), const Offset(900, 300), const Offset(1000, 300)]),
          'e8': EdgeModel(id: 'e8', sourceId: 'D', targetId: 'end',
              waypoints: [const Offset(800, 430), const Offset(900, 430), const Offset(900, 300), const Offset(1000, 300)]),
        },
      );
      final bars = computeMergeBars(diagram);
      // gw2 has 2 incoming (e3, e4), end has 2 incoming (e7, e8)
      expect(bars.length, 2);
      expect(bars.containsKey('gw2'), isTrue);
      expect(bars.containsKey('end'), isTrue);
    });
  });

  group('connector to node', () {
    test('connector point is on node border', () {
      final diagram = DiagramModel(
        nodes: {
          'A': _task('A', 200, 100),
          'B': _task('B', 600, 100),
          'C': _task('C', 400, 400),
        },
        edges: {
          'e1': EdgeModel(id: 'e1', sourceId: 'A', targetId: 'C',
              waypoints: [const Offset(200, 100), const Offset(400, 300), const Offset(400, 400)]),
          'e2': EdgeModel(id: 'e2', sourceId: 'B', targetId: 'C',
              waypoints: [const Offset(600, 100), const Offset(400, 300), const Offset(400, 400)]),
        },
      );
      final bars = computeMergeBars(diagram);
      final bar = bars['C']!;
      // Connector should be on the top edge of the task (y = 400 - 35 = 365).
      expect(bar.connectorNodePoint.dy, closeTo(365, 0.1));
      expect(bar.connectorNodePoint.dx, closeTo(400, 0.1));
    });

    test('connector for gateway hits diamond border', () {
      final diagram = DiagramModel(
        nodes: {
          'A': _task('A', 100, 100),
          'B': _task('B', 100, 400),
          'gw': _gateway('gw', 400, 250),
        },
        edges: {
          'e1': EdgeModel(id: 'e1', sourceId: 'A', targetId: 'gw',
              waypoints: [const Offset(100, 100), const Offset(300, 250), const Offset(400, 250)]),
          'e2': EdgeModel(id: 'e2', sourceId: 'B', targetId: 'gw',
              waypoints: [const Offset(100, 400), const Offset(300, 250), const Offset(400, 250)]),
        },
      );
      final bars = computeMergeBars(diagram);
      final bar = bars['gw']!;
      // Gateway center at (400, 250), left diamond point at (400-28, 250) = (372, 250).
      expect(bar.connectorNodePoint.dx, closeTo(372, 0.5));
      expect(bar.connectorNodePoint.dy, closeTo(250, 0.1));
    });
  });
}
