import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../../diagram/edit/editor_controller.dart';
import '../../diagram/model/diagram_model.dart';
import '../../steps/model/step_view.dart';
import '../skins/app_skins.dart';
import '../skins/skin_controller.dart';
import 'card_template.dart';
import 'close_circle_button.dart';
import 'process_card.dart';
import 'styled_field.dart';

/// Copies a file from a temporary path to the app's documents directory
/// so it persists across app restarts. Returns the permanent path.
Future<String> _persistFile(String tempPath) async {
  final appDir = await getApplicationDocumentsDirectory();
  final mediaDir = Directory(p.join(appDir.path, 'media'));
  if (!mediaDir.existsSync()) mediaDir.createSync(recursive: true);
  final timestamp = DateTime.now().millisecondsSinceEpoch;
  final fileName = '${timestamp}_${p.basename(tempPath)}';
  final dest = p.join(mediaDir.path, fileName);
  await File(tempPath).copy(dest);
  return dest;
}

/// The display type determines how a task card renders in presentation mode.
/// `text` is the Mixed layout (title + text + media, top-aligned); `textOnly`
/// is centered title + text with no media.

/// Opens the node editor for the currently selected node.
void showPropertiesSheet(BuildContext context, EditorController controller) {
  final nodeId = controller.selectedNodeId;
  if (nodeId == null) return;
  final node = controller.diagram.nodes[nodeId];
  if (node == null) return;
  _openNodeEditor(context, node, controller);
}

/// Opens the node editor for a specific node (used by long-press).
///
/// The returned future completes once the editor is dismissed and its edits
/// have been saved, so callers can refresh anything derived from the content.
Future<void> showNodeEditor(
    BuildContext context, NodeModel node, EditorController controller) {
  controller.selectedNodeId = node.id;
  return _openNodeEditor(context, node, controller);
}

Future<void> _openNodeEditor(
    BuildContext context, NodeModel node, EditorController controller) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) => _NodeEditorScreen(node: node, controller: controller),
    ),
  );
}

class _NodeEditorScreen extends StatefulWidget {
  final NodeModel node;
  final EditorController controller;

  const _NodeEditorScreen({required this.node, required this.controller});

  @override
  State<_NodeEditorScreen> createState() => _NodeEditorScreenState();
}

class _NodeEditorScreenState extends State<_NodeEditorScreen> {
  late final TextEditingController _nameCtrl;

  final _picker = ImagePicker();

  // ── Unified content model (slot-based) ──
  // One set of fields; the chosen card template decides which are shown. Fields
  // a template doesn't show are still preserved on save (never deleted).
  late CardTemplate _template;
  bool _showMore = false;
  late final TextEditingController _textCtrl;
  late final TextEditingController _urlCtrl;
  late final TextEditingController _urlLabelCtrl;
  late List<String> _imagePaths;
  late List<String> _videoPaths;
  late List<String> _pdfPaths;

  // Theme-specific slots.
  late final TextEditingController _setsCtrl;
  late final TextEditingController _repsCtrl;
  late final TextEditingController _restCtrl;
  late final TextEditingController _musicCtrl;
  late final TextEditingController _bpmCtrl;
  late List<ContentHotspot> _hotspots;
  final List<TextEditingController> _hsLabelCtrls = [];
  final List<TextEditingController> _hsDetailCtrls = [];

  String? get _themeId => widget.controller.diagram.theme;

  // Gateway outgoing edge label controllers.
  final Map<String, TextEditingController> _edgeLabelCtrls = {};
  late List<EdgeModel> _outgoingEdges;

  bool get _isGateway => widget.node.type == NodeType.exclusiveGateway;
  bool get _hasContent =>
      widget.node.type == NodeType.task ||
      widget.node.type == NodeType.startEvent ||
      widget.node.type == NodeType.endEvent;

