import 'package:flutter/material.dart';
import '../../diagram/edit/editor_controller.dart';

/// Bottom toolbar for selecting BPMN element types to place.
class EditorToolbar extends StatelessWidget {
  final EditorController controller;

  const EditorToolbar({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        return Container(
          padding: EdgeInsets.only(
            left: 8,
            right: 8,
            bottom: MediaQuery.of(context).padding.bottom + 4,
            top: 4,
          ),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 8,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _toolButton(
                context,
                icon: Icons.circle_outlined,
                label: 'Start',
                tool: EditorTool.addStart,
              ),
              _toolButton(
                context,
                icon: Icons.check_box_outline_blank_rounded,
                label: 'Step',
                tool: EditorTool.addTask,
              ),
              _toolButton(
                context,
                icon: Icons.diamond_outlined,
                label: 'Decision',
                tool: EditorTool.addGateway,
              ),
              _toolButton(
                context,
                icon: Icons.radio_button_checked,
                label: 'End',
                tool: EditorTool.addEnd,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _toolButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required EditorTool tool,
  }) {
    final isActive = controller.activeTool == tool;
    final color = isActive
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.onSurface;

    return GestureDetector(
      onTapDown: (_) {
        controller.setTool(isActive ? EditorTool.select : tool);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isActive
              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}
