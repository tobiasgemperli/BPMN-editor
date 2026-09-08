import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bpmn_editor/diagram/model/diagram_model.dart';
import 'package:bpmn_editor/diagram/render/diagram_rasterizer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('rasterizes a diagram to a valid PNG', () async {
    final d = DiagramModel();
    d.nodes['a'] = NodeModel(
        id: 'a', type: NodeType.startEvent, rect: const Rect.fromLTWH(0, 0, 40, 40));
    d.nodes['b'] = NodeModel(
        id: 'b', type: NodeType.task, rect: const Rect.fromLTWH(0, 120, 120, 60));
    d.edges['e'] = EdgeModel(id: 'e', sourceId: 'a', targetId: 'b');

    final png = await rasterizeDiagramPng(d, width: 240, height: 180);
    expect(png, isNotNull);
    expect(png!.length, greaterThan(100));
    // PNG magic number.
    expect(png.sublist(0, 4), [0x89, 0x50, 0x4E, 0x47]);
  });

  test('returns null for an empty diagram', () async {
    expect(await rasterizeDiagramPng(DiagramModel()), isNull);
  });
}
