import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bpmn_editor/diagram/samples/sample_diagrams.dart';
import 'package:bpmn_editor/app/widgets/step_media.dart';
import 'package:bpmn_editor/diagram/io/media_ref.dart';

const _out =
    '/private/tmp/claude-501/-Users-tobias-Documents-Sandbox-BPMN-editor/d82465e2-ca48-4d1b-85f2-0b60af809f57/scratchpad/thumb_picker.png';

// Renders just the "Or use an image from this guide" strip for the AT&T
// diagram's images, to eyeball the new thumbnail-picker UI.
void main() {
  testWidgets('render diagram-image thumbnail picker strip', (tester) async {
    final font =
        File('/System/Library/Fonts/Supplemental/Arial.ttf').readAsBytesSync();
    await (FontLoader('Roboto')
          ..addFont(Future.value(ByteData.view(font.buffer))))
        .load();

    final diagram = SampleDiagrams.attInternetInstall();
    final images = <String>[];
    final seen = <String>{};
    for (final n in diagram.nodes.values) {
      for (final s in n.content?.imagePaths ?? const <String>[]) {
        if (s.isNotEmpty && seen.add(s)) images.add(s);
      }
    }

    final key = GlobalKey();
    await tester.pumpWidget(MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(fontFamily: 'Roboto'),
      home: Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: RepaintBoundary(
            key: key,
            child: Container(
              width: 390,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Use an image from this guide',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1C1C1E))),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      for (final src in images)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: SizedBox(
                            width: 96,
                            height: 72,
                            child: StepImage(src, fit: BoxFit.cover),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Divider(height: 24),
                  OutlinedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.upload, size: 18),
                    label: const Text('Upload from gallery'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ));
    // Decode the asset images before capture.
    await tester.runAsync(() async {
      for (final src in images) {
        await precacheImage(AssetImage(src), key.currentContext!);
      }
    });
    await tester.pumpAndSettle();

    await tester.runAsync(() async {
      final boundary =
          key.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      File(_out).writeAsBytesSync(bytes!.buffer.asUint8List());
    });
    // Reference MediaRef so the import is exercised.
    expect(MediaRef.isAsset('assets/x.png'), true);
    expect(File(_out).existsSync(), true);
  });
}