  @override
  void initState() {
    super.initState();
    final c = widget.node.content;
    _nameCtrl = TextEditingController(text: widget.node.name);

    // One shared content model, populated from existing content.
    _textCtrl = TextEditingController(text: c?.text ?? '');
    _urlCtrl = TextEditingController(text: c?.linkUrl ?? '');
    _urlLabelCtrl = TextEditingController(text: c?.linkLabel ?? '');
    _imagePaths = List<String>.from(c?.imagePaths ?? const []);
    _videoPaths = List<String>.from(c?.videoPaths ?? const []);
    _pdfPaths = List<String>.from(c?.pdfPaths ?? const []);

    final w = c?.workout;
    _setsCtrl = TextEditingController(text: w != null ? '${w.sets}' : '');
    _repsCtrl = TextEditingController(text: w != null ? '${w.reps}' : '');
    _restCtrl =
        TextEditingController(text: w?.restSeconds != null ? '${w!.restSeconds}' : '');
    _musicCtrl = TextEditingController(text: w?.musicTitle ?? '');
    _bpmCtrl = TextEditingController(text: w?.musicBpm != null ? '${w!.musicBpm}' : '');
    _hotspots = (c?.hotspots ?? const []).map((h) => h.copy()).toList();
    for (final h in _hotspots) {
      _hsLabelCtrls.add(TextEditingController(text: h.label));
      _hsDetailCtrls.add(TextEditingController(text: h.detail));
    }

    _template = inferTemplate(
      themeId: _themeId,
      hasImage: _imagePaths.isNotEmpty,
      hasVideo: _videoPaths.isNotEmpty,
      hasPdf: _pdfPaths.isNotEmpty,
      hasText: (c?.text ?? '').isNotEmpty,
      hasWorkout: w != null,
      hasHotspot: _hotspots.isNotEmpty,
    );

    // Build edge label controllers for gateway nodes.
    _outgoingEdges = widget.controller.diagram.outgoingEdges(widget.node.id);
    for (final edge in _outgoingEdges) {
      _edgeLabelCtrls[edge.id] = TextEditingController(text: edge.name);
    }
  }

  @override
  void dispose() {
    _saveData();
    _nameCtrl.dispose();
    _textCtrl.dispose();
    _urlCtrl.dispose();
    _urlLabelCtrl.dispose();
    _setsCtrl.dispose();
    _repsCtrl.dispose();
    _restCtrl.dispose();
    _musicCtrl.dispose();
    _bpmCtrl.dispose();
    for (final c in [..._hsLabelCtrls, ..._hsDetailCtrls]) {
      c.dispose();
    }
    for (final ctrl in _edgeLabelCtrls.values) {
      ctrl.dispose();
    }
    super.dispose();
  }

  Widget _buildEdgeLabelField(EdgeModel edge, int index) {
    final targetNode = widget.controller.diagram.nodes[edge.targetId];
    final targetName = targetNode?.name ?? edge.targetId;
    return StyledField(
      controller: _edgeLabelCtrls[edge.id]!,
      placeholder: 'Option ${index + 1}',
      prefixIcon: Icons.arrow_forward,
      suffix: Text(
        targetName,
        style: TextStyle(fontSize: 12, color: Colors.grey[400]),
      ),
    );
  }

  Future<void> _pickImageFor(List<String> paths, int maxItems,
      {int? replaceIndex}) async {
    final file = await _picker.pickImage(source: ImageSource.gallery);
    if (file != null) {
      final permanent = await _persistFile(file.path);
      setState(() {
        if (replaceIndex != null && replaceIndex < paths.length) {
          paths[replaceIndex] = permanent;
        } else if (paths.length < maxItems) {
          paths.add(permanent);
        }
      });
    }
  }

  Future<void> _pickVideoFor(List<String> paths, int maxItems,
      {int? replaceIndex}) async {
    final file = await _picker.pickVideo(source: ImageSource.gallery);
    if (file != null) {
      final permanent = await _persistFile(file.path);
      setState(() {
        if (replaceIndex != null && replaceIndex < paths.length) {
          paths[replaceIndex] = permanent;
        } else if (paths.length < maxItems) {
          paths.add(permanent);
        }
      });
    }
  }

