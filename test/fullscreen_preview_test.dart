import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bpmn_editor/app/screens/fullscreen_preview_screen.dart';

void main() {
  testWidgets('fullscreen preview shows a sample and its miniature',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844); // phone portrait
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(home: FullscreenPreviewScreen()));
    await tester.pump();

    // First page is Classic sample 1.
    expect(find.text('Classic · 1 / 2'), findsOneWidget);
    expect(find.text('Attach the cam locks'), findsWidgets);

    // The miniature button opens the thumbnail overlay.
    await tester.tap(find.byTooltip('Show miniature'));
    await tester.pumpAndSettle();
    expect(find.text('Miniature · Classic'), findsOneWidget);
  });
}
