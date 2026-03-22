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
    final onGateway = _isGatewayPage(_currentPage);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: Colors.white,
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
            // Minimal overlay: close + mini process map.
            Positioned(
              top: topPad + 8,
              left: 12,
              right: 16,
              child: Row(
                children: [
                  _CloseCircleButton(
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _MiniProcessMap(
                      steps: _steps,
                      diagram: widget.diagram,
                      currentIndex: _currentPage,
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
                child: const _SwipeHintArrow(),
              ),
            // "Choose an option" hint on gateway pages.
            if (_showChooseHint)
              Positioned(
                bottom: bottomPad + 32,
                left: 0,
                right: 0,
                child: const _ChooseOptionHint(),
              ),
            // Close button on last step.
            if (_currentPage == _steps.length - 1)
              Positioned(
                bottom: bottomPad + 32,
                left: 32,
                right: 32,
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Close',
                        style: TextStyle(fontSize: 17)),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Mini flowchart using the actual diagram node positions, scaled to fit.
class _MiniProcessMap extends StatelessWidget {
  final List<NodeModel> steps;
  final DiagramModel diagram;
  final int currentIndex;

  const _MiniProcessMap({
    required this.steps,
    required this.diagram,
    required this.currentIndex,
  });

  @override
  Widget build(BuildContext context) {
    if (steps.isEmpty) return const SizedBox.shrink();

    // Compute bounding box of all step nodes.
    double minX = double.infinity, minY = double.infinity;
    double maxX = -double.infinity, maxY = -double.infinity;
    for (final node in steps) {
      final c = node.rect.center;
      if (c.dx < minX) minX = c.dx;
      if (c.dy < minY) minY = c.dy;
      if (c.dx > maxX) maxX = c.dx;
      if (c.dy > maxY) maxY = c.dy;
    }

    final diagramW = (maxX - minX).clamp(1.0, double.infinity);
    final diagramH = (maxY - minY).clamp(1.0, double.infinity);
    const mapHeight = 28.0;
    final scale = mapHeight / diagramH;
    final mapWidth = (diagramW * scale).clamp(40.0, 200.0);

    return Container(
      height: 36,
      alignment: Alignment.centerRight,
      child: CustomPaint(
        size: Size(mapWidth, mapHeight),
        painter: _MiniFlowPainter(
          steps: steps,
          diagram: diagram,
          currentIndex: currentIndex,
          originX: minX,
          originY: minY,
          scaleX: (mapWidth - 8) / diagramW,
          scaleY: (mapHeight - 8) / diagramH,
        ),
      ),
    );
  }
}

class _MiniFlowPainter extends CustomPainter {
  final List<NodeModel> steps;
  final DiagramModel diagram;
  final int currentIndex;
  final double originX, originY, scaleX, scaleY;

  _MiniFlowPainter({
    required this.steps,
    required this.diagram,
    required this.currentIndex,
    required this.originX,
    required this.originY,
    required this.scaleX,
    required this.scaleY,
  });

  Offset _map(Offset center) => Offset(
        (center.dx - originX) * scaleX + 4,
        (center.dy - originY) * scaleY + 4,
      );

  @override
  void paint(Canvas canvas, Size size) {
    const dotRadius = 3.0;
    const diamondSize = 4.0;

    final linePaint = Paint()
      ..color = Colors.black26
      ..strokeWidth = 1;

    final visitedPaint = Paint()..color = Colors.black54;
    final currentPaint = Paint()..color = Colors.black;
    final futurePaint = Paint()..color = Colors.black26;

    final stepIds = {for (final s in steps) s.id};

    // Draw edges using waypoints.
    for (final edge in diagram.edges.values) {
      if (!stepIds.contains(edge.sourceId) ||
          !stepIds.contains(edge.targetId)) {
        continue;
      }
      if (edge.waypoints.length >= 2) {
        for (int i = 0; i < edge.waypoints.length - 1; i++) {
          canvas.drawLine(
              _map(edge.waypoints[i]), _map(edge.waypoints[i + 1]), linePaint);
        }
      } else {
        final srcNode = diagram.nodes[edge.sourceId];
        final tgtNode = diagram.nodes[edge.targetId];
        if (srcNode == null || tgtNode == null) continue;
        canvas.drawLine(
            _map(srcNode.rect.center), _map(tgtNode.rect.center), linePaint);
      }
    }

    // Draw nodes on top.
    for (int i = 0; i < steps.length; i++) {
      final node = steps[i];
      final center = _map(node.rect.center);
      final paint = i == currentIndex
          ? currentPaint
          : (i < currentIndex ? visitedPaint : futurePaint);

      if (node.type == NodeType.exclusiveGateway) {
        final path = Path()
          ..moveTo(center.dx, center.dy - diamondSize)
          ..lineTo(center.dx + diamondSize, center.dy)
          ..lineTo(center.dx, center.dy + diamondSize)
          ..lineTo(center.dx - diamondSize, center.dy)
          ..close();
        canvas.drawPath(path, paint);
      } else {
        canvas.drawCircle(center, dotRadius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_MiniFlowPainter oldDelegate) =>
      oldDelegate.currentIndex != currentIndex;
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
  const _SwipeHintArrow();

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
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _offset.value),
          child: Opacity(
            opacity: _opacity.value,
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Swipe up',
                      style: TextStyle(fontSize: 12, color: Colors.white),
                    ),
                    SizedBox(height: 2),
                    Icon(Icons.keyboard_arrow_down,
                        size: 24, color: Colors.white),
                  ],
                ),
              ),
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
