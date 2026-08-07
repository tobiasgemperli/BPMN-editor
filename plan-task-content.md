# StepChat — Status & TODO

## Completed

### Core Editor
- [x] BPMN 2.0 model: StartEvent, EndEvent, Task, ExclusiveGateway, SequenceFlow
- [x] BPMN parser + serializer with DI layout support
- [x] CustomPainter rendering with InteractiveViewer (pinch/zoom/pan)
- [x] Command stack with undo/redo
- [x] Drag-to-move nodes, live edge updates
- [x] Connector handle to draw sequence flows
- [x] Auto-layout (grid-based layered algorithm)
- [x] Orthogonal edge routing with obstacle avoidance
- [x] Merge bars for converging edges
- [x] Gateway port distribution (unbiased for clean diamond routing)
- [x] Orphan detection — red border/tint on disconnected nodes
- [x] Delete/edit action buttons above bottom bar
- [x] Autosave (debounced 5s, on exit, on app background) — no manual Save button
- [x] Editable diagram title
- [x] Snap guides for alignment

### Task Content + Persistence
- [x] `TaskContent` model: text, images (up to 3), videos, PDFs, links
- [x] Content on all node types (tasks, start/end events)
- [x] Parser: `<bpmn:documentation>` + `<bpmn:extensionElements>` with `ed:content`
- [x] Serializer: round-trip content through BPMN XML
- [x] `UpdateTaskContentCommand` for undo/redo
- [x] Content display mode (mixed, image, video)

### Editor UI
- [x] Properties sheet with per-type fields (task, gateway, start/end event)
- [x] Image/video/PDF picker from device
- [x] URL/link attachments
- [x] Connections section with edge deletion
- [x] Gateway branch label editing
- [x] Right-side vertical shape palette (Step, Decision, End)
- [x] Bottom action bar (undo, redo, cleanup, AI, present, copy BPMN)
- [x] Floating delete (red for orphans — deletes all orphans) + edit buttons

### Presentation Mode
- [x] Full-screen swipe-through cards (PageView)
- [x] ProcessCard widget with title, text, image, video, PDF, links
- [x] Start/End event cards
- [x] Gateway decision cards
- [x] Pinch-to-zoom video
- [x] Mini process map navigation
- [x] Component library screen for card layout variations

### Backend + Cloud
- [x] Guide API client (save, update, get, list, delete)
- [x] DiagramStorage with local persistence + server sync
- [x] Sync status indicator (syncing, synced, failed)
- [x] Autosave with background sync

### Discover + Social
- [x] Discover screen with server models
- [x] Creator profiles with avatar
- [x] Sample diagrams (Diamond, Sprint Cycle, Coffee, Car Import, FDA, etc.)
- [x] Viewer mode (read-only) vs Owner mode
- [x] Diagram embed widget

### AI
- [x] AI chat sheet (Claude API) for diagram generation
- [x] Auto-layout AI-generated diagrams

---

## TODO / In Progress

### Editor Polish
- [ ] Improve edge routing for complex layouts (Car Configurator zigzags, four-way merge overlaps)
- [ ] Fix merge bar edge slot spacing test
- [ ] Clean up duplicate edges (e.g. two flows to same target from gateway)

### Social / Messaging
- [ ] Message creator (currently shows "not available yet")
- [ ] Account screen functionality
- [ ] Search screen functionality

### Content
- [ ] Cloud media storage (replace local file paths with URLs)
- [ ] Rich text support for task descriptions

### General
- [ ] Android build verification
- [ ] Performance profiling on large diagrams
