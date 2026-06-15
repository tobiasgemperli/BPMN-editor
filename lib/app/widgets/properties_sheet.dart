import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../diagram/edit/editor_controller.dart';
import '../../diagram/model/diagram_model.dart';

/// The display type determines how a task card renders in presentation mode.
enum DisplayType { text, image, document, video }

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
  late final TextEditingController _titleCtrl;
  late final TextEditingController _textCtrl;
  late final TextEditingController _imageCtrl;
  late final TextEditingController _videoCtrl;
  late final TextEditingController _urlCtrl;
  late final TextEditingController _urlLabelCtrl;

  late DisplayType _displayType;
  final _picker = ImagePicker();

  // Gateway outgoing edge label controllers.
  final Map<String, TextEditingController> _edgeLabelCtrls = {};
  late final List<EdgeModel> _outgoingEdges;

  bool get _isTask => widget.node.type == NodeType.task;
  bool get _isGateway => widget.node.type == NodeType.exclusiveGateway;

  @override
  void initState() {
    super.initState();
    final c = widget.node.content;
    _nameCtrl = TextEditingController(text: widget.node.name);
    _titleCtrl = TextEditingController(text: c?.title ?? '');
    _textCtrl = TextEditingController(text: c?.text ?? '');
    _imageCtrl = TextEditingController(text: c?.imagePath ?? '');
    _videoCtrl = TextEditingController(text: c?.videoPath ?? '');
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
    if (c.videoPath != null) return DisplayType.video;
    if (c.imagePath != null && (c.text != null || c.linkUrl != null)) {
      return DisplayType.document;
    }
    if (c.imagePath != null) return DisplayType.image;
    if (c.linkUrl != null || c.links.isNotEmpty) return DisplayType.document;
    return DisplayType.text;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _titleCtrl.dispose();
    _textCtrl.dispose();
    _imageCtrl.dispose();
    _videoCtrl.dispose();
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

  Future<void> _pickImage() async {
    final file = await _picker.pickImage(source: ImageSource.gallery);
    if (file != null) {
      setState(() => _imageCtrl.text = file.path);
    }
  }

  Future<void> _pickVideo() async {
    final file = await _picker.pickVideo(source: ImageSource.gallery);
    if (file != null) {
      setState(() => _videoCtrl.text = file.path);
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

    if (_isTask) {
      final title = _titleCtrl.text.isNotEmpty ? _titleCtrl.text : null;
      final text = _textCtrl.text.isNotEmpty ? _textCtrl.text : null;

      String? image;
      String? video;
      String? url;
      String? urlLabel;

      switch (_displayType) {
        case DisplayType.image:
          image = _imageCtrl.text.isNotEmpty ? _imageCtrl.text : null;
          break;
        case DisplayType.document:
          image = _imageCtrl.text.isNotEmpty ? _imageCtrl.text : null;
          url = _urlCtrl.text.isNotEmpty ? _urlCtrl.text : null;
          urlLabel = _urlLabelCtrl.text.isNotEmpty ? _urlLabelCtrl.text : null;
          break;
        case DisplayType.video:
          video = _videoCtrl.text.isNotEmpty ? _videoCtrl.text : null;
          break;
        case DisplayType.text:
          break;
      }

      final content = TaskContent(
        title: title,
        text: text,
        imagePath: image,
        videoPath: video,
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

                  // ── Display type picker (task only) ──
                  if (_isTask) ...[
                    const SizedBox(height: 20),
                    _SectionLabel(label: 'Display'),
                    const SizedBox(height: 8),
                    _DisplayTypePicker(
                      selected: _displayType,
                      onChanged: (t) => setState(() => _displayType = t),
                    ),

                    // ── Content fields ──
                    const SizedBox(height: 20),
                    _SectionLabel(label: 'Content'),
                    const SizedBox(height: 8),

                    // Title — all types.
                    _StyledField(
                      controller: _titleCtrl,
                      placeholder: 'Title (optional)',
                    ),
                    const SizedBox(height: 10),

                    // Body text — text, document, video.
                    if (_displayType != DisplayType.image) ...[
                      _StyledField(
                        controller: _textCtrl,
                        placeholder: 'Body text...',
                        maxLines: 6,
                        minLines: 3,
                      ),
                      const SizedBox(height: 10),
                    ],

                    // Image — image, document.
                    if (_displayType == DisplayType.image ||
                        _displayType == DisplayType.document) ...[
                      _MediaPickerField(
                        path: _imageCtrl.text.isEmpty ? null : _imageCtrl.text,
                        label: 'Photo',
                        icon: Icons.image_outlined,
                        onPick: () => _pickImage(),
                        onClear: () => setState(() => _imageCtrl.text = ''),
                      ),
                      const SizedBox(height: 10),
                    ],

                    // Video — video.
                    if (_displayType == DisplayType.video) ...[
                      _MediaPickerField(
                        path: _videoCtrl.text.isEmpty ? null : _videoCtrl.text,
                        label: 'Video',
                        icon: Icons.videocam_outlined,
                        onPick: () => _pickVideo(),
                        onClear: () => setState(() => _videoCtrl.text = ''),
                      ),
                      const SizedBox(height: 10),
                    ],

                    // Link — document.
                    if (_displayType == DisplayType.document) ...[
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
        return Icons.text_fields;
      case DisplayType.image:
        return Icons.image_outlined;
      case DisplayType.document:
        return Icons.article_outlined;
      case DisplayType.video:
        return Icons.videocam_outlined;
    }
  }

  String _labelFor(DisplayType type) {
    switch (type) {
      case DisplayType.text:
        return 'Text';
      case DisplayType.image:
        return 'Image';
      case DisplayType.document:
        return 'Document';
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
