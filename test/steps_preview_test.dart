import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bpmn_editor/app/screens/steps_preview_screen.dart';

void main() {
  testWidgets('preview renders both skin options and a sample', (tester) async {
    tester.view.physicalSize = const Size(390, 844); // phone portrait
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(home: StepsPreviewScreen()));
    await tester.pump();
    expect(find.text('Classic'), findsOneWidget);
    expect(find.text('Immersive'), findsOneWidget);
    expect(find.text('Attach the cam locks'), findsWidgets);
    expect(find.text('Miniatures'), findsOneWidget);
  });
}
