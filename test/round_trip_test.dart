import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:bpmn_editor/diagram/io/bpmn_parser.dart';
import 'package:bpmn_editor/diagram/io/bpmn_serializer.dart';

void main() {
  group('Round-trip', () {
    test('import -> export -> import preserves structure', () {
      final sampleXml = File('test/resources/sample.bpmn').readAsStringSync();

      // First import.
      final parser = BpmnParser();
      final model1 = parser.parse(sampleXml);

      // Export.
      final serializer = BpmnSerializer();
      final exportedXml = serializer.serialize(model1);

      // Second import.
      final model2 = parser.parse(exportedXml);

      // Verify same number of nodes and edges.
      expect(model2.nodes.length, model1.nodes.length);
      expect(model2.edges.length, model1.edges.length);

      // Verify all node IDs are preserved.
      for (final id in model1.nodes.keys) {
        expect(model2.nodes.containsKey(id), isTrue,
            reason: 'Node $id should be preserved');
        expect(model2.nodes[id]!.type, model1.nodes[id]!.type,
            reason: 'Node $id type should be preserved');
        expect(model2.nodes[id]!.name, model1.nodes[id]!.name,
            reason: 'Node $id name should be preserved');
      }

      // Verify all edge IDs and connections are preserved.
      for (final id in model1.edges.keys) {
        expect(model2.edges.containsKey(id), isTrue,
            reason: 'Edge $id should be preserved');
        expect(model2.edges[id]!.sourceId, model1.edges[id]!.sourceId);
        expect(model2.edges[id]!.targetId, model1.edges[id]!.targetId);
      }

      // Verify node positions are roughly preserved (within floating point tolerance).
      for (final id in model1.nodes.keys) {
        final r1 = model1.nodes[id]!.rect;
        final r2 = model2.nodes[id]!.rect;
        expect((r2.left - r1.left).abs(), lessThan(1.0),
            reason: 'Node $id x should be preserved');
        expect((r2.top - r1.top).abs(), lessThan(1.0),
            reason: 'Node $id y should be preserved');
        expect((r2.width - r1.width).abs(), lessThan(1.0),
            reason: 'Node $id width should be preserved');
      }
    });
  });
}
