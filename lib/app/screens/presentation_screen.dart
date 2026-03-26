import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../diagram/model/diagram_model.dart';
import '../../diagram/samples/sample_diagrams.dart';
import '../widgets/close_circle_button.dart';
import '../widgets/process_card.dart';
import 'discover_screen.dart' show dismissToDashboard;
import 'editor_screen.dart';

/// Full-screen presentation mode — swipe vertically through process steps.
class PresentationScreen extends StatefulWidget {
  final DiagramModel diagram;
  final String? title;
  final DiagramRole role;
  final SampleCreator? creator;

  const PresentationScreen({
    super.key,
    required this.diagram,
    this.title,
    this.role = DiagramRole.owner,
    this.creator,
  });

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

  void _openEditor(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EditorScreen(
          initialDiagram: widget.diagram,
          title: widget.title,
          role: widget.role,
          creator: widget.creator,
          showBackButton: true,
        ),
      ),
    );
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
    // Clamp in case _path was trimmed after _currentPage was set.
    final safePage = _currentPage.clamp(0, _path.length - 1);
    final unresolvedGateway = _isUnresolvedGateway(safePage);

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
                  // When swiping back to a gateway, trim the path after it
                  // so the user must choose again.
                  if (_isGatewayPage(i) && i < _path.length - 1) {
                    _path.removeRange(i + 1, _path.length);
                  }
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
            // Close button top-right — pops to dashboard.
            Positioned(
              top: topPad + 8,
              right: 16,
              child: CloseCircleButton(
                onPressed: () => dismissToDashboard(context),
              ),
            ),
            // Mini process map bottom-right — tap to open full view.
            Positioned(
              bottom: bottomPad + 16,
              right: 16,
              child: GestureDetector(
                onTap: () => _openEditor(context),
                child: _MiniProcessMap(
                  steps: _allNodes,
                  diagram: widget.diagram,
                  currentNodeId: _path[safePage].id,
                ),
              ),
            ),
            // Swipe hint on first card.
            if (_showSwipeHint && _path.length > 1 && !unresolvedGateway)
              Positioned(
                bottom: bottomPad + 16,
                left: 0,
                right: 0,
                child: _SwipeHintArrow(
                  onTap: () {
                    _pageController.nextPage(
                      duration: const Duration(milliseconds: 350),
                      curve: Curves.easeInOut,
                    );
                  },
                ),
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
            if (_isLastStep(safePage))
              Positioned(
                bottom: bottomPad + 32,
                left: 0,
                right: 0,
                child: Center(
                  child: SizedBox(
                    width: 140,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                      child: const Text('Close',
                          style: TextStyle(fontSize: 16)),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Mini flowchart with uniform dot density across all diagrams.
/// Uses a fixed target spacing per edge so every miniature looks similar
/// regardless of node count or original layout.
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

    // Target spacing: every connected pair of nodes should be ~targetDist apart.
    const targetDist = 16.0;
    const padding = 8.0;

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

    // Compute average edge length in the original diagram.
    final stepIds = {for (final s in steps) s.id};
    double totalDist = 0;
    int edgeCount = 0;
    for (final edge in diagram.edges.values) {
      if (!stepIds.contains(edge.sourceId) ||
          !stepIds.contains(edge.targetId)) continue;
      final src = diagram.nodes[edge.sourceId];
      final tgt = diagram.nodes[edge.targetId];
      if (src == null || tgt == null) continue;
      totalDist += (src.rect.center - tgt.rect.center).distance;
      edgeCount++;
    }
    final avgDist = edgeCount > 0 ? totalDist / edgeCount : diagramH;

    // Scale so the average edge length maps to targetDist.
    final scale = targetDist / avgDist;

    final mapW = diagramW * scale + padding * 2;
    final mapH = diagramH * scale + padding * 2;

    return Container(
      width: mapW + 12,
      height: mapH + 12,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: CustomPaint(
        size: Size(mapW, mapH),
        painter: _MiniFlowPainter(
          steps: steps,
          diagram: diagram,
          currentNodeId: currentNodeId,
          originX: minX,
          originY: minY,
          scale: scale,
          padding: padding,
        ),
      ),
    );
  }
}

class _MiniFlowPainter extends CustomPainter {
  final List<NodeModel> steps;
  final DiagramModel diagram;
  final String currentNodeId;
  final double originX, originY, scale, padding;

  _MiniFlowPainter({
    required this.steps,
    required this.diagram,
    required this.currentNodeId,
    required this.originX,
    required this.originY,
    required this.scale,
    required this.padding,
  });

  Offset _map(Offset center) => Offset(
        (center.dx - originX) * scale + padding,
        (center.dy - originY) * scale + padding,
      );

  @override
  void paint(Canvas canvas, Size size) {
    const dotRadius = 4.0;
    const diamondSize = 5.5;

    final linePaint = Paint()
      ..color = Colors.black26
      ..strokeWidth = 1;

    final currentPaint = Paint()..color = Colors.black;
    final futurePaint = Paint()..color = Colors.black26;

    final stepIds = {for (final s in steps) s.id};

    // Draw edges.
    for (final edge in diagram.edges.values) {
      if (!stepIds.contains(edge.sourceId) ||
          !stepIds.contains(edge.targetId)) {
        continue;
      }
      final srcNode = diagram.nodes[edge.sourceId];
      final tgtNode = diagram.nodes[edge.targetId];
      if (srcNode == null || tgtNode == null) continue;

      final points = <Offset>[
        _map(srcNode.rect.center),
        if (edge.waypoints.length >= 3)
          for (int i = 1; i < edge.waypoints.length - 1; i++)
            _map(edge.waypoints[i]),
        _map(tgtNode.rect.center),
      ];
      for (int i = 0; i < points.length - 1; i++) {
        canvas.drawLine(points[i], points[i + 1], linePaint);
      }
    }

    // Draw nodes on top.
    final bgPaint = Paint()..color = Colors.white;
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
        canvas.drawPath(path, bgPaint);
        canvas.drawPath(path, paint);
      } else {
        canvas.drawCircle(center, dotRadius, bgPaint);
        canvas.drawCircle(center, dotRadius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_MiniFlowPainter oldDelegate) =>
      oldDelegate.currentNodeId != currentNodeId;
}

/// Pulsating chevron hint — tappable to go to next page.
class _SwipeHintArrow extends StatefulWidget {
  final VoidCallback onTap;

  const _SwipeHintArrow({required this.onTap});

  @override
  State<_SwipeHintArrow> createState() => _SwipeHintArrowState();
}

class _SwipeHintArrowState extends State<_SwipeHintArrow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _opacity = Tween(begin: 0.2, end: 1.0).animate(
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
    return GestureDetector(
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Opacity(
            opacity: _opacity.value,
            child: const Center(
              child: Icon(Icons.keyboard_arrow_down,
                  size: 40, color: Colors.black),
            ),
          );
        },
      ),
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
                const Icon(Icons.keyboard_arrow_up,
                    size: 28, color: Colors.black54),
                const SizedBox(height: 2),
                const Text(
                  'Please choose an option',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.black54,
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
