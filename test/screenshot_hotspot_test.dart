import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bpmn_editor/steps/model/step_block.dart';
import 'package:bpmn_editor/app/skins/app_skins.dart';
import 'package:bpmn_editor/steps/render/block_view.dart';

const _dir =
    '/private/tmp/claude-501/-Users-tobias-Documents-Sandbox-BPMN-editor/d82465e2-ca48-4d1b-85f2-0b60af809f57/scratchpad';

void main() {
  testWidgets('render interactive HotspotBlock (before + after tap)',
      (tester) async {
    final font =
        File('/System/Library/Fonts/Supplemental/Arial.ttf').readAsBytesSync();
    await (FontLoader('Roboto')
          ..addFont(Future.value(ByteData.view(font.buffer))))
        .load();

    const block = HotspotBlock('assets/att_power_ill.png', [
      Hotspot(0.205, 0.330, 'Power',
          'Solid green = on. Red = fault — check the power source. Off = no power.'),
      Hotspot(0.215, 0.620, 'Broadband',
          'Solid green = connected. Blinking = trying to connect (wait). Off/red = no line — troubleshoot.'),
      Hotspot(0.215, 0.670, 'Service',
          'Solid green = internet active. Blinking = activating. Off = not activated yet — finish registration.'),
    ]);

    final key = GlobalKey();
    await tester.pumpWidget(MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(fontFamily: 'Roboto'),
      home: Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: RepaintBoundary(
            key: key,
            child: SizedBox(
              width: 390,
              height: 780,
              child: Builder(
                builder: (c) => appStepRegistry.renderBlock(
                    c, block, const SkinContext('immersive', immersive: true)),
              ),
            ),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    Future<void> shoot(String name) async {
      await tester.runAsync(() async {
        final boundary =
            key.currentContext!.findRenderObject() as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 3.0);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        File('$_dir/$name').writeAsBytesSync(bytes!.buffer.asUint8List());
      });
    }

    await shoot('hotspot_before.png'); // markers + hint
    await tester.tap(find.text('2')); // tap the Broadband marker
    await tester.pumpAndSettle();
    await shoot('hotspot_after.png'); // detail revealed

    expect(File('$_dir/hotspot_after.png').existsSync(), true);
  });
}
