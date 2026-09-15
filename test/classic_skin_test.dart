import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bpmn_editor/steps/model/step_block.dart';
import 'package:bpmn_editor/steps/model/step_view.dart';
import 'package:bpmn_editor/steps/registry/step_registry.dart';
import 'package:bpmn_editor/steps/render/skins/classic_skin.dart';

void main() {
  testWidgets('Classic skin renders a StepView end-to-end', (tester) async {
    final registry = StepRegistry();
    installClassic(registry);

    const view = StepView(
      title: 'Insert the dowels',
      eyebrow: 'Assembly',
      progress: ProgressInfo(index: 3, total: 10, linear: true),
      blocks: [
        TextBlock('Push all eight in fully.'),
        DocBlock([DocRef('remote:x', name: 'Baugesuch form', pages: 2)]),
        LinkBlock('https://example.com', 'eBau portal'),
        ChoiceBlock([Choice('Yes', 'a'), Choice('No', 'b')]),
      ],
    );

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (c) => registry.renderStep(c, 'classic', view),
        ),
      ),
    ));

    expect(find.text('Insert the dowels'), findsOneWidget); // title
    expect(find.text('ASSEMBLY · 3 / 10'), findsOneWidget); // linear eyebrow
    expect(find.text('Push all eight in fully.'), findsOneWidget); // text block
    expect(find.text('Baugesuch form'), findsOneWidget); // doc tile
    expect(find.text('eBau portal'), findsOneWidget); // link
    expect(find.text('Yes'), findsOneWidget); // choice
  });

  testWidgets('branched flow shows "Step X" (no total)', (tester) async {
    final registry = StepRegistry();
    installClassic(registry);
    const view = StepView(
      title: 'Do you live in this district?',
      eyebrow: 'Eligibility',
      progress: ProgressInfo(index: 9, linear: false),
    );
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
          body: Builder(builder: (c) => registry.renderStep(c, 'classic', view))),
    ));
    expect(find.text('ELIGIBILITY · STEP 9'), findsOneWidget);
  });

  testWidgets('Classic miniature renders the title', (tester) async {
    final registry = StepRegistry();
    installClassic(registry);
    const view = StepView(title: 'Insert the dowels', blocks: [
      DocBlock([DocRef('remote:x', name: 'Form')]),
    ]);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 160,
            height: 200,
            child: Builder(
                builder: (c) => registry.renderMiniature(c, 'classic', view)),
          ),
        ),
      ),
    ));
    expect(find.text('Insert the dowels'), findsOneWidget);
  });
}
