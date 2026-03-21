# Plan: Task Content + Presentation Mode

## Goal
1. Allow Task nodes to carry content: **Title**, **Text**, **Image** or **Video** (not both), **URL** (TBD placement)
2. Persist content in BPMN XML using standard extension mechanisms
3. Add a **Presentation Mode** — swipe through process steps as cards
4. Build a **Component Library** screen showing card layout variations

---

## Decisions

- **Text is plain text** (not rich text) — simpler, interoperable with other BPMN tools
- **Media is local file paths** for now (device gallery), will switch to URLs later
- **Image OR Video per task**, not both
- **URL** — placement TBD, will try it out and iterate

---

## BPMN Format

`<bpmn:documentation>` for text, `<bpmn:extensionElements>` for structured content:

```xml
<bpmn:task id="task_1" name="Review Sprint">
  <bpmn:documentation>Main descriptive text goes here</bpmn:documentation>
  <bpmn:extensionElements>
    <ed:content xmlns:ed="http://bpmn-editor.app/extensions">
      <ed:title>Sprint Review Meeting</ed:title>
      <ed:image src="/path/to/local/photo.png" />
      <!-- OR <ed:video src="/path/to/local/video.mp4" /> -->
      <ed:url href="https://jira.example.com/PROJ-42" label="Jira Ticket" />
    </ed:content>
  </bpmn:extensionElements>
</bpmn:task>
```

- `name` attribute = short label on the diagram box (existing)
- `documentation` = plain text body
- `ed:title` = display title shown in cards / detail view
- `ed:image` / `ed:video` = one media attachment (mutually exclusive)
- `ed:url` = link (TBD where shown)

---

## Part 1: Model + Persistence

### 1.1 Model — `TaskContent` class

```dart
class TaskContent {
  String? title;
  String? text;           // plain text → <bpmn:documentation>
  String? imagePath;      // local file path (later: URL)
  String? videoPath;      // local file path (later: URL)
  String? linkUrl;
  String? linkLabel;

  bool get hasMedia => imagePath != null || videoPath != null;
  bool get isEmpty => title == null && text == null && !hasMedia && linkUrl == null;
}
```

Add `TaskContent? content` to `NodeModel`. Update `copy()`.

Files: `diagram/model/diagram_model.dart`

### 1.2 Parser — read from BPMN XML

- Parse `<bpmn:documentation>` → `content.text`
- Parse `<bpmn:extensionElements>/<ed:content>` children

File: `diagram/io/bpmn_parser.dart`

### 1.3 Serializer — write to BPMN XML

- Emit `<bpmn:documentation>` if text is set
- Emit `<bpmn:extensionElements>` block for title/image/video/url

File: `diagram/io/bpmn_serializer.dart`

### 1.4 Command — undo/redo

Add `UpdateTaskContentCommand` that saves old/new `TaskContent`.

Files: `diagram/edit/commands.dart`, `diagram/edit/editor_controller.dart`

---

## Part 2: Editor UI

### 2.1 Properties Sheet — content editing

Extend the bottom sheet for Task nodes:
- Title field
- Text field (multiline)
- Image picker button (local file, shows thumbnail when set)
- Video picker button (local file, shows thumbnail when set)
- Image/Video are mutually exclusive — setting one clears the other
- URL + label fields

File: `app/widgets/properties_sheet.dart`

### 2.2 Diagram Renderer — content indicators

On task boxes in the diagram:
- Show `content.title` (or fall back to `name`) as the label
- Draw small icons (image/video/link) in bottom-right corner

File: `diagram/render/diagram_painter.dart`

---

## Part 3: Presentation Mode

A new full-screen mode where the process is shown **one step at a time** as swipeable cards.

### 3.1 Process ordering

Walk the diagram graph from StartEvent following sequence flows:
- Linear sequences → ordered list of steps
- Gateway branches → TBD (could show branch label, then each path)
- For now: flatten to a linear sequence (follow the "happy path" or topological order)

### 3.2 Card widget — `ProcessCard`

A card widget that displays one task's content:
- **Title** at the top (large, bold)
- **Text** below (plain text, scrollable if long)
- **Image/Video thumbnail** — tappable to open full-screen modal
- Consistent card styling (rounded corners, shadow, padding)

### 3.3 Presentation screen — `PresentationScreen`

- Full-screen, no diagram visible
- `PageView` with vertical swipe (swipe down = next step)
- Each page is a `ProcessCard`
- Start/End events shown as minimal cards (just the name)
- Gateway shown as a decision card
- Back button to return to editor

### 3.4 Media modal

- Tapping an image thumbnail → full-screen image view (dismissible)
- Tapping a video thumbnail → full-screen video player (dismissible)
- Must close modal before swiping to next card

### 3.5 Entry point

- Add a "Play" / presentation button in the app bar or toolbar
- Opens `PresentationScreen` with current diagram

Files:
- `app/widgets/process_card.dart` (new)
- `app/screens/presentation_screen.dart` (new)
- `app/screens/editor_screen.dart` (add entry point)

---

## Part 4: Component Library

A debug/reference screen showing all card layout variations with sample content.

### Card variations to display:

1. Card with Title only
2. Card with Title + Text (short)
3. Card with Title + Text (very long, scrollable)
4. Card with Title + Image
5. Card with Title + Text + Image
6. Card with Title + Text (very long) + Image
7. Card with Title + Video
8. Card with Title + Text + Video
9. Card with Title + Text (very long) + Video
10. Card with Title + URL
11. Card with Title + Text + URL
12. Card with Title + Text + Image + URL

### Sample content

Use content from a manual/instructions theme — e.g. "How to run a sprint retrospective":
- Titles: "Define the Goal", "Gather Feedback", "Review Metrics", etc.
- Text: realistic paragraph-length descriptions
- Images: placeholder asset or bundled sample image
- Videos: placeholder asset or bundled sample video

### Entry point

- Accessible from the overflow menu: "Component Library"
- Scrollable list of all card variations with labels

Files:
- `app/screens/component_library_screen.dart` (new)
- `app/screens/editor_screen.dart` (add menu entry)

---

## Implementation Order

1. **Model + Content** — TaskContent class, parser, serializer, command
2. **Properties Sheet** — edit content on tasks
3. **ProcessCard widget** — the reusable card component
4. **Component Library** — verify all card variations look right
5. **Presentation Mode** — full swipe-through experience
6. **Sample diagram** — update sprint cycle sample with content

---

## File changes summary

| File | Change |
|------|--------|
| `diagram/model/diagram_model.dart` | Add `TaskContent`, add `content` to `NodeModel` |
| `diagram/io/bpmn_parser.dart` | Parse `documentation` + `extensionElements` |
| `diagram/io/bpmn_serializer.dart` | Serialize `documentation` + `extensionElements` |
| `diagram/edit/commands.dart` | Add `UpdateTaskContentCommand` |
| `diagram/edit/editor_controller.dart` | Add `updateTaskContent()` |
| `diagram/render/diagram_painter.dart` | Content indicators on task boxes |
| `app/widgets/properties_sheet.dart` | Content editing fields for tasks |
| `app/widgets/process_card.dart` | **New** — reusable card widget |
| `app/screens/presentation_screen.dart` | **New** — swipe-through mode |
| `app/screens/component_library_screen.dart` | **New** — card variations reference |
| `app/screens/editor_screen.dart` | Add presentation + library entry points |
| `diagram/samples/sample_diagrams.dart` | Add content to sprint cycle tasks |
