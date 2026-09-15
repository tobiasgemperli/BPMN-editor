import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bpmn_editor/steps/model/step_block.dart';
import 'package:bpmn_editor/steps/model/step_view.dart';
import 'package:bpmn_editor/steps/registry/step_registry.dart';
import 'package:bpmn_editor/steps/render/skins/immersive_skin.dart';

Widget _host(Widget child) =>
    MaterialApp(home: Scaffold(body: Center(child: SizedBox(width: 220, height: 460, child: child))));

void main() {
  final registry = StepRegistry()..registerSkin(const ImmersiveSkin());

  testWidgets('immersive media step overlays cue', (tester) async {
    const view = StepView(
      title: 'Attach the cam locks',
      eyebrow: 'Assembly',
      progress: ProgressInfo(index: 4, total: 10),
      blocks: [
        MediaBlock(MediaKind.image, [MediaRef('assets/a.jpg')]),
        TextBlock('Slide it on until it clicks.'),
      ],
    );
    await tester.pumpWidget(_host(
        Builder(builder: (c) => registry.renderStep(c, 'immersive', view))));
    expect(find.text('Attach the cam locks'), findsOneWidget);
    expect(find.text('Slide it on until it clicks.'), findsOneWidget);
  });

  testWidgets('immersive text-only becomes a typo slide', (tester) async {
    const view = StepView(title: 'Before you switch on', eyebrow: 'Safety', blocks: [
      TextBlock('Check the cable and seat the guard.'),
    ]);
    await tester.pumpWidget(_host(
        Builder(builder: (c) => registry.renderStep(c, 'immersive', view))));
    expect(find.text('Before you switch on'), findsOneWidget);
  });

  testWidgets('immersive miniature renders the title', (tester) async {
    const view = StepView(title: 'Fit the top panel', blocks: [
      MediaBlock(MediaKind.image, [MediaRef('assets/a.jpg')]),
    ]);
    await tester.pumpWidget(_host(
        Builder(builder: (c) => registry.renderMiniature(c, 'immersive', view))));
    expect(find.text('Fit the top panel'), findsOneWidget);
  });
}
