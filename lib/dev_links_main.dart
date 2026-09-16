import 'package:flutter/material.dart';
import 'app/screens/presentation_screen.dart';
import 'app/skins/skin_controller.dart';
import 'diagram/samples/sample_diagrams.dart';

/// Throwaway: redesigned immersive Link + Link-list cards. Not shipped.
void main() {
  SkinController.instance.value = 'immersive';
  runApp(MaterialApp(
    debugShowCheckedModeBanner: false,
    home: Row(children: [
      Expanded(child: PresentationScreen(
          diagram: SampleDiagrams.allItems(), initialNodeId: 'n10')),
      const VerticalDivider(width: 1),
      Expanded(child: PresentationScreen(
          diagram: SampleDiagrams.allItems(), initialNodeId: 'n11')),
    ]),
  ));
}
