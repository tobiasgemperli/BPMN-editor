import 'package:flutter/material.dart';
import 'app/screens/discover_screen.dart';

void main() {
  runApp(const BpmnEditorApp());
}

class BpmnEditorApp extends StatelessWidget {
  const BpmnEditorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BPMN Editor',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: Colors.indigo,
        useMaterial3: true,
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        colorSchemeSeed: Colors.indigo,
        useMaterial3: true,
        brightness: Brightness.dark,
      ),
      home: const DiscoverScreen(),
    );
  }
}
