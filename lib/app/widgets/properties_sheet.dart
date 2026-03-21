import 'package:flutter/material.dart';
import '../../diagram/edit/editor_controller.dart';
import '../../diagram/model/diagram_model.dart';

/// Shows a bottom sheet to edit node properties (name + content for tasks).
void showPropertiesSheet(BuildContext context, EditorController controller) {
  final nodeId = controller.selectedNodeId;
  if (nodeId == null) return;

  final node = controller.diagram.nodes[nodeId];
  if (node == null) return;

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (context) {
      return _PropertiesSheetContent(
        node: node,
        controller: controller,
      );
    },
  );
}

class _PropertiesSheetContent extends StatefulWidget {
  final NodeModel node;
  final EditorController controller;

  const _PropertiesSheetContent({
    required this.node,
    required this.controller,
  });

  @override
  State<_PropertiesSheetContent> createState() =>
      _PropertiesSheetContentState();
}

class _PropertiesSheetContentState extends State<_PropertiesSheetContent> {
  late final TextEditingController _nameController;
  late final TextEditingController _titleController;
  late final TextEditingController _textController;
  late final TextEditingController _imageController;
  late final TextEditingController _videoController;
  late final TextEditingController _urlController;
  late final TextEditingController _urlLabelController;

  bool get _isTask => widget.node.type == NodeType.task;

  @override
  void initState() {
    super.initState();
    final content = widget.node.content;
    _nameController = TextEditingController(text: widget.node.name);
    _titleController = TextEditingController(text: content?.title ?? '');
    _textController = TextEditingController(text: content?.text ?? '');
    _imageController = TextEditingController(text: content?.imagePath ?? '');
    _videoController = TextEditingController(text: content?.videoPath ?? '');
    _urlController = TextEditingController(text: content?.linkUrl ?? '');
    _urlLabelController =
        TextEditingController(text: content?.linkLabel ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _titleController.dispose();
    _textController.dispose();
    _imageController.dispose();
    _videoController.dispose();
    _urlController.dispose();
    _urlLabelController.dispose();
    super.dispose();
  }

  void _save() {
    widget.controller.renameNode(widget.node.id, _nameController.text);

    if (_isTask) {
      final title =
          _titleController.text.isNotEmpty ? _titleController.text : null;
      final text =
          _textController.text.isNotEmpty ? _textController.text : null;
      final image =
          _imageController.text.isNotEmpty ? _imageController.text : null;
      final video =
          _videoController.text.isNotEmpty ? _videoController.text : null;
      final url =
          _urlController.text.isNotEmpty ? _urlController.text : null;
      final urlLabel =
          _urlLabelController.text.isNotEmpty ? _urlLabelController.text : null;

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
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _typeLabel(widget.node.type),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              'ID: ${widget.node.id}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey,
                  ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Name',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) => _save(),
            ),
            if (_isTask) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _textController,
                decoration: const InputDecoration(
                  labelText: 'Text',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                maxLines: 4,
                minLines: 2,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _imageController,
                decoration: InputDecoration(
                  labelText: 'Image path',
                  border: const OutlineInputBorder(),
                  suffixIcon: _imageController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            setState(() => _imageController.clear());
                          },
                        )
                      : null,
                ),
                onChanged: (val) {
                  if (val.isNotEmpty) {
                    setState(() => _videoController.clear());
                  }
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _videoController,
                decoration: InputDecoration(
                  labelText: 'Video path',
                  border: const OutlineInputBorder(),
                  suffixIcon: _videoController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            setState(() => _videoController.clear());
                          },
                        )
                      : null,
                ),
                onChanged: (val) {
                  if (val.isNotEmpty) {
                    setState(() => _imageController.clear());
                  }
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _urlController,
                decoration: const InputDecoration(
                  labelText: 'URL',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _urlLabelController,
                decoration: const InputDecoration(
                  labelText: 'URL label',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _save,
                child: const Text('Save'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _typeLabel(NodeType type) {
  switch (type) {
    case NodeType.startEvent:
      return 'Start Event';
    case NodeType.endEvent:
      return 'End Event';
    case NodeType.task:
      return 'Task';
    case NodeType.exclusiveGateway:
      return 'Exclusive Gateway';
  }
}
