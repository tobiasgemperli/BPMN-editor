# BPMN Editor

A mobile-first Flutter app for creating and viewing BPMN 2.0 diagrams with BPMN-DI layout support.

## Supported BPMN Elements

| Element | BPMN Tag | Visual |
|---------|----------|--------|
| Start Event | `bpmn:startEvent` | Circle |
| End Event | `bpmn:endEvent` | Thick circle |
| Task (Step) | `bpmn:task` | Rounded rectangle |
| Exclusive Gateway (Decision) | `bpmn:exclusiveGateway` | Diamond with X |
| Sequence Flow | `bpmn:sequenceFlow` | Arrow line |

## How to Run

```bash
flutter pub get
flutter run
```

## Editor Controls

- **Tap node** — select it (shows blue outline + connector handle)
- **Drag selected node** — move it; connected edges update live
- **Long-press empty space** — quick-add menu (Start/Step/Decision/End)
- **Drag from connector handle** — draw a sequence flow to another node
- **Bottom toolbar** — tap a tool, then tap canvas to place
- **Undo/Redo** — top bar buttons
- **Delete** — select node/edge, tap trash icon
- **Properties** — select node, tap edit icon to rename
- **Pinch/zoom** — InteractiveViewer pan and zoom

## Menu Actions

- **Load Sample** — loads the bundled `assets/sample.bpmn` (a review/approve workflow)
- **View BPMN XML** — shows the exported BPMN 2.0 XML with copy-to-clipboard
- **New Diagram** — clears the canvas

## File Format

Imports and exports valid BPMN 2.0 XML with these namespaces:
- `bpmn` — `http://www.omg.org/spec/BPMN/20100524/MODEL`
- `bpmndi` — `http://www.omg.org/spec/BPMN/20100524/DI`
- `dc` — `http://www.omg.org/spec/DD/20100524/DC`
- `di` — `http://www.omg.org/spec/DD/20100524/DI`

If imported files have unsupported elements, they are silently ignored. If BPMN-DI layout data is missing, nodes are auto-laid-out left-to-right.

## Project Structure

```
lib/
  main.dart
  app/
    screens/editor_screen.dart
    widgets/
      diagram_canvas.dart
      toolbar.dart
      properties_sheet.dart
  diagram/
    model/diagram_model.dart
    io/
      bpmn_parser.dart
      bpmn_serializer.dart
    render/diagram_painter.dart
    edit/
      editor_controller.dart
      commands.dart
      command_stack.dart
      hit_test.dart
  common/
    id_generator.dart
```

## Tests

```bash
flutter test
```

Tests cover:
- **Parser** — nodes, edges, DI bounds, waypoints, auto-layout, unsupported elements
- **Serializer** — all node types, DI shapes/edges, namespaces, IDs
- **Round-trip** — import → export → import preserves structure and layout
