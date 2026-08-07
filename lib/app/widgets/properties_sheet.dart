import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../diagram/edit/editor_controller.dart';
import '../../diagram/model/diagram_model.dart';

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
  late final TextEditingController _textCtrl;
  late final TextEditingController _urlCtrl;
  late final TextEditingController _urlLabelCtrl;

  late DisplayType _displayType;
  final _picker = ImagePicker();

  late List<String> _imagePaths;
  late List<String> _videoPaths;
  late List<String> _pdfPaths;

  // Gateway outgoing edge label controllers.
  final Map<String, TextEditingController> _edgeLabelCtrls = {};
  late final List<EdgeModel> _outgoingEdges;

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
    _textCtrl = TextEditingController(text: c?.text ?? '');
    _imagePaths = List<String>.from(c?.imagePaths ?? []);
    _videoPaths = List<String>.from(c?.videoPaths ?? []);
    _pdfPaths = List<String>.from(c?.pdfPaths ?? []);
    _urlCtrl = TextEditingController(text: c?.linkUrl ?? '');
    _urlLabelCtrl = TextEditingController(text: c?.linkLabel ?? '');
    _displayType = _inferDisplayType(c);

    // Build edge label controllers for gateway nodes.
    _outgoingEdges = widget.controller.diagram.outgoingEdges(widget.node.id);
    for (final edge in _outgoingEdges) {
      _edgeLabelCtrls[edge.id] = TextEditingController(text: edge.name);
    }
  }

  DisplayType _inferDisplayType(TaskContent? c) {
    if (c == null) return DisplayType.text;
    if (c.videoPaths.isNotEmpty && c.text == null && c.imagePaths.isEmpty && c.pdfPaths.isEmpty) {
      return DisplayType.video;
    }
    if (c.imagePaths.isNotEmpty && c.text == null && c.linkUrl == null &&
        c.links.isEmpty && c.videoPaths.isEmpty && c.pdfPaths.isEmpty) {
      return DisplayType.image;
    }
    return DisplayType.text;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _textCtrl.dispose();
    _urlCtrl.dispose();
    _urlLabelCtrl.dispose();
    for (final ctrl in _edgeLabelCtrls.values) {
      ctrl.dispose();
    }
    super.dispose();
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

  Future<void> _pickImage({int? replaceIndex}) async {
    final file = await _picker.pickImage(source: ImageSource.gallery);
    if (file != null) {
      setState(() {
        if (replaceIndex != null && replaceIndex < _imagePaths.length) {
          _imagePaths[replaceIndex] = file.path;
        } else if (_imagePaths.length < 3) {
          _imagePaths.add(file.path);
        }
      });
    }
  }

  Future<void> _pickVideo({int? replaceIndex}) async {
    final file = await _picker.pickVideo(source: ImageSource.gallery);
    if (file != null) {
      setState(() {
        if (replaceIndex != null && replaceIndex < _videoPaths.length) {
          _videoPaths[replaceIndex] = file.path;
        } else if (_videoPaths.length < 3) {
          _videoPaths.add(file.path);
        }
      });
    }
  }

  Future<void> _pickPdf({int? replaceIndex}) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (result != null && result.files.single.path != null) {
      setState(() {
        final path = result.files.single.path!;
        if (replaceIndex != null && replaceIndex < _pdfPaths.length) {
          _pdfPaths[replaceIndex] = path;
        } else if (_pdfPaths.length < 3) {
          _pdfPaths.add(path);
        }
      });
    }
  }

  void _save() {
    widget.controller.renameNode(widget.node.id, _nameCtrl.text);

    // Save gateway edge labels.
    for (final edge in _outgoingEdges) {
      final ctrl = _edgeLabelCtrls[edge.id];
      if (ctrl != null) {
        widget.controller.renameEdge(edge.id, ctrl.text);
      }
    }

    if (_hasContent) {
      final text = _textCtrl.text.isNotEmpty ? _textCtrl.text : null;

      List<String> images = [];
      List<String> videos = [];
      List<String> pdfs = [];
      String? url;
      String? urlLabel;

      switch (_displayType) {
        case DisplayType.image:
          images = _imagePaths.where((p) => p.isNotEmpty).toList();
          break;
        case DisplayType.video:
          videos = _videoPaths.where((p) => p.isNotEmpty).toList();
          break;
        case DisplayType.text:
          images = _imagePaths.where((p) => p.isNotEmpty).toList();
          videos = _videoPaths.where((p) => p.isNotEmpty).toList();
          pdfs = _pdfPaths.where((p) => p.isNotEmpty).toList();
          url = _urlCtrl.text.isNotEmpty ? _urlCtrl.text : null;
          urlLabel = _urlLabelCtrl.text.isNotEmpty ? _urlLabelCtrl.text : null;
          break;
      }

      final content = TaskContent(
        text: text,
        imagePaths: images,
        videoPaths: videos,
        pdfPaths: pdfs,
        linkUrl: url,
        linkLabel: urlLabel,
      );

      widget.controller.updateTaskContent(
        widget.node.id,
        content.isEmpty ? null : content,
      );
    }

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // Header with back, type badge, and save.
          Padding(
            padding: EdgeInsets.fromLTRB(8, topPad + 8, 12, 0),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _nodeTypeColor(widget.node.type).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _nodeTypeLabel(widget.node.type),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _nodeTypeColor(widget.node.type),
                    ),
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: _save,
                  style: TextButton.styleFrom(
                    backgroundColor: const Color(0xFF007AFF),
                    foregroundColor: Colors.white,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  child: const Text('Save',
                      style:
                          TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
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
                    _SectionLabel(label: 'Display'),
                    const SizedBox(height: 8),
                    _DisplayTypePicker(
                      selected: _displayType,
                      onChanged: (t) => setState(() => _displayType = t),
                    ),

                    // ── Content fields ──
                    const SizedBox(height: 20),

                    // Body text — Mixed mode only.
                    if (_displayType == DisplayType.text) ...[
                      _SectionLabel(label: 'Content'),
                      const SizedBox(height: 8),
                      _StyledField(
                        controller: _textCtrl,
                        placeholder: 'Body text...',
                        maxLines: 6,
                        minLines: 3,
                      ),
                      const SizedBox(height: 10),
                    ],

                    // Images — image mode (1 image), Mixed mode (up to 3).
                    if (_displayType == DisplayType.image ||
                        _displayType == DisplayType.text) ...[
                      _SectionLabel(
                        label: _displayType == DisplayType.text
                            ? 'Images (up to 3)'
                            : 'Image',
                      ),
                      const SizedBox(height: 8),
                      _MultiMediaPicker(
                        paths: _imagePaths,
                        maxItems: _displayType == DisplayType.text ? 3 : 1,
                        label: 'Photo',
                        icon: Icons.image_outlined,
                        onPick: (index) => _pickImage(replaceIndex: index),
                        onAdd: () => _pickImage(),
                        onRemove: (index) =>
                            setState(() => _imagePaths.removeAt(index)),
                      ),
                      const SizedBox(height: 10),
                    ],

                    // Videos — video mode (1 video), Mixed mode (up to 3).
                    if (_displayType == DisplayType.video ||
                        _displayType == DisplayType.text) ...[
                      _SectionLabel(
                        label: _displayType == DisplayType.text
                            ? 'Videos (up to 3)'
                            : 'Video',
                      ),
                      const SizedBox(height: 8),
                      _MultiMediaPicker(
                        paths: _videoPaths,
                        maxItems: _displayType == DisplayType.text ? 3 : 1,
                        label: 'Video',
                        icon: Icons.videocam_outlined,
                        onPick: (index) => _pickVideo(replaceIndex: index),
                        onAdd: () => _pickVideo(),
                        onRemove: (index) =>
                            setState(() => _videoPaths.removeAt(index)),
                      ),
                      const SizedBox(height: 10),
                    ],

                    // PDFs — Mixed mode only (up to 3).
                    if (_displayType == DisplayType.text) ...[
                      _SectionLabel(label: 'PDFs (up to 3)'),
                      const SizedBox(height: 8),
                      _MultiMediaPicker(
                        paths: _pdfPaths,
                        maxItems: 3,
                        label: 'PDF',
                        icon: Icons.picture_as_pdf_outlined,
                        onPick: (index) => _pickPdf(replaceIndex: index),
                        onAdd: () => _pickPdf(),
                        onRemove: (index) =>
                            setState(() => _pdfPaths.removeAt(index)),
                      ),
                      const SizedBox(height: 10),
                    ],

                    // Link — Mixed mode only.
                    if (_displayType == DisplayType.text) ...[
                      _SectionLabel(label: 'Link'),
                      const SizedBox(height: 8),
                      _StyledField(
                        controller: _urlCtrl,
                        placeholder: 'Link URL',
                        prefixIcon: Icons.link,
                      ),
                      const SizedBox(height: 10),
                      _StyledField(
                        controller: _urlLabelCtrl,
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
        color: Colors.grey[500],
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
    return TextField(
      controller: controller,
      autofocus: autofocus,
      maxLines: maxLines,
      minLines: minLines,
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
                      child: Image.file(
                        File(path!),
                        width: 48,
                        height: 48,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Container(
                          width: 48,
                          height: 48,
                          color: Colors.grey[200],
                          child: Icon(icon, size: 22, color: Colors.grey[500]),
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
              padding: const EdgeInsets.symmetric(vertical: 10),
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
                children: [
                  Icon(
                    _iconFor(type),
                    size: 22,
                    color: isSelected
                        ? const Color(0xFF007AFF)
                        : Colors.grey[500],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _labelFor(type),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.w500,
                      color: isSelected
                          ? const Color(0xFF007AFF)
                          : Colors.grey[600],
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

  IconData _iconFor(DisplayType type) {
    switch (type) {
      case DisplayType.text:
        return Icons.dashboard_outlined;
      case DisplayType.image:
        return Icons.image_outlined;
      case DisplayType.video:
        return Icons.videocam_outlined;
    }
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
