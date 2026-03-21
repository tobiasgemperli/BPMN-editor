import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../diagram/model/diagram_model.dart';
import '../widgets/process_card.dart';

/// Full-screen presentation mode — swipe vertically through process steps.
/// No app bar — just a minimal close button and step counter overlay.
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

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: dark ? Colors.black : Colors.white,
        body: Stack(
          children: [
            PageView.builder(
              controller: _pageController,
              scrollDirection: Axis.vertical,
              itemCount: _steps.length,
              onPageChanged: (i) {
                setState(() {
                  _currentPage = i;
                  if (i > 0) _showSwipeHint = false;
                });
              },
              itemBuilder: (context, index) {
                return ProcessCard.fromNode(_steps[index],
                    diagram: widget.diagram);
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
            if (_showSwipeHint && _steps.length > 1)
              Positioned(
                bottom: bottomPad + 32,
                left: 0,
                right: 0,
                child: _SwipeHintArrow(dark: dark),
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
