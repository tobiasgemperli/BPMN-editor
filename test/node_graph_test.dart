import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:bpmn_editor/diagram/io/node_graph.dart';
import 'package:bpmn_editor/diagram/model/diagram_model.dart';

void main() {
  // Trimmed copy of the real `getmodel/8` Nodes payload (legacy flow format,
  // empty BpmnXml). Chain: start(1)->2->3->9->10->11->12->15->stop(24).
  final linear = jsonDecode('''
  [
    {"Type":4,"Id":1,"ConnectToId":1},
    {"Type":0,"Id":2,"ConnectToId":2,"IdInput":1,"Text":"Align Team Goal"},
    {"Type":0,"Id":3,"ConnectToId":3,"IdInput":2,"Text":"Build Trust"},
    {"Type":0,"Id":9,"ConnectToId":4,"IdInput":3,"Text":"Present Plan"},
    {"Type":0,"Id":10,"ConnectToId":5,"IdInput":4,"Text":"Meet Regularly"},
    {"Type":0,"Id":11,"ConnectToId":6,"IdInput":5,"Text":"Track Efficiency"},
    {"Type":0,"Id":12,"ConnectToId":7,"IdInput":6,"Text":"Support Team"},
    {"Type":0,"Id":15,"ConnectToId":8,"IdInput":7,"Text":"Select Leaders"},
    {"Type":5,"Id":24,"IdInput":8,"StopType":1}
  ]
  ''') as List;

  test('reconstructs the linear chain: 9 nodes, 8 edges', () {
    final d = diagramFromNodes(linear);
    expect(d.nodes.length, 9);
    expect(d.edges.length, 8);
  });

  test('maps server types and links via connection ids', () {
    final d = diagramFromNodes(linear);
    expect(d.nodes['1']!.type, NodeType.startEvent);
    expect(d.nodes['2']!.type, NodeType.task);
    expect(d.nodes['24']!.type, NodeType.endEvent);
    expect(d.outgoingEdges('1').single.targetId, '2');
    expect(d.outgoingEdges('15').single.targetId, '24');
    expect(d.outgoingEdges('24'), isEmpty);
  });

  test('decision nodes fan out with branch labels, -1 dropped', () {
    final decision = jsonDecode('''
    [
      {"Type":4,"Id":1,"ConnectToId":1},
      {"Type":1,"Id":2,"IdInput":1,"ConnectToIds":[2,3,-1],
       "DescOutputs":["No","Yes",""],"Text":"Safe?"},
      {"Type":0,"Id":3,"IdInput":2,"ConnectToId":9,"Text":"Handle No"},
      {"Type":0,"Id":4,"IdInput":3,"ConnectToId":9,"Text":"Handle Yes"},
      {"Type":5,"Id":5,"IdInput":9,"StopType":1}
    ]
    ''') as List;
    final d = diagramFromNodes(decision);
    expect(d.nodes['2']!.type, NodeType.exclusiveGateway);
    final branches = d.outgoingEdges('2');
    expect(branches.length, 2);
    expect(branches.map((e) => e.targetId).toSet(), {'3', '4'});
    expect(branches.map((e) => e.name).toSet(), {'No', 'Yes'});
    expect(d.incomingEdges('5').length, 2);
  });

  test('start is topmost, stop is below it (vertical layout); empty is safe', () {
    final d = diagramFromNodes(linear);
    final startY = d.nodes['1']!.center.dy;
    for (final n in d.nodes.values) {
      expect(n.center.dy, greaterThanOrEqualTo(startY));
    }
    expect(d.nodes['24']!.center.dy, greaterThan(startY));
    expect(diagramFromNodes(const []).nodes, isEmpty);
  });
}
