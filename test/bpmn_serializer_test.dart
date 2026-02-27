import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:bpmn_editor/diagram/io/bpmn_serializer.dart';
import 'package:bpmn_editor/diagram/model/diagram_model.dart';

void main() {
  group('BpmnSerializer', () {
    test('generates valid BPMN XML with all node types', () {
      final model = _buildSampleModel();
      final serializer = BpmnSerializer();
      final xml = serializer.serialize(model);

      expect(xml, contains('bpmn:startEvent'));
      expect(xml, contains('bpmn:task'));
      expect(xml, contains('bpmn:exclusiveGateway'));
      expect(xml, contains('bpmn:endEvent'));
      expect(xml, contains('bpmn:sequenceFlow'));
    });

    test('includes BPMN-DI shapes and edges', () {
      final model = _buildSampleModel();
      final serializer = BpmnSerializer();
      final xml = serializer.serialize(model);

      expect(xml, contains('bpmndi:BPMNDiagram'));
      expect(xml, contains('bpmndi:BPMNPlane'));
      expect(xml, contains('bpmndi:BPMNShape'));
      expect(xml, contains('bpmndi:BPMNEdge'));
      expect(xml, contains('dc:Bounds'));
      expect(xml, contains('di:waypoint'));
    });

    test('preserves node IDs and names', () {
      final model = _buildSampleModel();
      final serializer = BpmnSerializer();
      final xml = serializer.serialize(model);

      expect(xml, contains('id="start_1"'));
      expect(xml, contains('id="task_1"'));
      expect(xml, contains('name="Review"'));
      expect(xml, contains('id="flow_1"'));
    });

    test('includes required namespaces', () {
      final model = _buildSampleModel();
      final serializer = BpmnSerializer();
      final xml = serializer.serialize(model);

      expect(xml, contains('xmlns:bpmn='));
      expect(xml, contains('xmlns:bpmndi='));
      expect(xml, contains('xmlns:dc='));
      expect(xml, contains('xmlns:di='));
    });

    test('includes bounds with correct dimensions', () {
      final model = _buildSampleModel();
      final serializer = BpmnSerializer();
      final xml = serializer.serialize(model);

      // Check that start event bounds are present.
      expect(xml, contains('x="76.0"'));
      expect(xml, contains('width="48.0"'));
    });
  });
}

DiagramModel _buildSampleModel() {
  final model = DiagramModel(processId: 'process_1', definitionsId: 'def_1');

  model.nodes['start_1'] = NodeModel(
    id: 'start_1',
    type: NodeType.startEvent,
    rect: Rect.fromCenter(center: const Offset(100, 200), width: 48, height: 48),
  );
  model.nodes['task_1'] = NodeModel(
    id: 'task_1',
    type: NodeType.task,
    name: 'Review',
    rect: Rect.fromCenter(center: const Offset(300, 200), width: 140, height: 70),
  );
  model.nodes['gateway_1'] = NodeModel(
    id: 'gateway_1',
    type: NodeType.exclusiveGateway,
    name: 'OK?',
    rect: Rect.fromCenter(center: const Offset(500, 200), width: 56, height: 56),
  );
  model.nodes['end_1'] = NodeModel(
    id: 'end_1',
    type: NodeType.endEvent,
    rect: Rect.fromCenter(center: const Offset(700, 200), width: 48, height: 48),
  );

  model.edges['flow_1'] = EdgeModel(
    id: 'flow_1',
    sourceId: 'start_1',
    targetId: 'task_1',
    waypoints: [const Offset(124, 200), const Offset(230, 200)],
  );
  model.edges['flow_2'] = EdgeModel(
    id: 'flow_2',
    sourceId: 'task_1',
    targetId: 'gateway_1',
  );
  model.edges['flow_3'] = EdgeModel(
    id: 'flow_3',
    sourceId: 'gateway_1',
    targetId: 'end_1',
  );

  return model;
}
