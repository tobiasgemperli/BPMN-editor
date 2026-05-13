import 'package:flutter/material.dart';
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
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _NodeEditorSheet(node: node, controller: controller),
  );
}

class _NodeEditorSheet extends StatefulWidget {
  final NodeModel node;
  final EditorController controller;

  const _NodeEditorSheet({required this.node, required this.controller});

  @override
  State<_NodeEditorSheet> createState() => _NodeEditorSheetState();
}

class _NodeEditorSheetState extends State<_NodeEditorSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _titleCtrl;
  late final TextEditingController _textCtrl;
  late final TextEditingController _imageCtrl;
  late final TextEditingController _videoCtrl;
  late final TextEditingController _urlCtrl;
  late final TextEditingController _urlLabelCtrl;

  late DisplayType _displayType;

  bool get _isTask => widget.node.type == NodeType.task;

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
    super.dispose();
  }

  void _save() {
    widget.controller.renameNode(widget.node.id, _nameCtrl.text);

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
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar.
          Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 6),
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Header with type badge and save.
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 12, 0),
            child: Row(
              children: [
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
          Flexible(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                  20, 0, 20, (bottomInset > 0 ? bottomInset : bottomPad) + 16),
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
                      _StyledField(
                        controller: _imageCtrl,
                        placeholder: 'Image path or URL',
                        prefixIcon: Icons.image_outlined,
                      ),
                      const SizedBox(height: 10),
                    ],

                    // Video — video.
                    if (_displayType == DisplayType.video) ...[
                      _StyledField(
                        controller: _videoCtrl,
                        placeholder: 'Video path',
                        prefixIcon: Icons.videocam_outlined,
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

  const _StyledField({
    required this.controller,
    required this.placeholder,
    this.maxLines = 1,
    this.minLines = 1,
    this.autofocus = false,
    this.style,
    this.prefixIcon,
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
