import 'package:flutter/material.dart';
import '../../diagram/edit/editor_controller.dart';
import '../../diagram/model/diagram_model.dart';

/// Shows a bottom sheet to edit node properties (name).
void showPropertiesSheet(BuildContext context, EditorController controller) {
  final nodeId = controller.selectedNodeId;
  if (nodeId == null) return;

  final node = controller.diagram.nodes[nodeId];
  if (node == null) return;

  final textController = TextEditingController(text: node.name);

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (context) {
      return Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _typeLabel(node.type),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              'ID: ${node.id}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey,
                  ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: textController,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Name',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (value) {
                controller.renameNode(nodeId, value);
                Navigator.pop(context);
              },
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  controller.renameNode(nodeId, textController.text);
                  Navigator.pop(context);
                },
                child: const Text('Save'),
              ),
            ),
          ],
        ),
      );
    },
  );
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