  Future<void> _pickPdfFor(List<String> paths, int maxItems,
      {int? replaceIndex}) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (result != null && result.files.single.path != null) {
      final permanent = await _persistFile(result.files.single.path!);
      setState(() {
        if (replaceIndex != null && replaceIndex < paths.length) {
          paths[replaceIndex] = permanent;
        } else if (paths.length < maxItems) {
          paths.add(permanent);
        }
      });
    }
  }

  // Guards against saving twice (PopScope on the way out + dispose backstop),
  // which would push duplicate undo commands.
  bool _saved = false;

  /// Builds a [TaskContent] from the current editor state, with no side
  /// effects. Shared by save and the live preview.
  List<String> _clean(List<String> l) => l.where((p) => p.isNotEmpty).toList();

  ContentDisplayMode _modeFor(CardTemplate t) => t.id == 'text_only'
      ? ContentDisplayMode.textOnly
      : t.has(CardSlot.video)
          ? ContentDisplayMode.video
          : t.has(CardSlot.image)
              ? ContentDisplayMode.image
              : ContentDisplayMode.mixed;

  WorkoutInfo? _buildWorkout() {
    final sets = int.tryParse(_setsCtrl.text);
    final reps = int.tryParse(_repsCtrl.text);
    if (sets == null && reps == null && _musicCtrl.text.isEmpty) return null;
    return WorkoutInfo(
      sets: sets ?? 0,
      reps: reps ?? 0,
      restSeconds: int.tryParse(_restCtrl.text),
      musicTitle: _musicCtrl.text.isNotEmpty ? _musicCtrl.text : null,
      musicBpm: int.tryParse(_bpmCtrl.text),
    );
  }

  List<ContentHotspot> _buildHotspots() => [
        for (int i = 0; i < _hotspots.length; i++)
          ContentHotspot(
            x: _hotspots[i].x,
            y: _hotspots[i].y,
            label: _hsLabelCtrls[i].text,
            detail: _hsDetailCtrls[i].text,
          ),
      ];

  /// Assemble the saved content from the shared model. All filled fields are
  /// kept — even ones the current template doesn't show — so switching template
  /// never deletes content. Callouts on the node are preserved.
  TaskContent? _buildContent() {
    if (!_hasContent) return null;
    final orig = widget.node.content;
    return TaskContent(
      text: _textCtrl.text.isNotEmpty ? _textCtrl.text : null,
      imagePaths: _clean(_imagePaths),
      videoPaths: _clean(_videoPaths),
      pdfPaths: _clean(_pdfPaths),
      linkUrl: _urlCtrl.text.isNotEmpty ? _urlCtrl.text : null,
      linkLabel: _urlLabelCtrl.text.isNotEmpty ? _urlLabelCtrl.text : null,
      callouts: orig?.callouts ?? const [],
      workout: _buildWorkout(),
      hotspots: _buildHotspots(),
      displayMode: _modeFor(_template),
    );
  }

  /// A StepView showing only [t]'s slots from the shared model — used for the
  /// per-template miniatures so each shows how this step looks with that layout.
  StepView _templateStep(CardTemplate t) {
    final content = TaskContent(
      text: t.has(CardSlot.text) && _textCtrl.text.isNotEmpty
          ? _textCtrl.text
          : null,
      imagePaths:
          (t.has(CardSlot.image) || t.has(CardSlot.hotspot)) ? _clean(_imagePaths) : const [],
      videoPaths: t.has(CardSlot.video) ? _clean(_videoPaths) : const [],
      pdfPaths: t.has(CardSlot.pdf) ? _clean(_pdfPaths) : const [],
      workout: t.has(CardSlot.workout) ? _buildWorkout() : null,
      hotspots: t.has(CardSlot.hotspot) ? _buildHotspots() : const [],
      displayMode: _modeFor(t),
    );
    final temp = NodeModel(
      id: widget.node.id,
      type: widget.node.type,
      name: _nameCtrl.text,
      rect: widget.node.rect,
      content: content.isEmpty ? null : content,
    );
    return nodeToStepView(temp, widget.controller.diagram);
  }

  /// The swipe strip of card-template miniatures. Each renders this step's
  /// content limited to that template, in the diagram's look. Tap to choose.
  Widget _templateStrip() {
    return ListenableBuilder(
      listenable: Listenable.merge([
        _nameCtrl, _textCtrl, _urlCtrl, _urlLabelCtrl,
        _setsCtrl, _repsCtrl, _restCtrl, _musicCtrl, _bpmCtrl,
        widget.controller,
      ]),
      builder: (context, _) {
        final skin =
            widget.controller.diagram.skinId ?? SkinController.defaultSkin;
        final templates = templatesForTheme(_themeId);
        return SizedBox(
          height: 214,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: templates.length,
            separatorBuilder: (_, _) => const SizedBox(width: 14),
            itemBuilder: (context, i) {
              final t = templates[i];
              return _TemplateTile(
                label: t.label,
                selected: t.id == _template.id,
                child: appStepRegistry.renderMiniature(
                    context, skin, _templateStep(t)),
                onTap: () => setState(() => _template = t),
              );
            },
          ),
        );
      },
    );
  }

  static const _slotOrder = [
    CardSlot.image,
    CardSlot.video,
    CardSlot.pdf,
    CardSlot.text,
    CardSlot.workout,
    CardSlot.hotspot,
  ];

  /// The editable fields for a set of slots, in a canonical order.
  List<Widget> _slotFields(Set<CardSlot> slots) {
    final w = <Widget>[];
    for (final s in _slotOrder) {
      if (slots.contains(s)) {
        w.addAll(_fieldFor(s));
        w.add(const SizedBox(height: 18));
      }
    }
    return w;
  }

  /// A "More fields" disclosure holding the slots the current template doesn't
  /// feature, plus the link — so every field stays reachable.
  List<Widget> _moreFields() {
    // Only offer slots this theme actually supports (across its templates),
    // minus the ones the current template already shows.
    final pool = {for (final t in templatesForTheme(_themeId)) ...t.slots};
    final rest = _slotOrder
        .where((s) => pool.contains(s) && !_template.has(s))
        .toList();
    return [
      const SizedBox(height: 4),
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: () => setState(() => _showMore = !_showMore),
          icon: Icon(_showMore ? Icons.expand_less : Icons.expand_more,
              size: 18),
          label: Text(_showMore ? 'Fewer fields' : 'More fields'),
          style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF007AFF),
              padding: EdgeInsets.zero),
        ),
      ),
      if (_showMore) ...[
        const SizedBox(height: 8),
        for (final s in rest) ...[..._fieldFor(s), const SizedBox(height: 18)],
        ..._linkFields(),
      ],
    ];
  }

  List<Widget> _fieldFor(CardSlot s) {
    switch (s) {
      case CardSlot.image:
        return [
          _SectionLabel(label: 'Image'),
          const SizedBox(height: 8),
          _MultiMediaPicker(
            paths: _imagePaths,
            maxItems: 3,
            label: 'Photo',
            icon: Icons.image_outlined,
            onPick: (i) => _pickImageFor(_imagePaths, 3, replaceIndex: i),
            onAdd: () => _pickImageFor(_imagePaths, 3),
            onRemove: (i) => setState(() => _imagePaths.removeAt(i)),
          ),
        ];
      case CardSlot.video:
        return [
          _SectionLabel(label: 'Video'),
          const SizedBox(height: 8),
          _MultiMediaPicker(
            paths: _videoPaths,
            maxItems: 1,
            label: 'Video',
            icon: Icons.videocam_outlined,
            onPick: (i) => _pickVideoFor(_videoPaths, 1, replaceIndex: i),
            onAdd: () => _pickVideoFor(_videoPaths, 1),
            onRemove: (i) => setState(() => _videoPaths.removeAt(i)),
          ),
        ];
      case CardSlot.pdf:
        return [
          _SectionLabel(label: 'PDF'),
          const SizedBox(height: 8),
          _MultiMediaPicker(
            paths: _pdfPaths,
            maxItems: 3,
            label: 'PDF',
            icon: Icons.picture_as_pdf_outlined,
            onPick: (i) => _pickPdfFor(_pdfPaths, 3, replaceIndex: i),
            onAdd: () => _pickPdfFor(_pdfPaths, 3),
            onRemove: (i) => setState(() => _pdfPaths.removeAt(i)),
          ),
        ];
      case CardSlot.text:
        return [
          _SectionLabel(label: 'Text'),
          const SizedBox(height: 8),
          StyledField(
            controller: _textCtrl,
            placeholder: 'Body text...',
            maxLines: 6,
            minLines: 3,
          ),
        ];
      case CardSlot.workout:
        return [
          _SectionLabel(label: 'Sets · Reps · Rest'),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
                child: StyledField(
                    controller: _setsCtrl,
                    placeholder: 'Sets',
                    keyboardType: TextInputType.number)),
            const SizedBox(width: 10),
            Expanded(
                child: StyledField(
                    controller: _repsCtrl,
                    placeholder: 'Reps',
                    keyboardType: TextInputType.number)),
            const SizedBox(width: 10),
            Expanded(
                child: StyledField(
                    controller: _restCtrl,
                    placeholder: 'Rest s',
                    keyboardType: TextInputType.number)),
          ]),
          const SizedBox(height: 10),
          _SectionLabel(label: 'Music'),
          const SizedBox(height: 8),
          StyledField(controller: _musicCtrl, placeholder: 'Track title'),
          const SizedBox(height: 10),
          StyledField(
              controller: _bpmCtrl,
              placeholder: 'BPM',
              keyboardType: TextInputType.number),
        ];
      case CardSlot.hotspot:
        return [
          _SectionLabel(label: 'Hotspots'),
          const SizedBox(height: 8),
          for (int i = 0; i < _hotspots.length; i++) _hotspotRow(i),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _addHotspot,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add hotspot'),
              style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF007AFF),
                  padding: EdgeInsets.zero),
            ),
          ),
        ];
      case CardSlot.link:
        return _linkFields();
    }
  }

  Widget _hotspotRow(int i) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Column(
            children: [
              Row(children: [
                Expanded(
                    child: StyledField(
                        controller: _hsLabelCtrls[i],
                        placeholder: 'Label (e.g. Power light)')),
                IconButton(
                  onPressed: () => _removeHotspot(i),
                  icon: const Icon(Icons.close, size: 18, color: Color(0xFF8E8E93)),
                ),
              ]),
              const SizedBox(height: 8),
              StyledField(
                  controller: _hsDetailCtrls[i],
                  placeholder: 'What it means…',
                  maxLines: 2),
            ],
          ),
        ),
      );

  void _addHotspot() => setState(() {
        final n = _hotspots.length;
        _hotspots.add(ContentHotspot(
            x: 0.25 + 0.15 * (n % 4), y: 0.35 + 0.12 * ((n ~/ 4) % 3)));
        _hsLabelCtrls.add(TextEditingController());
        _hsDetailCtrls.add(TextEditingController());
      });

  void _removeHotspot(int i) => setState(() {
        _hotspots.removeAt(i);
        _hsLabelCtrls.removeAt(i).dispose();
        _hsDetailCtrls.removeAt(i).dispose();
      });

  List<Widget> _linkFields() => [
        _SectionLabel(label: 'Link'),
        const SizedBox(height: 8),
        StyledField(
            controller: _urlCtrl,
            placeholder: 'Link URL',
            prefixIcon: Icons.link),
        const SizedBox(height: 10),
        StyledField(controller: _urlLabelCtrl, placeholder: 'Link label'),
      ];

  void _saveData() {
    if (_saved) return;
    _saved = true;
    widget.controller.renameNode(widget.node.id, _nameCtrl.text);

    // Save gateway edge labels.
    for (final edge in _outgoingEdges) {
      final ctrl = _edgeLabelCtrls[edge.id];
      if (ctrl != null) {
        widget.controller.renameEdge(edge.id, ctrl.text);
      }
    }

    if (_hasContent) {
      final content = _buildContent();
      widget.controller.updateTaskContent(
        widget.node.id,
        (content == null || content.isEmpty) ? null : content,
      );
    }
  }

  /// Show the presentation card for this step exactly as it will appear,
  /// reflecting the current (unsaved) edits.
  void _openPreview() {
    // Dismiss the keyboard before showing the preview.
    FocusManager.instance.primaryFocus?.unfocus();
    final preview = widget.node.copy()
      ..name = _nameCtrl.text
      ..content = _buildContent();
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _NodePreviewScreen(
          node: preview,
          diagram: widget.controller.diagram,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;

    return PopScope(
      // Save synchronously as the editor pops (back button, swipe, or system
      // back) so the caller's reload sees the updated content.
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) _saveData();
      },
      child: Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // Header: floating back button (same as the screen before) + title.
          Padding(
            padding: EdgeInsets.fromLTRB(16, topPad + 8, 16, 0),
            child: Row(
              children: [
                CloseCircleButton(
                  isBack: true,
                  onPressed: () {
                    FocusScope.of(context).unfocus();
                    Navigator.pop(context);
                  },
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      _editTitle(widget.node.type),
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1C1C1E),
                      ),
                    ),
                  ),
                ),
                // Preview the step as it will appear in presentation mode.
                TextButton(
                  onPressed: _openPreview,
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF1C1C1E),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(44, 44),
                  ),
                  child: const Text('Preview'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Scrollable content.
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                  20, 0, 20, MediaQuery.of(context).padding.bottom + 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Node title ──
                  _SectionLabel(label: 'Title'),
                  const SizedBox(height: 6),
                  StyledField(
                    controller: _nameCtrl,
                    placeholder: widget.node.type == NodeType.exclusiveGateway
                        ? 'Question...'
                        : 'Step name...',
                    autofocus: true,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1C1C1E),
                    ),
                  ),

                  // ── Gateway branch labels ──
                  if (_isGateway && _outgoingEdges.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    _SectionLabel(label: 'Options'),
                    const SizedBox(height: 8),
                    for (int i = 0; i < _outgoingEdges.length; i++) ...[
                      _buildEdgeLabelField(_outgoingEdges[i], i),
                      if (i < _outgoingEdges.length - 1)
                        const SizedBox(height: 10),
                    ],
                  ],

                  // ── Card-template swipe + slot fields (task, start, end) ──
                  if (_hasContent) ...[
                    const SizedBox(height: 20),
                    _SectionLabel(label: 'Layout · swipe to choose'),
                    const SizedBox(height: 8),
                    _templateStrip(),
                    const SizedBox(height: 20),

                    // Fields for the chosen template's slots (prefilled).
                    ..._slotFields(_template.slots),

                    // Everything else the diagram can hold — reachable so no
                    // content gets stranded when a template hides its field.
                    ..._moreFields(),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }
}

