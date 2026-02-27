import 'package:flutter/material.dart';
import '../../diagram/edit/editor_controller.dart';
import '../../diagram/model/diagram_model.dart';

/// Bottom toolbar for adding BPMN elements by tapping.
class EditorToolbar extends StatelessWidget {
  final EditorController controller;
  final TransformationController transformationController;
  final GlobalKey canvasKey;

  const EditorToolbar({
    super.key,
    required this.controller,
    required this.transformationController,
    required this.canvasKey,
  });

  /// Compute the canvas point at the center of the visible canvas viewport.
  Offset _visibleCenter() {
    final renderBox =
        canvasKey.currentContext?.findRenderObject() as RenderBox?;
    final viewportSize = renderBox?.size ?? const Size(400, 600);
    final localCenter =
        Offset(viewportSize.width / 2, viewportSize.height / 2);

    // Invert the InteractiveViewer transform to get canvas coordinates.
    final inverse = Matrix4.inverted(transformationController.value);
    final dx = inverse.storage[0] * localCenter.dx +
        inverse.storage[4] * localCenter.dy +
        inverse.storage[12];
    final dy = inverse.storage[1] * localCenter.dx +
        inverse.storage[5] * localCenter.dy +
        inverse.storage[13];
    return Offset(dx, dy);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final startDisabled = controller.hasStartEvent;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ToolButton(
                icon: Icons.circle_outlined,
                label: 'Start',
                enabled: !startDisabled,
                onPressed: () {
                  controller.addNodeNear(
                      NodeType.startEvent, _visibleCenter());
                },
              ),
              _ToolButton(
                icon: Icons.check_box_outline_blank_rounded,
                label: 'Step',
                onPressed: () {
                  controller.addNodeNear(NodeType.task, _visibleCenter());
                },
              ),
              _ToolButton(
                icon: Icons.diamond_outlined,
                label: 'Decision',
                onPressed: () {
                  controller.addNodeNear(
                      NodeType.exclusiveGateway, _visibleCenter());
                },
              ),
              _ToolButton(
                icon: Icons.radio_button_checked,
                label: 'End',
                onPressed: () {
                  controller.addNodeNear(
                      NodeType.endEvent, _visibleCenter());
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ToolButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool enabled;

  const _ToolButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.enabled = true,
  });

  @override
  State<_ToolButton> createState() => _ToolButtonState();
}

class _ToolButtonState extends State<_ToolButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.85), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 0.85, end: 1.08), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.08, end: 1.0), weight: 30),
    ]).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    ));
    _opacityAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.4), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 0.4, end: 1.0), weight: 70),
    ]).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    ));
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _handleTap() {
    if (!widget.enabled) return;
    widget.onPressed();
    _animController.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.enabled
        ? Theme.of(context).colorScheme.onSurface
        : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3);

    return GestureDetector(
      onTapDown: (_) => _handleTap(),
      child: AnimatedBuilder(
        animation: _animController,
        builder: (context, child) {
          return Opacity(
            opacity: _animController.isAnimating
                ? _opacityAnimation.value
                : 1.0,
            child: Transform.scale(
              scale: _animController.isAnimating
                  ? _scaleAnimation.value
                  : 1.0,
              child: child,
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon, color: color, size: 28),
              const SizedBox(height: 2),
              Text(
                widget.label,
                style: TextStyle(
                    color: color, fontSize: 11, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
