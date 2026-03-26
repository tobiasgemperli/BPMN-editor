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

/// Mini flowchart with equidistant vertical spacing, auto-sized to fit.
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

    const vSpacing = 14.0;
    const padding = 10.0;
    const dotRadius = 4.0;

    // Horizontal: keep relative x positions from the diagram, scaled to fit.
    double minX = double.infinity, maxX = -double.infinity;
    for (final node in steps) {
      final cx = node.rect.center.dx;
      if (cx < minX) minX = cx;
      if (cx > maxX) maxX = cx;
    }
    final diagramW = (maxX - minX).clamp(1.0, double.infinity);

    const maxMapW = 60.0;
    final hScale = diagramW > 1.0 ? (maxMapW - padding) / diagramW : 1.0;

    final mapH = (steps.length - 1) * vSpacing + padding * 2;
    // Actual width used by the scaled x positions.
    final usedW = diagramW * hScale + padding * 2;
    final mapW = usedW.clamp(24.0, maxMapW + padding * 2);

    return Container(
      width: mapW,
      height: mapH,
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
          hScale: hScale,
          vSpacing: vSpacing,
          padding: padding,
          dotRadius: dotRadius,
          mapWidth: mapW,
        ),
      ),
    );
  }
}

class _MiniFlowPainter extends CustomPainter {
  final List<NodeModel> steps;
  final DiagramModel diagram;
  final String currentNodeId;
  final double originX, hScale, vSpacing, padding, dotRadius, mapWidth;

  _MiniFlowPainter({
    required this.steps,
    required this.diagram,
    required this.currentNodeId,
    required this.originX,
    required this.hScale,
    required this.vSpacing,
    required this.padding,
    required this.dotRadius,
    required this.mapWidth,
  });

  Offset _mapNode(int index, NodeModel node) {
    final x = (node.rect.center.dx - originX) * hScale + padding;
    // Center horizontally if all nodes are roughly aligned.
    final y = padding + index * vSpacing;
    return Offset(x, y);
  }

  @override
  void paint(Canvas canvas, Size size) {
    const diamondSize = 5.0;

    final linePaint = Paint()
      ..color = Colors.black26
      ..strokeWidth = 1;

    final currentPaint = Paint()..color = Colors.black;
    final futurePaint = Paint()..color = Colors.black26;

    // Build index lookup for step positions.
    final nodePositions = <String, Offset>{};
    for (int i = 0; i < steps.length; i++) {
      nodePositions[steps[i].id] = _mapNode(i, steps[i]);
    }

    // Draw edges between consecutive steps.
    for (final edge in diagram.edges.values) {
      final src = nodePositions[edge.sourceId];
      final tgt = nodePositions[edge.targetId];
      if (src == null || tgt == null) continue;
      canvas.drawLine(src, tgt, linePaint);
    }

    // Draw nodes on top.
    final bgPaint = Paint()..color = Colors.white;
    for (int i = 0; i < steps.length; i++) {
      final node = steps[i];
      final center = nodePositions[node.id]!;
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
