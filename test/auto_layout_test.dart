import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:bpmn_editor/diagram/edit/editor_controller.dart';
import 'package:bpmn_editor/diagram/model/diagram_model.dart';

/// Helper to build a diagram from a list of nodes and edges.
DiagramModel _buildDiagram(
    List<(String id, NodeType type, String name)> nodes,
    List<(String id, String src, String tgt, String name)> edges) {
  final nodeMap = <String, NodeModel>{};
  for (final (id, type, name) in nodes) {
    nodeMap[id] = NodeModel(
      id: id,
      type: type,
      name: name,
      rect: NodeModel.defaultRect(type, const Offset(0, 0)),
    );
  }
  final edgeMap = <String, EdgeModel>{};
  for (final (id, src, tgt, name) in edges) {
    edgeMap[id] = EdgeModel(id: id, sourceId: src, targetId: tgt, name: name);
  }
  return DiagramModel(nodes: nodeMap, edges: edgeMap);
}

/// Run autoLayout and return a map of node id → center position.
Map<String, Offset> _layout(DiagramModel diagram) {
  final ctrl = EditorController(diagram: diagram);
  ctrl.autoLayout();
  return {
    for (final e in ctrl.diagram.nodes.entries) e.key: e.value.center,
  };
}

/// Print the layout for visual inspection.
void _printLayout(Map<String, Offset> pos, DiagramModel diagram) {
  final sorted = pos.entries.toList()
    ..sort((a, b) {
      final cmp = a.value.dy.compareTo(b.value.dy);
      return cmp != 0 ? cmp : a.value.dx.compareTo(b.value.dx);
    });
  for (final e in sorted) {
    final node = diagram.nodes[e.key]!;
    print(
        '  ${e.key} (${node.type.name}) "${node.name}" → center(${e.value.dx}, ${e.value.dy})');
  }
}

