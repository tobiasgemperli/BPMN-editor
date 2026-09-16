import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bpmn_editor/diagram/model/diagram_model.dart';
import 'package:bpmn_editor/app/skins/app_skins.dart';

const _out =
    '/private/tmp/claude-501/-Users-tobias-Documents-Sandbox-BPMN-editor/d82465e2-ca48-4d1b-85f2-0b60af809f57/scratchpad/workout_safearea.png';

// Immersive card on a device WITH a 34px home indicator, drawn as a bar, to
// confirm the scrim text now sits above the bottom safe area.
void main() {
  testWidgets('immersive scrim respects bottom safe area', (tester) async {
    final font =
        File('/System/Library/Fonts/Supplemental/Arial.ttf').readAsBytesSync();
    await (FontLoader('Roboto')
          ..addFont(Future.value(ByteData.view(font.buffer))))
        .load();

    final node = NodeModel(
      id: 'n2', type: NodeType.task, name: 'Barbell back squat',
      rect: const Rect.fromLTWH(0, 0, 140, 70),
      content: TaskContent(
        imagePath: 'assets/machine_1.jpg',
        workout: const WorkoutInfo(
            sets: 3, reps: 12, restSeconds: 60,
            musicTitle: 'Uptown Funk', musicBpm: 128),
      ),
    );
    final diagram = DiagramModel(nodes: {'n2': node}, edges: {});
    final step = nodeToStepView(node, diagram,
        index: 3, total: 9, eyebrow: 'Strength');

    const homeIndicator = 34.0;
    final key = GlobalKey();
    await tester.pumpWidget(MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(fontFamily: 'Roboto'),
      home: RepaintBoundary(
        key: key,
        child: Center(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: SizedBox(
              width: 360,
              height: 720,
              child: Stack(
                children: [
                  // Simulate a device bottom inset for the skin to read.
                  Builder(
                    builder: (c) => MediaQuery(
                      data: MediaQuery.of(c).copyWith(
                          padding: const EdgeInsets.only(bottom: homeIndicator)),
                      child: Builder(
                          builder: (cc) =>
                              appStepRegistry.renderStep(cc, 'immersive', step)),
                    ),
                  ),
                  // Draw the home-indicator zone (red) + the pill.
                  Positioned(
                    left: 0, right: 0, bottom: 0, height: homeIndicator,
                    child: Container(
                      color: const Color(0x33FF0000),
                      alignment: Alignment.center,
                      child: Container(
                        width: 120, height: 5,
                        decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(3)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ));

    await tester.runAsync(() async {
      await precacheImage(
          const AssetImage('assets/machine_1.jpg'), key.currentContext!);
    });
    await tester.pumpAndSettle();

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
