import 'package:flutter/material.dart';
import '../../diagram/edit/editor_controller.dart';
import '../../diagram/model/diagram_model.dart';

/// Bottom toolbar for adding BPMN elements by tapping.
class EditorToolbar extends StatelessWidget {
  final EditorController controller;
  final TransformationController transformationController;

  const EditorToolbar({
    super.key,
    required this.controller,
    required this.transformationController,
  });

  /// Compute the canvas point at the center of the visible viewport.
  Offset _visibleCenter(BuildContext context) {
    final renderBox = context.findAncestorRenderObjectOfType<RenderBox>();
    final viewportSize = renderBox?.size ?? MediaQuery.of(context).size;
    final screenCenter = Offset(viewportSize.width / 2, viewportSize.height / 2);

    // Invert the transformation to get canvas coordinates.
    final inverse = Matrix4.inverted(transformationController.value);
    final dx = inverse.storage[0] * screenCenter.dx +
        inverse.storage[4] * screenCenter.dy +
        inverse.storage[12];
    final dy = inverse.storage[1] * screenCenter.dx +
        inverse.storage[5] * screenCenter.dy +
        inverse.storage[13];
    return Offset(dx, dy);
  }

  @override
  Widget build(BuildContext context) {
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
            type: NodeType.startEvent,
          ),
          _toolButton(
            context,
            icon: Icons.check_box_outline_blank_rounded,
            label: 'Step',
            type: NodeType.task,
          ),
          _toolButton(
            context,
            icon: Icons.diamond_outlined,
            label: 'Decision',
            type: NodeType.exclusiveGateway,
          ),
          _toolButton(
            context,
            icon: Icons.radio_button_checked,
            label: 'End',
            type: NodeType.endEvent,
          ),
        ],
      ),
    );
  }

  Widget _toolButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required NodeType type,
  }) {
    final color = Theme.of(context).colorScheme.onSurface;

    return GestureDetector(
      onTapDown: (_) {
        final center = _visibleCenter(context);
        controller.addNodeNear(type, center);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                  color: color, fontSize: 11, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}
