import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bpmn_editor/steps/render/skin_text.dart';

Widget _at(double scale, Widget child) => MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 200,
            child: SkinScale(scale: scale, child: child),
          ),
        ),
      ),
    );

void main() {
  const style = TextStyle(fontSize: 20, color: Color(0xFF1C1C1E));

  testWidgets('renders real text at full scale', (tester) async {
    await tester.pumpWidget(_at(1.0, const SkinText('Attach the locks', style: style)));
    expect(find.text('Attach the locks'), findsOneWidget);
  });

  testWidgets('renders real text while still legible when shrunk',
      (tester) async {
    // 20px * 0.5 = 10px, above the legibility floor → still real text.
    await tester.pumpWidget(_at(0.5, const SkinText('Attach the locks', style: style)));
    expect(find.text('Attach the locks'), findsOneWidget);
  });

  testWidgets('degrades to gray bars when too small to read', (tester) async {
    // 20px * 0.2 = 4px, below the floor → bars, no glyphs.
    await tester.pumpWidget(_at(0.2, const SkinText('Attach the locks', style: style)));
    expect(find.text('Attach the locks'), findsNothing);
    expect(find.byType(Container), findsWidgets); // the bar(s)
  });
}
