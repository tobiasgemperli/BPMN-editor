import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bpmn_editor/diagram/samples/sample_diagrams.dart';
import 'package:bpmn_editor/app/skins/app_skins.dart';

// Renders the real Connect-ONT "Open the Lower Cover" card (with the amber
// CalloutBlock warning) through the production classic skin and saves a PNG.
const _out =
    '/private/tmp/claude-501/-Users-tobias-Documents-Sandbox-BPMN-editor/248d5a5c-b96b-460a-9061-e04f840f1517/scratchpad/callout_card.png';

void main() {
  testWidgets('render CalloutBlock card to PNG', (tester) async {
    final bytes =
        File('/System/Library/Fonts/Supplemental/Arial.ttf').readAsBytesSync();
    await (FontLoader('Roboto')..addFont(Future.value(ByteData.view(bytes.buffer))))
        .load();

    final diagram = SampleDiagrams.attInternetInstall();
    final step = nodeToStepView(diagram.nodes['n9']!, diagram, index: 8, total: 12);

    final key = GlobalKey();
    await tester.pumpWidget(MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(fontFamily: 'Roboto'),
      home: Scaffold(
        backgroundColor: Colors.white,
        body: SingleChildScrollView(
          child: RepaintBoundary(
            key: key,
            child: Container(
              width: 390,
              color: Colors.white,
              child: Builder(
                builder: (c) => appStepRegistry.renderStep(c, 'classic', step),
              ),
            ),
          ),
        ),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 200));

    await tester.runAsync(() async {
      final boundary =
          key.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      File(_out).writeAsBytesSync(bytes!.buffer.asUint8List());
    });
    expect(File(_out).existsSync(), true);
  });
}
