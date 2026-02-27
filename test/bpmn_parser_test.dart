import 'dart:io';
import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:bpmn_editor/diagram/io/bpmn_parser.dart';
import 'package:bpmn_editor/diagram/model/diagram_model.dart';

void main() {
  late String sampleXml;

  setUpAll(() {
    sampleXml = File('test/resources/sample.bpmn').readAsStringSync();
  });

  group('BpmnParser', () {
    test('parses nodes from sample BPMN', () {
      final parser = BpmnParser();
      final model = parser.parse(sampleXml);

      expect(model.nodes.length, 6);
      expect(model.nodes['start_1']?.type, NodeType.startEvent);
      expect(model.nodes['task_1']?.type, NodeType.task);
      expect(model.nodes['gateway_1']?.type, NodeType.exclusiveGateway);
      expect(model.nodes['task_2']?.type, NodeType.task);
      expect(model.nodes['task_3']?.type, NodeType.task);
      expect(model.nodes['end_1']?.type, NodeType.endEvent);
    });

    test('parses node names', () {
      final parser = BpmnParser();
      final model = parser.parse(sampleXml);

      expect(model.nodes['start_1']?.name, 'Begin');
      expect(model.nodes['task_1']?.name, 'Review Document');
      expect(model.nodes['gateway_1']?.name, 'Approved?');
    });

    test('parses edges from sample BPMN', () {
      final parser = BpmnParser();
      final model = parser.parse(sampleXml);

      expect(model.edges.length, 6);
      expect(model.edges['flow_1']?.sourceId, 'start_1');
      expect(model.edges['flow_1']?.targetId, 'task_1');
      expect(model.edges['flow_3']?.name, 'Yes');
      expect(model.edges['flow_4']?.name, 'No');
    });

    test('parses DI bounds for shapes', () {
      final parser = BpmnParser();
      final model = parser.parse(sampleXml);

      final start = model.nodes['start_1']!;
      expect(start.rect.left, 100);
      expect(start.rect.top, 200);
      expect(start.rect.width, 48);
      expect(start.rect.height, 48);

      final task = model.nodes['task_1']!;
      expect(task.rect.left, 230);
      expect(task.rect.width, 140);
    });

    test('parses DI waypoints for edges', () {
      final parser = BpmnParser();
      final model = parser.parse(sampleXml);

      final flow1 = model.edges['flow_1']!;
      expect(flow1.waypoints.length, 2);
      expect(flow1.waypoints[0].dx, 148);

      final flow4 = model.edges['flow_4']!;
      expect(flow4.waypoints.length, 3);
    });

    test('parses process and definitions IDs', () {
      final parser = BpmnParser();
      final model = parser.parse(sampleXml);

      expect(model.definitionsId, 'Definitions_1');
      expect(model.processId, 'Process_1');
    });

    test('auto-layouts nodes when DI is missing', () {
      const noDiXml = '''<?xml version="1.0" encoding="UTF-8"?>
<bpmn:definitions xmlns:bpmn="http://www.omg.org/spec/BPMN/20100524/MODEL"
                  id="Def_1" targetNamespace="http://example.com">
  <bpmn:process id="P1" isExecutable="false">
    <bpmn:startEvent id="s1"/>
    <bpmn:task id="t1" name="Do something"/>
    <bpmn:endEvent id="e1"/>
  </bpmn:process>
</bpmn:definitions>''';

      final parser = BpmnParser();
      final model = parser.parse(noDiXml);

      expect(model.nodes.length, 3);
      // All nodes should have non-zero rects from auto-layout.
      for (final node in model.nodes.values) {
        expect(node.rect, isNot(equals(Rect.zero)));
      }
    });

    test('ignores unsupported elements without crashing', () {
      const xmlWithUnsupported = '''<?xml version="1.0" encoding="UTF-8"?>
<bpmn:definitions xmlns:bpmn="http://www.omg.org/spec/BPMN/20100524/MODEL"
                  id="Def_1" targetNamespace="http://example.com">
  <bpmn:process id="P1" isExecutable="false">
    <bpmn:startEvent id="s1"/>
    <bpmn:subProcess id="sub1" name="Subprocess"/>
    <bpmn:intermediateCatchEvent id="ice1"/>
    <bpmn:task id="t1"/>
    <bpmn:endEvent id="e1"/>
    <bpmn:sequenceFlow id="f1" sourceRef="s1" targetRef="t1"/>
  </bpmn:process>
</bpmn:definitions>''';

      final parser = BpmnParser();
      final model = parser.parse(xmlWithUnsupported);

      // Only supported elements are parsed.
      expect(model.nodes.length, 3);
      expect(model.edges.length, 1);
    });
  });
}
