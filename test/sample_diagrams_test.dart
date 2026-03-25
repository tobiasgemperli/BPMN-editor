import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:bpmn_editor/diagram/samples/sample_diagrams.dart';

void main() {
  group('Sample diagrams — no diagonal edges', () {
    for (final sample in SampleDiagrams.all) {
      test('${sample.name}: all edge segments are axis-aligned', () {
        final diagram = sample.builder();

        for (final edge in diagram.edges.values) {
          final source = diagram.nodes[edge.sourceId]!;
          final target = diagram.nodes[edge.targetId]!;

          final wps = edge.waypoints.isNotEmpty
              ? edge.waypoints
              : [source.rect.center, target.rect.center];

          for (int i = 0; i < wps.length - 1; i++) {
            final a = wps[i];
            final b = wps[i + 1];
            final sameX = (a.dx - b.dx).abs() < 0.1;
            final sameY = (a.dy - b.dy).abs() < 0.1;

            expect(
              sameX || sameY,
              isTrue,
              reason: '${sample.name} edge ${edge.id} segment $i→${i + 1} '
                  'is diagonal: ($a) → ($b). '
                  'Add waypoints to route it as an L-shape.',
            );
          }
        }
      });
    }
  });
}
