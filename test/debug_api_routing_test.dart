import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:bpmn_editor/diagram/samples/sample_diagrams.dart';
import 'package:bpmn_editor/diagram/render/merge_bar.dart';

void main() {
  group('Debug API 500 — edge routing', () {
    late final diagram = SampleDiagrams.technicalDebugging();
    late final mergeBars = computeMergeBars(diagram);

    test('merge bars are computed correctly', () {
      // Print all merge bars for analysis.
      for (final entry in mergeBars.entries) {
        final bar = entry.value;
        final node = diagram.nodes[entry.key]!;
        print('MergeBar on ${node.name}(${entry.key}): '
            'side=${bar.side} barPos=${bar.barPos} '
            'slots=${bar.edgeSlots}');
      }
    });

    /// Simulate the rendering pipeline from DiagramPainter._drawEdges
    /// to get the final adjustedWps for each edge.
    List<Offset> computeAdjustedWps(String edgeId) {
      final edge = diagram.edges[edgeId]!;
      final source = diagram.nodes[edge.sourceId]!;
      final target = diagram.nodes[edge.targetId]!;

      final wps = edge.waypoints.isNotEmpty
          ? edge.waypoints
          : [source.center, target.center];

      final clippedStart = clipToNodeBorder(source, wps[1]);
      final mergeBar = mergeBars[edge.targetId];

      if (mergeBar != null) {
        return adjustEdgeForMergeBar(
          wps, clippedStart, mergeBar, edgeId,
          obstacles: diagram.nodes.values.toList(),
          sourceId: edge.sourceId,
          targetId: edge.targetId,
        );
      } else {
        final clippedEnd = clipToNodeBorder(target, wps[wps.length - 2]);
        return [clippedStart, ...wps.sublist(1, wps.length - 1), clippedEnd];
      }
    }

    int countBends(List<Offset> wps) => wps.length - 2;

    void checkAxisAligned(List<Offset> wps, String label) {
      for (int i = 0; i < wps.length - 1; i++) {
        final a = wps[i];
        final b = wps[i + 1];
        final sameX = (a.dx - b.dx).abs() < 0.5;
        final sameY = (a.dy - b.dy).abs() < 0.5;
        expect(sameX || sameY, isTrue,
            reason: '$label segment $i→${i + 1} is diagonal: $a → $b');
      }
    }

    // ── Gateway outgoing edges ──────────────────────────────────

    test('e4 (Database) has exactly 1 bend', () {
      final wps = computeAdjustedWps('e4');
      print('e4 adjustedWps: $wps');
      checkAxisAligned(wps, 'e4');
      expect(countBends(wps), equals(1),
          reason: 'e4 should have 1 bend (L-shape), got ${countBends(wps)}: $wps');
    });

    test('e5 (Auth) has exactly 0 bends', () {
      final wps = computeAdjustedWps('e5');
      print('e5 adjustedWps: $wps');
      checkAxisAligned(wps, 'e5');
      expect(countBends(wps), equals(0),
          reason: 'e5 should be straight (0 bends), got ${countBends(wps)}: $wps');
    });

    test('e6 (Timeout) has exactly 1 bend', () {
      final wps = computeAdjustedWps('e6');
      print('e6 adjustedWps: $wps');
      checkAxisAligned(wps, 'e6');
      expect(countBends(wps), equals(1),
          reason: 'e6 should have 1 bend (L-shape), got ${countBends(wps)}: $wps');
    });

    // ── Merge edges into Verify Fix ─────────────────────────────

    test('e10 (Fix Query → Verify Fix) has at most 1 bend', () {
      final wps = computeAdjustedWps('e10');
      print('e10 adjustedWps: $wps');
      checkAxisAligned(wps, 'e10');
      expect(countBends(wps), lessThanOrEqualTo(1),
          reason: 'e10 should have ≤1 bend, got ${countBends(wps)}: $wps');
    });

    test('e11 (Fix Auth → Verify Fix) has 0 bends', () {
      final wps = computeAdjustedWps('e11');
      print('e11 adjustedWps: $wps');
      checkAxisAligned(wps, 'e11');
      expect(countBends(wps), equals(0),
          reason: 'e11 should be straight, got ${countBends(wps)}: $wps');
    });

    test('e12 (Optimize → Verify Fix) has at most 1 bend', () {
      final wps = computeAdjustedWps('e12');
      print('e12 adjustedWps: $wps');
      checkAxisAligned(wps, 'e12');
      expect(countBends(wps), lessThanOrEqualTo(1),
          reason: 'e12 should have ≤1 bend, got ${countBends(wps)}: $wps');
    });

    // ── All edges: no diagonals ─────────────────────────────────

    test('all edges are axis-aligned', () {
      for (final edge in diagram.edges.values) {
        final wps = computeAdjustedWps(edge.id);
        checkAxisAligned(wps, '${edge.id}(${edge.name})');
        print('${edge.id}(${edge.name}): ${wps.length} points, '
            '${countBends(wps)} bends → $wps');
      }
    });
  });
}