void main() {
  // ──────────────────────────────────────────────────────────────
  // Test 1: Simple linear chain  S → A → B → E
  // ──────────────────────────────────────────────────────────────
  test('Linear chain: all nodes vertically aligned', () {
    final diagram = _buildDiagram([
      ('s', NodeType.startEvent, 'Start'),
      ('a', NodeType.task, 'Task A'),
      ('b', NodeType.task, 'Task B'),
      ('e', NodeType.endEvent, 'End'),
    ], [
      ('e1', 's', 'a', ''),
      ('e2', 'a', 'b', ''),
      ('e3', 'b', 'e', ''),
    ]);

    final pos = _layout(diagram);
    print('Test 1: Linear chain');
    _printLayout(pos, diagram);

    // All nodes should share the same x.
    expect(pos['s']!.dx, pos['a']!.dx);
    expect(pos['a']!.dx, pos['b']!.dx);
    expect(pos['b']!.dx, pos['e']!.dx);

    // Each node should be below the previous.
    expect(pos['s']!.dy, lessThan(pos['a']!.dy));
    expect(pos['a']!.dy, lessThan(pos['b']!.dy));
    expect(pos['b']!.dy, lessThan(pos['e']!.dy));
  });

  // ──────────────────────────────────────────────────────────────
  // Test 2: Diamond  S → G → A/B → M → E
  // ──────────────────────────────────────────────────────────────
  test('Diamond: gateway branches and merge', () {
    final diagram = _buildDiagram([
      ('s', NodeType.startEvent, 'Start'),
      ('g', NodeType.exclusiveGateway, 'Decision?'),
      ('a', NodeType.task, 'Path A'),
      ('b', NodeType.task, 'Path B'),
      ('m', NodeType.exclusiveGateway, 'Merge'),
      ('e', NodeType.endEvent, 'End'),
    ], [
      ('e1', 's', 'g', ''),
      ('e2', 'g', 'a', 'Yes'),
      ('e3', 'g', 'b', 'No'),
      ('e4', 'a', 'm', ''),
      ('e5', 'b', 'm', ''),
      ('e6', 'm', 'e', ''),
    ]);

    final pos = _layout(diagram);
    print('\nTest 2: Diamond');
    _printLayout(pos, diagram);

    // S, G, M, E should be vertically aligned (centered over branches).
    expect(pos['s']!.dx, pos['g']!.dx);
    expect(pos['g']!.dx, pos['m']!.dx);
    expect(pos['m']!.dx, pos['e']!.dx);

    // A and B should be on opposite sides of the center.
    expect(pos['a']!.dx, isNot(pos['b']!.dx));
    expect(pos['a']!.dy, pos['b']!.dy); // same row

    // Gateway between A and B horizontally.
    final center = pos['g']!.dx;
    expect((pos['a']!.dx + pos['b']!.dx) / 2, closeTo(center, 1.0));
  });

  // ──────────────────────────────────────────────────────────────
  // Test 3: Three-way split from gateway
  // ──────────────────────────────────────────────────────────────
  test('Three-way gateway split', () {
    final diagram = _buildDiagram([
      ('s', NodeType.startEvent, 'Start'),
      ('g', NodeType.exclusiveGateway, 'Three-way'),
      ('a', NodeType.task, 'Path A'),
      ('b', NodeType.task, 'Path B'),
      ('c', NodeType.task, 'Path C'),
      ('e', NodeType.endEvent, 'End'),
    ], [
      ('e1', 's', 'g', ''),
      ('e2', 'g', 'a', 'A'),
      ('e3', 'g', 'b', 'B'),
      ('e4', 'g', 'c', 'C'),
      ('e5', 'a', 'e', ''),
      ('e6', 'b', 'e', ''),
      ('e7', 'c', 'e', ''),
    ]);

    final pos = _layout(diagram);
    print('\nTest 3: Three-way split');
    _printLayout(pos, diagram);

    // A, B, C should all be at the same y (same layer).
    expect(pos['a']!.dy, pos['b']!.dy);
    expect(pos['b']!.dy, pos['c']!.dy);

    // All three should be distinct x positions.
    final xs = [pos['a']!.dx, pos['b']!.dx, pos['c']!.dx]..sort();
    expect(xs[0], lessThan(xs[1]));
    expect(xs[1], lessThan(xs[2]));

    // No overlap: minimum 140px apart (task width).
    expect(xs[1] - xs[0], greaterThanOrEqualTo(140));
    expect(xs[2] - xs[1], greaterThanOrEqualTo(140));

    // Gateway and End should be centered over the branches.
    final avgBranch = (xs[0] + xs[1] + xs[2]) / 3;
    expect(pos['g']!.dx, closeTo(avgBranch, 10));
    expect(pos['e']!.dx, closeTo(avgBranch, 10));
  });

  // ──────────────────────────────────────────────────────────────
  // Test 4: Sequential chain with branch (patient flow style)
  // ──────────────────────────────────────────────────────────────
  test('Patient flow: linear with one branch', () {
    final diagram = _buildDiagram([
      ('s', NodeType.startEvent, 'Patient Arrives'),
      ('t1', NodeType.task, 'Record Symptoms'),
      ('g', NodeType.exclusiveGateway, 'Severe?'),
      ('t2', NodeType.task, 'Emergency Care'),
      ('t3', NodeType.task, 'Prescribe Medication'),
      ('t4', NodeType.task, 'Discharge'),
      ('e', NodeType.endEvent, 'End'),
    ], [
      ('e1', 's', 't1', ''),
      ('e2', 't1', 'g', ''),
      ('e3', 'g', 't2', 'Yes'),
      ('e4', 'g', 't3', 'No'),
      ('e5', 't2', 't4', ''),
      ('e6', 't3', 't4', ''),
      ('e7', 't4', 'e', ''),
    ]);

    final pos = _layout(diagram);
    print('\nTest 4: Patient flow');
    _printLayout(pos, diagram);

    // S → T1 → G should be on a vertical line.
    expect(pos['s']!.dx, pos['t1']!.dx);
    expect(pos['t1']!.dx, pos['g']!.dx);

    // T2 and T3 should be at the same y, different x.
    expect(pos['t2']!.dy, pos['t3']!.dy);
    expect(pos['t2']!.dx, isNot(pos['t3']!.dx));

    // T4 and E should be centered between branches.
    expect(pos['t4']!.dx, pos['e']!.dx);
    expect(pos['t4']!.dx, closeTo(pos['g']!.dx, 10));

    // Vertical order.
    expect(pos['s']!.dy, lessThan(pos['t1']!.dy));
    expect(pos['t1']!.dy, lessThan(pos['g']!.dy));
    expect(pos['g']!.dy, lessThan(pos['t2']!.dy));
    expect(pos['t2']!.dy, lessThan(pos['t4']!.dy));
    expect(pos['t4']!.dy, lessThan(pos['e']!.dy));
  });

  // ──────────────────────────────────────────────────────────────
  // Test 5: No overlapping nodes
  // ──────────────────────────────────────────────────────────────
  test('No overlapping nodes in any test case', () {
    // Build a complex diagram.
    final diagram = _buildDiagram([
      ('s', NodeType.startEvent, 'Start'),
      ('g1', NodeType.exclusiveGateway, 'G1'),
      ('a', NodeType.task, 'A'),
      ('b', NodeType.task, 'B'),
      ('c', NodeType.task, 'C'),
      ('g2', NodeType.exclusiveGateway, 'G2'),
      ('d', NodeType.task, 'D'),
      ('e', NodeType.endEvent, 'End'),
    ], [
      ('e1', 's', 'g1', ''),
      ('e2', 'g1', 'a', 'X'),
      ('e3', 'g1', 'b', 'Y'),
      ('e4', 'g1', 'c', 'Z'),
      ('e5', 'a', 'g2', ''),
      ('e6', 'b', 'g2', ''),
      ('e7', 'c', 'g2', ''),
      ('e8', 'g2', 'd', ''),
      ('e9', 'd', 'e', ''),
    ]);

    final ctrl = EditorController(diagram: diagram);
    ctrl.autoLayout();

    final nodes = ctrl.diagram.nodes.values.toList();
    for (var i = 0; i < nodes.length; i++) {
      for (var j = i + 1; j < nodes.length; j++) {
        final a = nodes[i].rect;
        final b = nodes[j].rect;
        final overlaps = a.overlaps(b);
        if (overlaps) {
          fail(
              '${nodes[i].id} (${a.left},${a.top},${a.width},${a.height}) overlaps '
              '${nodes[j].id} (${b.left},${b.top},${b.width},${b.height})');
        }
      }
    }
  });

  // ──────────────────────────────────────────────────────────────
  // Test 6: Coordinates are clean multiples of 10
  // ──────────────────────────────────────────────────────────────
  test('All node centers are multiples of 10', () {
    final diagram = _buildDiagram([
      ('s', NodeType.startEvent, 'Start'),
      ('a', NodeType.task, 'A'),
      ('g', NodeType.exclusiveGateway, 'G'),
      ('b', NodeType.task, 'B'),
      ('c', NodeType.task, 'C'),
      ('e', NodeType.endEvent, 'End'),
    ], [
      ('e1', 's', 'a', ''),
      ('e2', 'a', 'g', ''),
      ('e3', 'g', 'b', 'Y'),
      ('e4', 'g', 'c', 'N'),
      ('e5', 'b', 'e', ''),
      ('e6', 'c', 'e', ''),
    ]);

    final pos = _layout(diagram);
    for (final entry in pos.entries) {
      expect(entry.value.dx % 10, 0.0,
          reason: '${entry.key} x=${entry.value.dx} not multiple of 10');
      expect(entry.value.dy % 10, 0.0,
          reason: '${entry.key} y=${entry.value.dy} not multiple of 10');
    }
  });

  // ──────────────────────────────────────────────────────────────
  // Test 7: Nested diamonds (branch within a branch)
  // ──────────────────────────────────────────────────────────────
  test('Nested diamond: branch inside branch', () {
    // S → G1 → (A → G2 → (X,Y) → M2 → C) / B → M1 → E
    final diagram = _buildDiagram([
      ('s', NodeType.startEvent, 'Start'),
      ('g1', NodeType.exclusiveGateway, 'G1'),
      ('a', NodeType.task, 'A'),
      ('b', NodeType.task, 'B'),
      ('g2', NodeType.exclusiveGateway, 'G2'),
      ('x', NodeType.task, 'X'),
      ('y', NodeType.task, 'Y'),
      ('m2', NodeType.exclusiveGateway, 'M2'),
      ('c', NodeType.task, 'C'),
      ('m1', NodeType.exclusiveGateway, 'M1'),
      ('e', NodeType.endEvent, 'End'),
    ], [
      ('e1', 's', 'g1', ''),
      ('e2', 'g1', 'a', 'L'),
      ('e3', 'g1', 'b', 'R'),
      ('e4', 'a', 'g2', ''),
      ('e5', 'g2', 'x', 'L'),
      ('e6', 'g2', 'y', 'R'),
      ('e7', 'x', 'm2', ''),
      ('e8', 'y', 'm2', ''),
      ('e9', 'm2', 'c', ''),
      ('e10', 'c', 'm1', ''),
      ('e11', 'b', 'm1', ''),
      ('e12', 'm1', 'e', ''),
    ]);

    final pos = _layout(diagram);
    print('\nTest 7b: Nested diamond');
    _printLayout(pos, diagram);

    // No overlaps.
    final nodes = diagram.nodes.values.toList();
    for (var i = 0; i < nodes.length; i++) {
      for (var j = i + 1; j < nodes.length; j++) {
        expect(nodes[i].rect.overlaps(nodes[j].rect), isFalse,
            reason: '${nodes[i].id} overlaps ${nodes[j].id}');
      }
    }

    // X and Y at same row, different x.
    expect(pos['x']!.dy, pos['y']!.dy);
    expect(pos['x']!.dx, isNot(pos['y']!.dx));

    // A and B at same row, different x.
    expect(pos['a']!.dy, pos['b']!.dy);
    expect(pos['a']!.dx, isNot(pos['b']!.dx));
  });

  // ──────────────────────────────────────────────────────────────
  // Test 8: Long sequential chain with one side branch
  // ──────────────────────────────────────────────────────────────
  test('Long chain with side branch stays mostly vertical', () {
    final diagram = _buildDiagram([
      ('s', NodeType.startEvent, 'Start'),
      ('t1', NodeType.task, 'Step 1'),
      ('t2', NodeType.task, 'Step 2'),
      ('g', NodeType.exclusiveGateway, 'Check'),
      ('t3', NodeType.task, 'Side Path'),
      ('t4', NodeType.task, 'Main Path'),
      ('m', NodeType.exclusiveGateway, 'Rejoin'),
      ('t5', NodeType.task, 'Step 5'),
      ('t6', NodeType.task, 'Step 6'),
      ('e', NodeType.endEvent, 'End'),
    ], [
      ('e1', 's', 't1', ''),
      ('e2', 't1', 't2', ''),
      ('e3', 't2', 'g', ''),
      ('e4', 'g', 't3', 'A'),
      ('e5', 'g', 't4', 'B'),
      ('e6', 't3', 'm', ''),
      ('e7', 't4', 'm', ''),
      ('e8', 'm', 't5', ''),
      ('e9', 't5', 't6', ''),
      ('e10', 't6', 'e', ''),
    ]);

    final pos = _layout(diagram);
    print('\nTest 8: Long chain with side branch');
    _printLayout(pos, diagram);

    // S, T1, T2, G should be vertically aligned.
    expect(pos['s']!.dx, pos['t1']!.dx);
    expect(pos['t1']!.dx, pos['t2']!.dx);
    expect(pos['t2']!.dx, pos['g']!.dx);

    // M, T5, T6, E should be vertically aligned.
    expect(pos['m']!.dx, pos['t5']!.dx);
    expect(pos['t5']!.dx, pos['t6']!.dx);
    expect(pos['t6']!.dx, pos['e']!.dx);

    // G and M should be at the same x (centered over branches).
    expect(pos['g']!.dx, pos['m']!.dx);
  });

  // ──────────────────────────────────────────────────────────────
  // Test 9: Complex patient flow (from user's AI-generated diagram)
  // ──────────────────────────────────────────────────────────────
  test('Complex patient flow with multiple merge points', () {
    final diagram = _buildDiagram([
      ('n1', NodeType.startEvent, 'Patient Arrives'),
      ('n3', NodeType.task, 'Perform Initial Examination'),
      ('n4', NodeType.exclusiveGateway, 'Symptoms Severe?'),
      ('n5', NodeType.task, 'Order Lab Tests'),
      ('n8', NodeType.task, 'Recommend Rest'),
      ('n9', NodeType.task, 'Monitor Vital Signs'),
      ('n10', NodeType.task, 'Provide Emergency Care'),
      ('n11', NodeType.exclusiveGateway, 'Test Results?'),
      ('n12', NodeType.task, 'Analyze Test Results'),
      ('n13', NodeType.task, 'Update Diagnosis'),
      ('n14', NodeType.task, 'Discharge Patient'),
      ('n15', NodeType.endEvent, 'End'),
    ], [
      ('e1', 'n1', 'n3', ''),
      ('e3', 'n3', 'n4', ''),
      ('e4', 'n4', 'n5', 'Yes'),
      ('e5', 'n4', 'n8', 'No'),
      ('e9', 'n8', 'n9', ''),
      ('e10', 'n9', 'n10', ''),
      ('e6', 'n5', 'n11', ''),
      ('e11', 'n10', 'n11', ''),
      ('e12', 'n11', 'n12', 'Positive'),
      ('e13', 'n11', 'n15', 'Negative'),
      ('e14', 'n12', 'n13', ''),
      ('e15', 'n13', 'n14', ''),
    ]);

    final pos = _layout(diagram);
    print('\nTest 9: Complex patient flow');
    _printLayout(pos, diagram);

    // N1 → N3 → N4 should be vertically aligned.
    expect(pos['n1']!.dx, pos['n3']!.dx);
    expect(pos['n3']!.dx, pos['n4']!.dx);

    // N5 and N8 should be at same y (branches from gateway).
    expect(pos['n5']!.dy, pos['n8']!.dy);
    expect(pos['n5']!.dx, isNot(pos['n8']!.dx));

    // N11 (merge node) should be centered between its parents.
    final n5x = pos['n5']!.dx;
    final n10x = pos['n10']!.dx;
    expect(pos['n11']!.dx, closeTo((n5x + n10x) / 2, 10));

    // No overlaps.
    final nodes = diagram.nodes.values.toList();
    for (var i = 0; i < nodes.length; i++) {
      for (var j = i + 1; j < nodes.length; j++) {
        expect(nodes[i].rect.overlaps(nodes[j].rect), isFalse,
            reason: '${nodes[i].id} overlaps ${nodes[j].id}');
      }
    }
  });

  // ──────────────────────────────────────────────────────────────
  // Test 10: Orphan nodes don't crash
  // ──────────────────────────────────────────────────────────────
  test('Orphan nodes are placed without crashing', () {
    final diagram = _buildDiagram([
      ('s', NodeType.startEvent, 'Start'),
      ('a', NodeType.task, 'Connected'),
      ('orphan', NodeType.task, 'Orphan'),
      ('e', NodeType.endEvent, 'End'),
    ], [
      ('e1', 's', 'a', ''),
      ('e2', 'a', 'e', ''),
    ]);

    final pos = _layout(diagram);
    print('\nTest 7: Orphan node');
    _printLayout(pos, diagram);

    // Orphan should exist and not overlap.
    expect(pos.containsKey('orphan'), isTrue);
    final orphanRect = diagram.nodes['orphan']!.rect;
    for (final node in diagram.nodes.values) {
      if (node.id == 'orphan') continue;
      expect(orphanRect.overlaps(node.rect), isFalse,
          reason: 'Orphan overlaps ${node.id}');
    }
  });
}
