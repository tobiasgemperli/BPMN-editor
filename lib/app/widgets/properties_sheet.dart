import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../../diagram/edit/editor_controller.dart';
import '../../diagram/model/diagram_model.dart';

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
enum DisplayType { text, image, video }

/// Opens the node editor for the currently selected node.
void showPropertiesSheet(BuildContext context, EditorController controller) {
  final nodeId = controller.selectedNodeId;
  if (nodeId == null) return;
  final node = controller.diagram.nodes[nodeId];
  if (node == null) return;
  _openNodeEditor(context, node, controller);
}

/// Opens the node editor for a specific node (used by long-press).
void showNodeEditor(
    BuildContext context, NodeModel node, EditorController controller) {
  controller.selectedNodeId = node.id;
  _openNodeEditor(context, node, controller);
}

void _openNodeEditor(
    BuildContext context, NodeModel node, EditorController controller) {
  Navigator.of(context).push(
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

  late DisplayType _displayType;
  final _picker = ImagePicker();

  // ── Per-mode state: Mixed ──
  late final TextEditingController _mixedTextCtrl;
  late final TextEditingController _mixedUrlCtrl;
  late final TextEditingController _mixedUrlLabelCtrl;
  late List<String> _mixedImagePaths;
  late List<String> _mixedPdfPaths;

  // ── Per-mode state: Image ──
  late final TextEditingController _imageUrlCtrl;
  late final TextEditingController _imageUrlLabelCtrl;
  late List<String> _imageImagePaths;
  late List<String> _imagePdfPaths;

  // ── Per-mode state: Video ──
  late final TextEditingController _videoUrlCtrl;
  late final TextEditingController _videoUrlLabelCtrl;
  late List<String> _videoVideoPaths;
  late List<String> _videoPdfPaths;

  // Gateway outgoing edge label controllers.
  final Map<String, TextEditingController> _edgeLabelCtrls = {};
  late List<EdgeModel> _outgoingEdges;
  late List<EdgeModel> _incomingEdges;

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
    _displayType = _inferDisplayType(c);

    // Initialize all per-mode controllers with empty defaults.
    _mixedTextCtrl = TextEditingController();
    _mixedUrlCtrl = TextEditingController();
    _mixedUrlLabelCtrl = TextEditingController();
    _mixedImagePaths = [];
    _mixedPdfPaths = [];

    _imageUrlCtrl = TextEditingController();
    _imageUrlLabelCtrl = TextEditingController();
    _imageImagePaths = [];
    _imagePdfPaths = [];

    _videoUrlCtrl = TextEditingController();
    _videoUrlLabelCtrl = TextEditingController();
    _videoVideoPaths = [];
    _videoPdfPaths = [];

    // Populate only the saved mode's fields from existing content.
    if (c != null) {
      switch (_displayType) {
        case DisplayType.text:
          _mixedTextCtrl.text = c.text ?? '';
          _mixedImagePaths = List<String>.from(c.imagePaths);
          _mixedPdfPaths = List<String>.from(c.pdfPaths);
          _mixedUrlCtrl.text = c.linkUrl ?? '';
          _mixedUrlLabelCtrl.text = c.linkLabel ?? '';
          break;
        case DisplayType.image:
          _imageImagePaths = List<String>.from(c.imagePaths);
          _imagePdfPaths = List<String>.from(c.pdfPaths);
          _imageUrlCtrl.text = c.linkUrl ?? '';
          _imageUrlLabelCtrl.text = c.linkLabel ?? '';
          break;
        case DisplayType.video:
          _videoVideoPaths = List<String>.from(c.videoPaths);
          _videoPdfPaths = List<String>.from(c.pdfPaths);
          _videoUrlCtrl.text = c.linkUrl ?? '';
          _videoUrlLabelCtrl.text = c.linkLabel ?? '';
          break;
      }
    }

    // Build edge label controllers for gateway nodes.
    _outgoingEdges = widget.controller.diagram.outgoingEdges(widget.node.id);
    _incomingEdges = widget.controller.diagram.incomingEdges(widget.node.id);
    for (final edge in _outgoingEdges) {
      _edgeLabelCtrls[edge.id] = TextEditingController(text: edge.name);
    }
  }

  DisplayType _inferDisplayType(TaskContent? c) {
    if (c == null) return DisplayType.text;
    switch (c.displayMode) {
      case ContentDisplayMode.image:
        return DisplayType.image;
      case ContentDisplayMode.video:
        return DisplayType.video;
      case ContentDisplayMode.mixed:
        return DisplayType.text;
    }
  }

  @override
  void dispose() {
    _saveData();
    _nameCtrl.dispose();
    _mixedTextCtrl.dispose();
    _mixedUrlCtrl.dispose();
    _mixedUrlLabelCtrl.dispose();
    _imageUrlCtrl.dispose();
    _imageUrlLabelCtrl.dispose();
    _videoUrlCtrl.dispose();
    _videoUrlLabelCtrl.dispose();
    for (final ctrl in _edgeLabelCtrls.values) {
      ctrl.dispose();
    }
    super.dispose();
  }

  Widget _buildConnectionRow(EdgeModel edge, {required bool isOutgoing}) {
    final otherNode = isOutgoing
        ? widget.controller.diagram.nodes[edge.targetId]
        : widget.controller.diagram.nodes[edge.sourceId];
    final otherName = otherNode?.name.isNotEmpty == true
        ? otherNode!.name
        : (otherNode?.id ?? '?');
    final label = isOutgoing ? '→ $otherName' : '$otherName →';

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Row(
          children: [
            Icon(
              isOutgoing ? Icons.arrow_forward : Icons.arrow_back,
              size: 16,
              color: Colors.grey[500],
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontSize: 14, color: Color(0xFF1C1C1E)),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            GestureDetector(
              onTap: () {
                widget.controller.deleteEdge(edge.id);
                setState(() {
                  _outgoingEdges = widget.controller.diagram
                      .outgoingEdges(widget.node.id);
                  _incomingEdges = widget.controller.diagram
                      .incomingEdges(widget.node.id);
                });
              },
              child: Icon(Icons.close, size: 18, color: Colors.grey[400]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEdgeLabelField(EdgeModel edge, int index) {
    final targetNode = widget.controller.diagram.nodes[edge.targetId];
    final targetName = targetNode?.name ?? edge.targetId;
    return _StyledField(
      controller: _edgeLabelCtrls[edge.id]!,
      placeholder: 'Option ${index + 1}',
      prefixIcon: Icons.arrow_forward,
      suffix: Text(
        '→ $targetName',
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

  void _saveData() {
    widget.controller.renameNode(widget.node.id, _nameCtrl.text);

    // Save gateway edge labels.
    for (final edge in _outgoingEdges) {
      final ctrl = _edgeLabelCtrls[edge.id];
      if (ctrl != null) {
        widget.controller.renameEdge(edge.id, ctrl.text);
      }
    }

    if (_hasContent) {
      String? text;
      List<String> images = [];
      List<String> videos = [];
      List<String> pdfs = [];
      String? url;
      String? urlLabel;
      ContentDisplayMode mode;

      switch (_displayType) {
        case DisplayType.text:
          mode = ContentDisplayMode.mixed;
          text = _mixedTextCtrl.text.isNotEmpty ? _mixedTextCtrl.text : null;
          images = _mixedImagePaths.where((p) => p.isNotEmpty).toList();
          pdfs = _mixedPdfPaths.where((p) => p.isNotEmpty).toList();
          url = _mixedUrlCtrl.text.isNotEmpty ? _mixedUrlCtrl.text : null;
          urlLabel = _mixedUrlLabelCtrl.text.isNotEmpty
              ? _mixedUrlLabelCtrl.text
              : null;
          break;
        case DisplayType.image:
          mode = ContentDisplayMode.image;
          images = _imageImagePaths.where((p) => p.isNotEmpty).toList();
          pdfs = _imagePdfPaths.where((p) => p.isNotEmpty).toList();
          url = _imageUrlCtrl.text.isNotEmpty ? _imageUrlCtrl.text : null;
          urlLabel = _imageUrlLabelCtrl.text.isNotEmpty
              ? _imageUrlLabelCtrl.text
              : null;
          break;
        case DisplayType.video:
          mode = ContentDisplayMode.video;
          videos = _videoVideoPaths.where((p) => p.isNotEmpty).toList();
          pdfs = _videoPdfPaths.where((p) => p.isNotEmpty).toList();
          url = _videoUrlCtrl.text.isNotEmpty ? _videoUrlCtrl.text : null;
          urlLabel = _videoUrlLabelCtrl.text.isNotEmpty
              ? _videoUrlLabelCtrl.text
              : null;
          break;
      }

      final content = TaskContent(
        text: text,
        imagePaths: images,
        videoPaths: videos,
        pdfPaths: pdfs,
        linkUrl: url,
        linkLabel: urlLabel,
        displayMode: mode,
      );

      widget.controller.updateTaskContent(
        widget.node.id,
        content.isEmpty ? null : content,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // Header with back chevron.
          Padding(
            padding: EdgeInsets.fromLTRB(8, topPad + 8, 12, 0),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: Color(0xFF1C1C1E)),
                  onPressed: () {
                    FocusScope.of(context).unfocus();
                    Navigator.pop(context);
                  },
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
                  // ── Node name ──
                  _SectionLabel(label: 'Name'),
                  const SizedBox(height: 6),
                  _StyledField(
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

                  // ── Connections ──
                  if (_outgoingEdges.isNotEmpty || _incomingEdges.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    _SectionLabel(label: 'Connections'),
                    const SizedBox(height: 8),
                    for (final edge in _incomingEdges)
                      _buildConnectionRow(edge, isOutgoing: false),
                    for (final edge in _outgoingEdges)
                      _buildConnectionRow(edge, isOutgoing: true),
                  ],

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

                  // ── Display type picker (task, start, end — not gateway) ──
                  if (_hasContent) ...[
                    const SizedBox(height: 20),
                    _SectionLabel(label: 'Display Mode'),
                    const SizedBox(height: 8),
                    _DisplayTypePicker(
                      selected: _displayType,
                      onChanged: (t) => setState(() => _displayType = t),
                    ),

                    // ── Content fields per mode ──
                    const SizedBox(height: 20),

                    // ── Mixed mode ──
                    if (_displayType == DisplayType.text) ...[
                      _SectionLabel(label: 'Content'),
                      const SizedBox(height: 8),
                      _StyledField(
                        controller: _mixedTextCtrl,
                        placeholder: 'Body text...',
                        maxLines: 6,
                        minLines: 3,
                      ),
                      const SizedBox(height: 10),
                      _SectionLabel(label: 'Images (up to 3)'),
                      const SizedBox(height: 8),
                      _MultiMediaPicker(
                        paths: _mixedImagePaths,
                        maxItems: 3,
                        label: 'Photo',
                        icon: Icons.image_outlined,
                        onPick: (index) => _pickImageFor(
                            _mixedImagePaths, 3, replaceIndex: index),
                        onAdd: () => _pickImageFor(_mixedImagePaths, 3),
                        onRemove: (index) =>
                            setState(() => _mixedImagePaths.removeAt(index)),
                      ),
                      const SizedBox(height: 10),
                      _SectionLabel(label: 'PDFs (up to 3)'),
                      const SizedBox(height: 8),
                      _MultiMediaPicker(
                        paths: _mixedPdfPaths,
                        maxItems: 3,
                        label: 'PDF',
                        icon: Icons.picture_as_pdf_outlined,
                        onPick: (index) => _pickPdfFor(
                            _mixedPdfPaths, 3, replaceIndex: index),
                        onAdd: () => _pickPdfFor(_mixedPdfPaths, 3),
                        onRemove: (index) =>
                            setState(() => _mixedPdfPaths.removeAt(index)),
                      ),
                      const SizedBox(height: 10),
                      _SectionLabel(label: 'Link'),
                      const SizedBox(height: 8),
                      _StyledField(
                        controller: _mixedUrlCtrl,
                        placeholder: 'Link URL',
                        prefixIcon: Icons.link,
                      ),
                      const SizedBox(height: 10),
                      _StyledField(
                        controller: _mixedUrlLabelCtrl,
                        placeholder: 'Link label',
                      ),
                    ],

                    // ── Image mode ──
                    if (_displayType == DisplayType.image) ...[
                      _SectionLabel(label: 'Image'),
                      const SizedBox(height: 8),
                      _MultiMediaPicker(
                        paths: _imageImagePaths,
                        maxItems: 1,
                        label: 'Photo',
                        icon: Icons.image_outlined,
                        onPick: (index) => _pickImageFor(
                            _imageImagePaths, 1, replaceIndex: index),
                        onAdd: () => _pickImageFor(_imageImagePaths, 1),
                        onRemove: (index) =>
                            setState(() => _imageImagePaths.removeAt(index)),
                      ),
                      const SizedBox(height: 10),
                      _SectionLabel(label: 'PDF'),
                      const SizedBox(height: 8),
                      _MultiMediaPicker(
                        paths: _imagePdfPaths,
                        maxItems: 1,
                        label: 'PDF',
                        icon: Icons.picture_as_pdf_outlined,
                        onPick: (index) => _pickPdfFor(
                            _imagePdfPaths, 1, replaceIndex: index),
                        onAdd: () => _pickPdfFor(_imagePdfPaths, 1),
                        onRemove: (index) =>
                            setState(() => _imagePdfPaths.removeAt(index)),
                      ),
                      const SizedBox(height: 10),
                      _SectionLabel(label: 'Link'),
                      const SizedBox(height: 8),
                      _StyledField(
                        controller: _imageUrlCtrl,
                        placeholder: 'Link URL',
                        prefixIcon: Icons.link,
                      ),
                      const SizedBox(height: 10),
                      _StyledField(
                        controller: _imageUrlLabelCtrl,
                        placeholder: 'Link label',
                      ),
                    ],

                    // ── Video mode ──
                    if (_displayType == DisplayType.video) ...[
                      _SectionLabel(label: 'Video'),
                      const SizedBox(height: 8),
                      _MultiMediaPicker(
                        paths: _videoVideoPaths,
                        maxItems: 1,
                        label: 'Video',
                        icon: Icons.videocam_outlined,
                        onPick: (index) => _pickVideoFor(
                            _videoVideoPaths, 1, replaceIndex: index),
                        onAdd: () => _pickVideoFor(_videoVideoPaths, 1),
                        onRemove: (index) =>
                            setState(() => _videoVideoPaths.removeAt(index)),
                      ),
                      const SizedBox(height: 10),
                      _SectionLabel(label: 'PDF'),
                      const SizedBox(height: 8),
                      _MultiMediaPicker(
                        paths: _videoPdfPaths,
                        maxItems: 1,
                        label: 'PDF',
                        icon: Icons.picture_as_pdf_outlined,
                        onPick: (index) => _pickPdfFor(
                            _videoPdfPaths, 1, replaceIndex: index),
                        onAdd: () => _pickPdfFor(_videoPdfPaths, 1),
                        onRemove: (index) =>
                            setState(() => _videoPdfPaths.removeAt(index)),
                      ),
                      const SizedBox(height: 10),
                      _SectionLabel(label: 'Link'),
                      const SizedBox(height: 8),
                      _StyledField(
                        controller: _videoUrlCtrl,
                        placeholder: 'Link URL',
                        prefixIcon: Icons.link,
                      ),
                      const SizedBox(height: 10),
                      _StyledField(
                        controller: _videoUrlLabelCtrl,
                        placeholder: 'Link label',
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ),
        ],
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

// ── Styled text field ────────────────────────────────────────

class _StyledField extends StatelessWidget {
  final TextEditingController controller;
  final String placeholder;
  final int maxLines;
  final int minLines;
  final bool autofocus;
  final TextStyle? style;
  final IconData? prefixIcon;
  final Widget? suffix;

  const _StyledField({
    required this.controller,
    required this.placeholder,
    this.maxLines = 1,
    this.minLines = 1,
    this.autofocus = false,
    this.style,
    this.prefixIcon,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    final isSingleLine = maxLines == 1;
    return TextField(
      controller: controller,
      autofocus: autofocus,
      maxLines: maxLines,
      minLines: minLines,
      textInputAction:
          isSingleLine ? TextInputAction.done : TextInputAction.newline,
      onEditingComplete: isSingleLine
          ? () => FocusScope.of(context).unfocus()
          : null,
      style: style ??
          const TextStyle(fontSize: 15, color: Color(0xFF1C1C1E)),
      decoration: InputDecoration(
        hintText: placeholder,
        hintStyle: TextStyle(color: Colors.grey[400]),
        prefixIcon: prefixIcon != null
            ? Icon(prefixIcon, size: 20, color: Colors.grey[500])
            : null,
        suffixIcon: suffix != null
            ? Padding(
                padding: const EdgeInsets.only(right: 12),
                child: suffix,
              )
            : null,
        suffixIconConstraints:
            const BoxConstraints(minHeight: 0, minWidth: 0),
        filled: true,
        fillColor: Colors.grey[50],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[200]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[200]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF007AFF)),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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

class _DisplayTypePicker extends StatelessWidget {
  final DisplayType selected;
  final ValueChanged<DisplayType> onChanged;

  const _DisplayTypePicker({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: DisplayType.values.map((type) {
        final isSelected = type == selected;
        return Expanded(
          child: GestureDetector(
            onTap: () => onChanged(type),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: EdgeInsets.only(
                  right: type != DisplayType.video ? 8 : 0),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFF007AFF).withValues(alpha: 0.1)
                    : Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFF007AFF)
                      : Colors.grey[200]!,
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _MiniScreenPreview(
                    type: type,
                    isSelected: isSelected,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _labelFor(type),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.w500,
                      color: isSelected
                          ? const Color(0xFF007AFF)
                          : const Color(0xFF1C1C1E),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  String _labelFor(DisplayType type) {
    switch (type) {
      case DisplayType.text:
        return 'Mixed';
      case DisplayType.image:
        return 'Image';
      case DisplayType.video:
        return 'Video';
    }
  }
}

/// A tiny portrait phone wireframe showing the layout of each display mode.
class _MiniScreenPreview extends StatelessWidget {
  final DisplayType type;
  final bool isSelected;

  const _MiniScreenPreview({required this.type, required this.isSelected});

  Color get _fg =>
      isSelected ? const Color(0xFF007AFF) : const Color(0xFF999999);

  @override
  Widget build(BuildContext context) {
    // 9:16 phone ratio.
    return AspectRatio(
      aspectRatio: 9 / 16,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected ? _fg : Colors.grey[300]!,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
        child: _buildLayout(),
      ),
    );
  }

  Widget _buildLayout() {
    switch (type) {
      case DisplayType.text:
        return _buildMixed();
      case DisplayType.image:
        return _buildImage();
      case DisplayType.video:
        return _buildVideo();
    }
  }

  /// Mixed: title at top, text lines, image thumbnail, link at bottom.
  Widget _buildMixed() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 3),
        Center(child: _bar(widthFraction: 0.6, height: 4)),
        const SizedBox(height: 5),
        _bar(widthFraction: 0.9, height: 3),
        const SizedBox(height: 3),
        _bar(widthFraction: 0.75, height: 3),
        const SizedBox(height: 3),
        _bar(widthFraction: 0.85, height: 3),
        const SizedBox(height: 3),
        _bar(widthFraction: 0.6, height: 3),
        const Spacer(),
        Container(
          height: 26,
          width: 38,
          decoration: BoxDecoration(
            color: _fg.withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(2),
          ),
          child: Icon(Icons.image, size: 16, color: _fg.withValues(alpha: 0.6)),
        ),
        const Spacer(),
        _bar(widthFraction: 0.55, height: 3),
        const SizedBox(height: 3),
      ],
    );
  }

  /// Image: fullscreen landscape image, title at top, link at bottom.
  Widget _buildImage() {
    return Column(
      children: [
        const SizedBox(height: 3),
        Center(child: _bar(widthFraction: 0.55, height: 4)),
        const Spacer(),
        Container(
          width: double.infinity,
          height: 36,
          decoration: BoxDecoration(
            color: _fg.withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(2),
          ),
          child: Icon(Icons.image, size: 20, color: _fg.withValues(alpha: 0.6)),
        ),
        const Spacer(),
        _bar(widthFraction: 0.5, height: 3),
        const SizedBox(height: 3),
      ],
    );
  }

  /// Video: fullscreen with play icon, title at top, link at bottom.
  Widget _buildVideo() {
    return Column(
      children: [
        const SizedBox(height: 3),
        Center(child: _bar(widthFraction: 0.55, height: 4)),
        const Spacer(),
        Icon(Icons.play_circle_outline, size: 22, color: _fg.withValues(alpha: 0.7)),
        const Spacer(),
        _bar(widthFraction: 0.5, height: 3),
        const SizedBox(height: 3),
      ],
    );
  }

  Widget _bar({required double widthFraction, required double height}) {
    return FractionallySizedBox(
      widthFactor: widthFraction,
      alignment: Alignment.centerLeft,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: _fg.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(1.5),
        ),
      ),
    );
  }
}

// ── Helpers ──────────────────────────────────────────────────

Color _nodeTypeColor(NodeType type) {
  switch (type) {
    case NodeType.startEvent:
      return const Color(0xFF34C759);
    case NodeType.endEvent:
      return const Color(0xFFFF3B30);
    case NodeType.task:
      return const Color(0xFF007AFF);
    case NodeType.exclusiveGateway:
      return const Color(0xFFFF9500);
  }
}

String _nodeTypeLabel(NodeType type) {
  switch (type) {
    case NodeType.startEvent:
      return 'Start Event';
    case NodeType.endEvent:
      return 'End Event';
    case NodeType.task:
      return 'Task';
    case NodeType.exclusiveGateway:
      return 'Gateway';
  }
}
