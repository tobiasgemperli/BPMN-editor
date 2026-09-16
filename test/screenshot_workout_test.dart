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
    '/private/tmp/claude-501/-Users-tobias-Documents-Sandbox-BPMN-editor/d82465e2-ca48-4d1b-85f2-0b60af809f57/scratchpad/workout_immersive.png';

// Renders one strength-workout step through the immersive skin: hero media +
// sets/reps/rest metrics + music track overlaid on the scrim. Uses a bundled
// photo as the hero so it renders offline (real diagram uses a remote clip).
void main() {
  testWidgets('render immersive workout card', (tester) async {
    final font =
        File('/System/Library/Fonts/Supplemental/Arial.ttf').readAsBytesSync();
    await (FontLoader('Roboto')
          ..addFont(Future.value(ByteData.view(font.buffer))))
        .load();

    // A workout node with a photo hero (so it decodes offline) + workout info.
    final node = NodeModel(
      id: 'n2',
      type: NodeType.task,
      name: 'Barbell back squat',
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

    final key = GlobalKey();
    await tester.pumpWidget(MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(fontFamily: 'Roboto'),
      home: Scaffold(
        body: Center(
          child: RepaintBoundary(
            key: key,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: SizedBox(
                width: 360,
                height: 720,
                child: Builder(
                    builder: (c) =>
                        appStepRegistry.renderStep(c, 'immersive', step)),
              ),
            ),
          ),
        ),
      ),
    ));

    await tester.runAsync(() async {
      await precacheImage(const AssetImage('assets/machine_1.jpg'),
          key.currentContext!);
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
