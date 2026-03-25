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
  /// The path the user has taken — grows dynamically as they swipe.
  final List<NodeModel> _path = [];

  /// All diagram nodes, for the mini-map.
  late final List<NodeModel> _allNodes;

  late final PageController _pageController;
  int _currentPage = 0;
  bool _showSwipeHint = true;

  @override
  void initState() {
    super.initState();
    _allNodes = _collectAllNodes(widget.diagram);
    final start = _findStart(widget.diagram);
    if (start != null) {
      _path.add(start);
      _extendPath(start);
    }
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  /// Find the start event node.
  NodeModel? _findStart(DiagramModel diagram) {
    for (final node in diagram.nodes.values) {
      if (node.type == NodeType.startEvent) return node;
    }
    return diagram.nodes.values.firstOrNull;
  }

  /// Collect all nodes via BFS (for the mini-map).
  List<NodeModel> _collectAllNodes(DiagramModel diagram) {
    final start = _findStart(diagram);
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

  /// If the node has exactly one outgoing edge (non-gateway), append
  /// the target so the PageView has a next page to swipe to.
  void _extendPath(NodeModel node) {
    if (node.type == NodeType.exclusiveGateway) return;
    final outgoing = widget.diagram.outgoingEdges(node.id);
    if (outgoing.length == 1) {
      final target = widget.diagram.nodes[outgoing.first.targetId];
      if (target != null) {
        _path.add(target);
      }
    }
  }

  bool _isGatewayPage(int index) {
    if (index < 0 || index >= _path.length) return false;
    return _path[index].type == NodeType.exclusiveGateway &&
        widget.diagram.outgoingEdges(_path[index].id).isNotEmpty;
  }

  /// True if the current page is the last node in the path with no
  /// outgoing edges (end event or dead end).
  bool _isLastStep(int index) {
    if (index < 0 || index >= _path.length) return false;
    return widget.diagram.outgoingEdges(_path[index].id).isEmpty;
  }

  void _jumpToGatewayTarget(NodeModel gatewayNode, int optionIndex) {
    final outgoing = widget.diagram.outgoingEdges(gatewayNode.id);
    if (optionIndex >= outgoing.length) return;
    final target = widget.diagram.nodes[outgoing[optionIndex].targetId];
    if (target == null) return;

    final gatewayIndex = _path.indexOf(gatewayNode);
    if (gatewayIndex < 0) return;

    setState(() {
      // Trim any pages after the gateway and append the chosen target.
      _path.removeRange(gatewayIndex + 1, _path.length);
      _path.add(target);
      _extendPath(target);
    });

    // Animate to the next page (the chosen target).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pageController.animateToPage(
        gatewayIndex + 1,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    });
  }

  /// True if the user is on a gateway that hasn't been resolved yet
  /// (no pages after it in the path).
  bool _isUnresolvedGateway(int index) {
    if (!_isGatewayPage(index)) return false;
    return index == _path.length - 1;
  }

  @override
  Widget build(BuildContext context) {
    if (_path.isEmpty) {
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
    final unresolvedGateway = _isUnresolvedGateway(_currentPage);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Stack(
          children: [
            // The PageView — pages are the user's path through the graph.
            // Gateway pages without a chosen option are the last page,
            // so PageView naturally prevents swiping forward.
            PageView.builder(
              controller: _pageController,
              scrollDirection: Axis.vertical,
              physics: const PageScrollPhysics(),
              itemCount: _path.length,
              onPageChanged: (i) {
                setState(() {
                  _currentPage = i;
                  if (i > 0) _showSwipeHint = false;
                  // When arriving at a new page, extend the path so
                  // there's always a next page to swipe to.
                  if (i == _path.length - 1) {
                    _extendPath(_path[i]);
                  }
                });
              },
              itemBuilder: (context, index) {
                final node = _path[index];
                return ProcessCard.fromNode(
                  node,
                  diagram: widget.diagram,
                  onOptionSelected: (optionIndex) {
                    _jumpToGatewayTarget(node, optionIndex);
                  },
                );
              },
            ),
            // Close button top-left.
            Positioned(
              top: topPad + 8,
              left: 12,
              child: _CloseCircleButton(
                onPressed: () => Navigator.pop(context),
              ),
            ),
            // Mini process map bottom-right.
            Positioned(
              bottom: bottomPad + 16,
              right: 16,
              child: _MiniProcessMap(
                steps: _allNodes,
                diagram: widget.diagram,
                currentNodeId: _path[_currentPage].id,
              ),
            ),
            // Swipe hint on first card.
            if (_showSwipeHint && _path.length > 1 && !unresolvedGateway)
              Positioned(
                bottom: bottomPad + 32,
                left: 0,
                right: 0,
                child: const _SwipeHintArrow(),
              ),
            // "Choose an option" hint on unresolved gateway pages.
            if (unresolvedGateway)
              Positioned(
                bottom: bottomPad + 32,
                left: 0,
                right: 0,
                child: const _ChooseOptionHint(),
              ),
            // Close button on last step.
            if (_isLastStep(_currentPage))
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
  final String currentNodeId;

  const _MiniProcessMap({
    required this.steps,
    required this.diagram,
    required this.currentNodeId,
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

    // Use uniform scale so dots don't get squashed.
    // Fit within max bounds, then derive the other dimension.
    const maxMapH = 90.0;
    const maxMapW = 180.0;
    const padding = 8.0;
    const minDotSpacing = 15.0;

    // Find the minimum spacing in the diagram to ensure dots don't overlap.
    double minNodeDist = double.infinity;
    for (int i = 0; i < steps.length; i++) {
      for (int j = i + 1; j < steps.length; j++) {
        final d = (steps[i].rect.center - steps[j].rect.center).distance;
        if (d > 0 && d < minNodeDist) minNodeDist = d;
      }
    }

    // Scale so the closest pair of dots is at least minDotSpacing apart.
    double scale = minDotSpacing / (minNodeDist.isFinite ? minNodeDist : 1.0);
    // But also fit within max bounds.
    final scaleForW = (maxMapW - padding) / diagramW;
    final scaleForH = (maxMapH - padding) / diagramH;
    scale = scale.clamp(0.0, scaleForW.clamp(0.0, scaleForH));

    final mapWidth = diagramW * scale + padding;
    final mapHeight = diagramH * scale + padding;

    return Container(
      height: mapHeight.clamp(12.0, maxMapH),
      alignment: Alignment.centerRight,
      child: CustomPaint(
        size: Size(mapWidth.clamp(12.0, maxMapW), mapHeight.clamp(12.0, maxMapH)),
        painter: _MiniFlowPainter(
          steps: steps,
          diagram: diagram,
          currentNodeId: currentNodeId,
          originX: minX,
          originY: minY,
          scale: scale,
        ),
      ),
    );
  }
}

class _MiniFlowPainter extends CustomPainter {
  final List<NodeModel> steps;
  final DiagramModel diagram;
  final String currentNodeId;
  final double originX, originY, scale;

  _MiniFlowPainter({
    required this.steps,
    required this.diagram,
    required this.currentNodeId,
    required this.originX,
    required this.originY,
    required this.scale,
  });

  Offset _map(Offset center) => Offset(
        (center.dx - originX) * scale + 4,
        (center.dy - originY) * scale + 4,
      );

  @override
  void paint(Canvas canvas, Size size) {
    const dotRadius = 4.5;
    const diamondSize = 6.0;

    final linePaint = Paint()
      ..color = Colors.black26
      ..strokeWidth = 1;

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
    for (final node in steps) {
      final center = _map(node.rect.center);
      final paint = node.id == currentNodeId ? currentPaint : futurePaint;

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
      oldDelegate.currentNodeId != currentNodeId;
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
