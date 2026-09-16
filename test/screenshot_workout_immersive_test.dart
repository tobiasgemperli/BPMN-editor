import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bpmn_editor/app/skins/app_skins.dart';
import 'package:bpmn_editor/steps/model/step_block.dart';
import 'package:bpmn_editor/steps/model/step_view.dart';
import 'package:bpmn_editor/steps/registry/packs/workout_pack.dart';

const _dir =
    '/private/tmp/claude-501/-Users-tobias-Documents-Sandbox-BPMN-editor/d82465e2-ca48-4d1b-85f2-0b60af809f57/scratchpad';

void main() {
  testWidgets('workout step in the immersive skin', (tester) async {
    final font =
        File('/System/Library/Fonts/Supplemental/Arial.ttf').readAsBytesSync();
    await (FontLoader('Roboto')
          ..addFont(Future.value(ByteData.view(font.buffer))))
        .load();

    // Same step as the Skin Preview's "Barbell back squat", but with a local
    // image so the media actually decodes in the test harness.
    const step = StepView(
      title: 'Barbell back squat',
      eyebrow: 'Strength',
      progress: ProgressInfo(index: 4, total: 9),
      blocks: [
        MediaBlock(MediaKind.image, [MediaRef('assets/sample_image.jpg')]),
        RepsBlock(sets: 3, reps: 12, rest: Duration(seconds: 60)),
        MusicBlock('Uptown Funk', bpm: 128),
      ],
    );

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
      await precacheImage(const AssetImage('assets/sample_image.jpg'), ctx);
    });
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      final boundary =
          key.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2.0);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      File('$_dir/workout_immersive.png')
          .writeAsBytesSync(bytes!.buffer.asUint8List());
    });
    expect(File('$_dir/workout_immersive.png').existsSync(), true);
  });
}
