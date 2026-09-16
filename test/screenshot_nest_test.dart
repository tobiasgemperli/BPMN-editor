import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bpmn_editor/app/skins/app_skins.dart';
import 'package:bpmn_editor/diagram/samples/sample_diagrams.dart';

const _dir =
    '/private/tmp/claude-501/-Users-tobias-Documents-Sandbox-BPMN-editor/d82465e2-ca48-4d1b-85f2-0b60af809f57/scratchpad';

void main() {
  testWidgets('render every Nest step in the immersive card', (tester) async {
    final font =
        File('/System/Library/Fonts/Supplemental/Arial.ttf').readAsBytesSync();
    await (FontLoader('Roboto')
          ..addFont(Future.value(ByteData.view(font.buffer))))
        .load();

    final diagram = SampleDiagrams.nestThermostatInstall();
    const nodes = ['n1', 'n2', 'n3', 'n4', 'n5', 'n6', 'n7', 'n8', 'n9', 'n10',
        'n11', 'n12'];

    for (final id in nodes) {
      final node = diagram.nodes[id]!;
      final step = nodeToStepView(node, diagram, index: 1, total: 16);
      final asset =
          (node.content!.imagePaths).first; // assets/nest_*.png
      final key = GlobalKey();
      await tester.pumpWidget(MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(fontFamily: 'Roboto'),
        home: Scaffold(
          body: Center(
            child: RepaintBoundary(
              key: key,
              child: SizedBox(
                width: 390,
                height: 780,
                child: Builder(
                  builder: (c) =>
                      appStepRegistry.renderStep(c, 'immersive', step),
                ),
              ),
            ),
          ),
        ),
      ));
      await tester.runAsync(() async {
        final ctx = tester.element(find.byType(MaterialApp));
        await precacheImage(AssetImage(asset), ctx);
      });
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        final boundary =
            key.currentContext!.findRenderObject() as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 2.0);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        File('$_dir/card_$id.png')
            .writeAsBytesSync(bytes!.buffer.asUint8List());
      });
    }
    expect(File('$_dir/card_n12.png').existsSync(), true);
  });
}