// ── Section label ────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: const Color(0xFF1C1C1E),
        letterSpacing: 0.8,
      ),
    );
  }
}

// ── Media picker field ───────────────────────────────────────

class _MediaPickerField extends StatelessWidget {
  final String? path;
  final String label;
  final IconData icon;
  final VoidCallback onPick;
  final VoidCallback onClear;

  const _MediaPickerField({
    required this.path,
    required this.label,
    required this.icon,
    required this.onPick,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final hasFile = path != null && path!.isNotEmpty;
    return GestureDetector(
      onTap: onPick,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: hasFile
            ? Row(
                children: [
                  // Show thumbnail for images.
                  if (path!.startsWith('/'))
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                            maxHeight: 60, maxWidth: 120),
                        child: Image.file(
                          File(path!),
                          fit: BoxFit.contain,
                          errorBuilder: (_, _, _) => Container(
                            width: 48,
                            height: 48,
                            color: Colors.grey[200],
                            child:
                                Icon(icon, size: 22, color: Colors.grey[500]),
                          ),
                        ),
                      ),
                    )
                  else
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(icon, size: 22, color: Colors.grey[500]),
                    ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      path!.split('/').last,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF1C1C1E),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  GestureDetector(
                    onTap: onClear,
                    child: Icon(Icons.close, size: 18, color: Colors.grey[500]),
                  ),
                ],
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 22, color: const Color(0xFF007AFF)),
                  const SizedBox(width: 8),
                  Text(
                    'Choose $label',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF007AFF),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

