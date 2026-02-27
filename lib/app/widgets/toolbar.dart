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
    final screenCenter =
        Offset(viewportSize.width / 2, viewportSize.height / 2);

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
          _ToolButton(
            icon: Icons.circle_outlined,
            label: 'Start',
            onPressed: () {
              controller.addNodeNear(
                  NodeType.startEvent, _visibleCenter(context));
            },
          ),
          _ToolButton(
            icon: Icons.check_box_outline_blank_rounded,
            label: 'Step',
            onPressed: () {
              controller.addNodeNear(NodeType.task, _visibleCenter(context));
            },
          ),
          _ToolButton(
            icon: Icons.diamond_outlined,
            label: 'Decision',
            onPressed: () {
              controller.addNodeNear(
                  NodeType.exclusiveGateway, _visibleCenter(context));
            },
          ),
          _ToolButton(
            icon: Icons.radio_button_checked,
            label: 'End',
            onPressed: () {
              controller.addNodeNear(
                  NodeType.endEvent, _visibleCenter(context));
            },
          ),
        ],
      ),
    );
  }
}

class _ToolButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  const _ToolButton({
    required this.icon,
    required this.label,
    required this.onPressed,
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
    widget.onPressed();
    _animController.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurface;

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
