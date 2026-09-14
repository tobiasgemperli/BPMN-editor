import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bpmn_editor/app/widgets/process_card.dart';
import 'package:bpmn_editor/diagram/model/diagram_model.dart';

/// A PDF attachment renders as a document tile (filename + PDF badge + open
/// affordance), and a mixed card with a PDF + a link shows both.
void main() {
  testWidgets('PDF renders as a document tile', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: ProcessCard(
          nodeName: 'Gather your documents',
          text: 'Bring the required documents.',
          pdfPaths: ['assets/baugesuch.pdf'],
          displayMode: ContentDisplayMode.mixed,
        ),
      ),
    ));
    await tester.pump();

    expect(find.text('baugesuch.pdf'), findsOneWidget);
    expect(find.text('PDF'), findsOneWidget);
    expect(find.text('Tap to open'), findsOneWidget);

    // Body text must actually be laid out with real height — regression guard
    // for the bug where a Flexible text above Spacer(flex:100) collapsed to ~0.
    final textSize = tester.getSize(find.text('Bring the required documents.'));
    expect(textSize.height, greaterThan(10));
  });

  testWidgets('mixed card shows PDF tile and link together', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: ProcessCard(
          nodeName: 'Submit',
          text: 'File it, then confirm online.',
          pdfPaths: ['assets/form.pdf'],
          linkUrl: 'https://example.com',
          linkLabel: 'Portal',
          displayMode: ContentDisplayMode.mixed,
        ),
      ),
    ));
    await tester.pump();

    expect(find.text('form.pdf'), findsOneWidget); // PDF tile
    expect(find.text('Portal'), findsOneWidget); // link row
  });
}