// ── Multi-media picker (images, videos, PDFs) ────────────────

class _MultiMediaPicker extends StatelessWidget {
  final List<String> paths;
  final int maxItems;
  final String label;
  final IconData icon;
  final ValueChanged<int> onPick;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemove;

  const _MultiMediaPicker({
    required this.paths,
    required this.maxItems,
    required this.label,
    required this.icon,
    required this.onPick,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (int i = 0; i < paths.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _MediaPickerField(
              path: paths[i],
              label: '$label ${i + 1}',
              icon: icon,
              onPick: () => onPick(i),
              onClear: () => onRemove(i),
            ),
          ),
        if (paths.length < maxItems)
          _MediaPickerField(
            path: null,
            label: paths.isEmpty ? label : '$label ${paths.length + 1}',
            icon: icon,
            onPick: onAdd,
            onClear: () {},
          ),
      ],
    );
  }
}

// ── Display type picker ──────────────────────────────────────

class _TemplateTile extends StatelessWidget {
  final String label;
  final bool selected;
  final Widget child;
  final VoidCallback onTap;
  const _TemplateTile({
    required this.label,
    required this.selected,
    required this.child,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF007AFF);
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 108,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected ? accent : const Color(0xFFE0E0E0),
                width: selected ? 2.5 : 1,
              ),
              boxShadow: const [
                BoxShadow(
                    color: Colors.black12, blurRadius: 10, offset: Offset(0, 3)),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: SizedBox(width: 108, height: 144, child: child),
          ),
          const SizedBox(height: 8),
          Text(label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? accent : const Color(0xFF3A3A3C),
              )),
        ],
      ),
    );
  }
}

// ── Helpers ──────────────────────────────────────────────────

/// Screen title for the node editor, e.g. "Edit Step", "Edit Start".
String _editTitle(NodeType type) {
  switch (type) {
    case NodeType.task:
      return 'Edit Step';
    case NodeType.startEvent:
      return 'Edit Start';
    case NodeType.endEvent:
      return 'Edit End';
    case NodeType.exclusiveGateway:
      return 'Edit Decision';
  }
}

// ── Node preview ─────────────────────────────────────────────

/// Full-screen preview of a single node's presentation card — the same card
/// shown in presentation mode, so "Preview" reflects exactly what viewers see.
class _NodePreviewScreen extends StatelessWidget {
  final NodeModel node;
  final DiagramModel diagram;

  const _NodePreviewScreen({required this.node, required this.diagram});

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    return Scaffold(
      // Match presentation mode — the card renders dark text / contained media
      // on a light background, so a black background hides it.
      backgroundColor: Colors.white,
      body: Stack(
        fit: StackFit.expand,
        children: [
          ProcessCard.fromNode(node, diagram: diagram),
          Positioned(
            top: topPad + 8,
            right: 16,
            child: CloseCircleButton(
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
    );
  }
}
