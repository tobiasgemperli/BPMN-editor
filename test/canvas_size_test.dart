import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bpmn_editor/app/widgets/diagram_canvas.dart';
import 'package:bpmn_editor/diagram/edit/editor_controller.dart';
import 'package:bpmn_editor/diagram/model/diagram_model.dart';
import 'package:bpmn_editor/diagram/render/diagram_painter.dart';

/// The canvas must size to content (not a fixed 8000×8000 raster) yet still
/// cover every node so nothing is clipped.
CustomPaint _diagramPaint(WidgetTester tester) => tester
    .widgetList<CustomPaint>(find.byType(CustomPaint))
    .firstWhere((c) => c.painter is DiagramPainter);

void main() {
  testWidgets('canvas sizes to content, not 8000, and covers all nodes',
      (tester) async {
    final d = DiagramModel();
    d.nodes['a'] = NodeModel(
        id: 'a', type: NodeType.task, name: 'A',
        rect: const Rect.fromLTWH(100, 200, 140, 70));
    d.nodes['b'] = NodeModel(
        id: 'b', type: NodeType.task, name: 'B',
        rect: const Rect.fromLTWH(300, 600, 140, 70));
    final ctrl = EditorController(diagram: d);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: DiagramCanvas(
          controller: ctrl,
          transformationController: TransformationController(),
        ),
      ),
    ));
    await tester.pump();

    final size = _diagramPaint(tester).size;
    // Much smaller than the old fixed surface.
    expect(size.width, lessThan(8000));
    expect(size.height, lessThan(8000));
    // Content (bottom-right 440,670) + the 2000 canvas offset must be inside.
    expect(size.width, greaterThanOrEqualTo(440 + 2000));
    expect(size.height, greaterThanOrEqualTo(670 + 2000));
  });

  testWidgets('empty diagram still gets a sane minimum canvas', (tester) async {
    final ctrl = EditorController(diagram: DiagramModel());
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: DiagramCanvas(
          controller: ctrl,
          transformationController: TransformationController(),
        ),
      ),
    ));
    await tester.pump();
    final size = _diagramPaint(tester).size;
    expect(size.width, greaterThanOrEqualTo(2600));
    expect(size.width, lessThan(8000));
  });
}
