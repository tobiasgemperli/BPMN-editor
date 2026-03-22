import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../diagram/model/diagram_model.dart';
import '../widgets/process_card.dart';

/// Full-screen presentation mode — swipe vertically through process steps.
class PresentationScreen extends StatefulWidget {
  final DiagramModel diagram;

  const PresentationScreen({super.key, required this.diagram});

  @override
  State<PresentationScreen> createState() => _PresentationScreenState();
}

class _PresentationScreenState extends State<PresentationScreen> {
  late final List<NodeModel> _steps;
  late final PageController _pageController;
  int _currentPage = 0;
  bool _showSwipeHint = true;
  bool _showChooseHint = false;

  @override
  void initState() {
    super.initState();
    _steps = _buildStepOrder(widget.diagram);
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  bool _isGatewayPage(int index) {
    if (index < 0 || index >= _steps.length) return false;
    return _steps[index].type == NodeType.exclusiveGateway &&
        widget.diagram.outgoingEdges(_steps[index].id).isNotEmpty;
  }

  List<NodeModel> _buildStepOrder(DiagramModel diagram) {
    NodeModel? start;
    for (final node in diagram.nodes.values) {
      if (node.type == NodeType.startEvent) {
        start = node;
        break;
      }
    }

    if (start == null) return diagram.nodes.values.toList();

    final ordered = <NodeModel>[];
    final visited = <String>{};
    final queue = <String>[start.id];

    while (queue.isNotEmpty) {
      final id = queue.removeAt(0);
      if (visited.contains(id)) continue;
      visited.add(id);

      final node = diagram.nodes[id];
      if (node == null) continue;
      ordered.add(node);

      final outgoing = diagram.outgoingEdges(id);
      outgoing.sort((a, b) => a.name.compareTo(b.name));
      for (final edge in outgoing) {
        if (!visited.contains(edge.targetId)) {
          queue.add(edge.targetId);
        }
      }
    }

    for (final node in diagram.nodes.values) {
      if (!visited.contains(node.id)) {
        ordered.add(node);
      }
    }

    return ordered;
  }

  void _jumpToGatewayTarget(NodeModel gatewayNode, int optionIndex) {
    final outgoing = widget.diagram.outgoingEdges(gatewayNode.id);
    if (optionIndex >= outgoing.length) return;
    final targetId = outgoing[optionIndex].targetId;
    final targetIndex = _steps.indexWhere((n) => n.id == targetId);
    if (targetIndex >= 0) {
      _pageController.jumpToPage(targetIndex);
    }
  }

  void _onSwipeAttemptOnGateway() {
    if (_showChooseHint) return;
    setState(() => _showChooseHint = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _showChooseHint = false);
    });
  }

  bool _isDarkBg(NodeModel node) {
    return node.content?.videoPath != null;
  }

  @override
  Widget build(BuildContext context) {
    if (_steps.isEmpty) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('No steps in diagram'),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Back'),
              ),
            ],
          ),
        ),
      );
    }

    final topPad = MediaQuery.of(context).padding.top;
    final bottomPad = MediaQuery.of(context).padding.bottom;
    final dark = _isDarkBg(_steps[_currentPage]);
    final onGateway = _isGatewayPage(_currentPage);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: dark ? Colors.black : Colors.white,
        body: Stack(
          children: [
            // Swipe detector layer — catches swipe attempts on gateway pages.
            if (onGateway)
              GestureDetector(
                behavior: HitTestBehavior.translucent,
                onVerticalDragUpdate: (_) => _onSwipeAttemptOnGateway(),
                child: const SizedBox.expand(),
              ),
            // The PageView — disabled physics on gateway pages.
            PageView.builder(
              controller: _pageController,
              scrollDirection: Axis.vertical,
              physics: onGateway
                  ? const NeverScrollableScrollPhysics()
                  : const PageScrollPhysics(),
              itemCount: _steps.length,
              onPageChanged: (i) {
                setState(() {
                  _currentPage = i;
                  _showChooseHint = false;
                  if (i > 0) _showSwipeHint = false;
                });
              },
              itemBuilder: (context, index) {
                final node = _steps[index];
                return ProcessCard.fromNode(
                  node,
                  diagram: widget.diagram,
                  onOptionSelected: (optionIndex) {
                    _jumpToGatewayTarget(node, optionIndex);
                  },
                );
              },
            ),
            // Minimal overlay: close + counter.
            Positioned(
              top: topPad + 8,
              left: 12,
              right: 16,
              child: Row(
                children: [
                  _CloseCircleButton(
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${_currentPage + 1} / ${_steps.length}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black54,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Swipe hint on first card.
            if (_showSwipeHint && _steps.length > 1 && !onGateway)
              Positioned(
                bottom: bottomPad + 32,
                left: 0,
                right: 0,
                child: _SwipeHintArrow(dark: dark),
              ),
            // "Choose an option" hint on gateway pages.
            if (_showChooseHint)
              Positioned(
                bottom: bottomPad + 32,
                left: 0,
                right: 0,
                child: const _ChooseOptionHint(),
              ),
          ],
        ),
      ),
    );
  }
}

class _CloseCircleButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _CloseCircleButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.7),
        ),
        child: const Icon(Icons.close, size: 20, color: Colors.black54),
      ),
    );
  }
}

/// Blinking down-arrow hint shown on the first card only.
class _SwipeHintArrow extends StatefulWidget {
  final bool dark;

  const _SwipeHintArrow({required this.dark});

  @override
  State<_SwipeHintArrow> createState() => _SwipeHintArrowState();
}

class _SwipeHintArrowState extends State<_SwipeHintArrow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<double> _offset;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _opacity = Tween(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _offset = Tween(begin: 0.0, end: 8.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.dark ? Colors.white : Colors.black54;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _offset.value),
          child: Opacity(
            opacity: _opacity.value,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Swipe up',
                  style: TextStyle(fontSize: 12, color: color),
                ),
                const SizedBox(height: 4),
                Icon(Icons.keyboard_arrow_down, size: 28, color: color),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Hint shown when user tries to swipe on a gateway card.
/// Arrow points up toward the option buttons.
class _ChooseOptionHint extends StatefulWidget {
  const _ChooseOptionHint();

  @override
  State<_ChooseOptionHint> createState() => _ChooseOptionHintState();
}

class _ChooseOptionHintState extends State<_ChooseOptionHint>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<double> _offset;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    _opacity = Tween(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _offset = Tween(begin: 0.0, end: -6.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _offset.value),
          child: Opacity(
            opacity: _opacity.value,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.keyboard_arrow_up,
                    size: 28, color: Colors.amber[800]),
                const SizedBox(height: 2),
                Text(
                  'Please choose an option',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.amber[800],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
