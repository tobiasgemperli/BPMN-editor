import 'package:flutter/material.dart';
import '../../diagram/model/diagram_model.dart';
import '../../diagram/samples/sample_diagrams.dart';
import '../widgets/diagram_embed.dart';
import '../widgets/mini_process_map.dart';

/// Web showcase page with multiple embedded process steppers and
/// a landscape diagram view.
class EmbedShowcaseScreen extends StatelessWidget {
  const EmbedShowcaseScreen({super.key});

  static const _samples = [
    ('Content Showcase', SampleDiagrams.contentShowcase),
    ('IKEA KALLAX Assembly', SampleDiagrams.ikeaAssembly),
    ('Coffee Brewing Guide', SampleDiagrams.coffeeBrewing),
    ('CI/CD Pipeline', SampleDiagrams.cicdPipeline),
    ('Emergency: Fire Evacuation', SampleDiagrams.emergencyProcedure),
    ('FDA 510(k) Clearance', SampleDiagrams.fda510k),
    ('Car Import USA → Germany', SampleDiagrams.carImportUSA),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      body: CustomScrollView(
        slivers: [
          // Header.
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(40, 56, 40, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Embedded Process Views',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Interactive step-by-step process embeds. '
                    'Press Continue to advance through each process.',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Stepper embeds — single column, limited width.
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(32, 24, 32, 32),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final (title, builder) = _samples[index];
                  return Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 720),
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 24),
                        child: AspectRatio(
                          aspectRatio: 1.5,
                          child: _FramedStepper(
                              title: title, builder: builder),
                        ),
                      ),
                    ),
                  );
                },
                childCount: _samples.length,
              ),
            ),
          ),

          // Landscape diagram section.
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(40, 16, 40, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Landscape Diagrams',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Full process diagrams rendered horizontally.',
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(32, 16, 32, 56),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final (title, builder) = _samples[index];
                  final diagram = _toLandscape(builder());
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(left: 8, bottom: 8),
                          child: Text(
                            title,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        SizedBox(
                          height: 220,
                          child: DiagramEmbed(diagram: diagram),
                        ),
                      ],
                    ),
                  );
                },
                childCount: _samples.length,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Transform a portrait (top-down) diagram to landscape (left-to-right)
  /// by swapping X and Y coordinates.
  static DiagramModel _toLandscape(DiagramModel diagram) {
    final nodes = <String, NodeModel>{};
    for (final entry in diagram.nodes.entries) {
      final n = entry.value;
      final c = n.rect.center;
      // Swap x/y; make task boxes landscape-shaped (wider, shorter).
      final newCenter = Offset(c.dy, c.dx);
      final isTask = n.type == NodeType.task;
      final newW = isTask
          ? (n.rect.width > n.rect.height ? n.rect.width : n.rect.height) * 1.2
          : n.rect.height;
      final newH = isTask
          ? (n.rect.width < n.rect.height ? n.rect.width : n.rect.height) * 0.7
          : n.rect.width;
      nodes[entry.key] = NodeModel(
        id: n.id,
        type: n.type,
        name: n.name,
        rect: Rect.fromCenter(center: newCenter, width: newW, height: newH),
        content: n.content,
      );
    }

    final edges = <String, EdgeModel>{};
    for (final entry in diagram.edges.entries) {
      final e = entry.value;
      edges[entry.key] = EdgeModel(
        id: e.id,
        sourceId: e.sourceId,
        targetId: e.targetId,
        waypoints: e.waypoints.map((p) => Offset(p.dy, p.dx)).toList(),
        name: e.name,
      );
    }

    return DiagramModel(nodes: nodes, edges: edges);
  }
}

typedef _DiagramBuilder = DiagramModel Function();

/// A framed stepper embed with Continue button and slide-in transitions.
class _FramedStepper extends StatefulWidget {
  final String title;
  final _DiagramBuilder builder;

  const _FramedStepper({required this.title, required this.builder});

  @override
  State<_FramedStepper> createState() => _FramedStepperState();
}

class _FramedStepperState extends State<_FramedStepper> {
  late final DiagramModel _diagram;
  late List<NodeModel> _steps;
  late final List<NodeModel> _allNodes;
  int _currentStep = 0;
  bool _animatingForward = true;

  @override
  void initState() {
    super.initState();
    _diagram = EmbedShowcaseScreen._toLandscape(widget.builder());
    _steps = _buildPath(_diagram);
    _allNodes = _collectAllNodes(_diagram);
  }

  List<NodeModel> _collectAllNodes(DiagramModel diagram) {
    NodeModel? start;
    for (final node in diagram.nodes.values) {
      if (node.type == NodeType.startEvent) {
        start = node;
        break;
      }
    }
    start ??= diagram.nodes.values.firstOrNull;
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
      for (final edge in diagram.outgoingEdges(id)) {
        if (!visited.contains(edge.targetId)) queue.add(edge.targetId);
      }
    }
    return ordered;
  }

  List<NodeModel> _buildPath(DiagramModel diagram) {
    NodeModel? start;
    for (final node in diagram.nodes.values) {
      if (node.type == NodeType.startEvent) {
        start = node;
        break;
      }
    }
    start ??= diagram.nodes.values.firstOrNull;
    if (start == null) return [];

    final path = <NodeModel>[start];
    final visited = <String>{start.id};

    var current = start;
    while (true) {
      final outgoing = diagram.outgoingEdges(current.id);
      if (outgoing.isEmpty) break;

      // Stop at gateways — user must choose an option.
      if (current.type == NodeType.exclusiveGateway) break;

      if (outgoing.length == 1) {
        final target = diagram.nodes[outgoing.first.targetId];
        if (target == null || visited.contains(target.id)) break;
        visited.add(target.id);
        path.add(target);
        current = target;
      } else {
        break;
      }
    }
    return path;
  }

  /// Extend the path linearly from a node (follow single-outgoing edges).
  void _extendPath(List<NodeModel> path, Set<String> visited) {
    while (true) {
      final current = path.last;
      if (current.type == NodeType.exclusiveGateway) break;
      final outgoing = _diagram.outgoingEdges(current.id);
      if (outgoing.length != 1) break;
      final target = _diagram.nodes[outgoing.first.targetId];
      if (target == null || visited.contains(target.id)) break;
      visited.add(target.id);
      path.add(target);
    }
  }

  void _handleGatewayOption(int optionIndex) {
    final gatewayNode = _steps[_currentStep];
    final outgoing = _diagram.outgoingEdges(gatewayNode.id);
    if (optionIndex >= outgoing.length) return;
    final target = _diagram.nodes[outgoing[optionIndex].targetId];
    if (target == null) return;

    setState(() {
      // Trim everything after the gateway.
      _steps.removeRange(_currentStep + 1, _steps.length);
      // Collect visited IDs from current path.
      final visited = <String>{for (final s in _steps) s.id};
      visited.add(target.id);
      _steps.add(target);
      _extendPath(_steps, visited);
      // Advance to the chosen target.
      _currentStep++;
      _animatingForward = true;
    });
  }

  void _openDiagramView(BuildContext context) {
    final landscape = EmbedShowcaseScreen._toLandscape(_diagram);
    showDialog(
      context: context,
      builder: (_) => _FullDiagramOverlay(
        diagram: landscape,
        title: widget.title,
      ),
    );
  }

  void _goForward() {
    if (_currentStep < _steps.length - 1) {
      setState(() {
        _currentStep++;
        _animatingForward = true;
      });
    }
  }

  void _goBack() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
        _animatingForward = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_steps.isEmpty) {
      return Container(
        decoration: _frameDecoration(),
        child: const Center(child: Text('No steps')),
      );
    }

    final node = _steps[_currentStep];
    final isLast = _currentStep >= _steps.length - 1;
    final isFirst = _currentStep == 0;
    final isUnresolvedGateway = node.type == NodeType.exclusiveGateway &&
        _diagram.outgoingEdges(node.id).isNotEmpty &&
        isLast;

    return Container(
      decoration: _frameDecoration(),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Title bar with horizontal miniature.
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              border: Border(
                bottom: BorderSide(color: Colors.grey[200]!),
              ),
            ),
            child: Text(
              widget.title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // Step content with slide animation.
          Expanded(
            child: ClipRect(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                transitionBuilder: (child, animation) {
                  final isIncoming = child.key == ValueKey(_currentStep);
                  final direction = _animatingForward ? 1.0 : -1.0;
                  // Incoming slides in from direction, outgoing slides out opposite.
                  final offset = isIncoming ? direction : -direction;
                  return SlideTransition(
                    position: Tween(
                      begin: Offset(offset, 0),
                      end: Offset.zero,
                    ).animate(animation),
                    child: FadeTransition(
                      opacity: Tween(begin: 0.3, end: 1.0).animate(animation),
                      child: child,
                    ),
                  );
                },
                layoutBuilder: (currentChild, previousChildren) {
                  return Stack(
                    clipBehavior: Clip.hardEdge,
                    children: [
                      ...previousChildren,
                      if (currentChild != null) currentChild,
                    ],
                  );
                },
                child: _EmbedStepContent(
                  key: ValueKey(_currentStep),
                  node: node,
                  diagram: _diagram,
                  onOptionSelected: _handleGatewayOption,
                ),
              ),
            ),
          ),

          // Bottom bar with Back / Continue.
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              border: Border(
                top: BorderSide(color: Colors.grey[200]!),
              ),
            ),
            child: Row(
              children: [
                // Horizontal miniature diagram — tap to open full view.
                GestureDetector(
                  onTap: () => _openDiagramView(context),
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: MiniProcessMap(
                      steps: _allNodes,
                      diagram: _diagram,
                      currentNodeId: _steps[_currentStep].id,
                      backgroundColor: Colors.grey[50]!,
                      showShadow: false,
                    ),
                  ),
                ),
                const Spacer(),
                // Back button.
                if (!isFirst)
                  TextButton(
                    onPressed: _goBack,
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.grey[600],
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                    ),
                    child: const Text('Back'),
                  ),
                const SizedBox(width: 8),
                // Continue / Restart button — disabled on unresolved gateway.
                FilledButton(
                  onPressed: isUnresolvedGateway
                      ? null
                      : isLast
                          ? () => setState(() {
                                _currentStep = 0;
                                _animatingForward = false;
                                _steps = _buildPath(_diagram);
                              })
                          : _goForward,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.indigo,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(isLast && !isUnresolvedGateway
                      ? 'Restart'
                      : 'Continue'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  BoxDecoration _frameDecoration() => BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[300]!, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      );
}

/// The step content area inside the framed stepper.
class _EmbedStepContent extends StatelessWidget {
  final NodeModel node;
  final DiagramModel diagram;
  final ValueChanged<int>? onOptionSelected;

  const _EmbedStepContent({
    super.key,
    required this.node,
    required this.diagram,
    this.onOptionSelected,
  });

  @override
  Widget build(BuildContext context) {
    final content = node.content;
    final displayTitle = content?.title ?? node.name;
    final text = content?.text;
    final imagePath = content?.imagePath;
    final videoPath = content?.videoPath;
    final hasImage = imagePath != null;
    final hasVideo = videoPath != null;
    final isGateway = node.type == NodeType.exclusiveGateway;

    List<String> options = [];
    if (isGateway) {
      final outgoing = diagram.outgoingEdges(node.id);
      options =
          outgoing.map((e) => e.name.isNotEmpty ? e.name : 'Option').toList();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 8),

          // Title — centered.
          Text(
            displayTitle,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              height: 1.3,
            ),
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),

          // Body text.
          if (text != null) ...[
            const SizedBox(height: 12),
            Flexible(
              flex: hasImage || hasVideo ? 2 : 3,
              child: SingleChildScrollView(
                child: Text(
                  text,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.7,
                    color: Colors.grey[600],
                  ),
                ),
              ),
            ),
          ],

          // Image.
          if (hasImage) ...[
            const SizedBox(height: 12),
            Expanded(
              flex: 3,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.asset(
                  imagePath,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ],

          // Video thumbnail placeholder.
          if (hasVideo && !hasImage) ...[
            const SizedBox(height: 12),
            Expanded(
              flex: 3,
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Center(
                  child: Icon(Icons.play_circle_outline,
                      size: 48, color: Colors.white70),
                ),
              ),
            ),
          ],

          if (!hasImage && !hasVideo && text == null) const Spacer(),

          // Gateway options.
          if (isGateway && options.isNotEmpty) ...[
            const SizedBox(height: 8),
            for (int i = 0; i < options.length; i++)
              GestureDetector(
                onTap: () => onOptionSelected?.call(i),
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: Container(
                    width: double.infinity,
                    padding:
                        const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      options[i],
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[800],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

/// Full-screen overlay showing the landscape diagram.
class _FullDiagramOverlay extends StatelessWidget {
  final DiagramModel diagram;
  final String title;

  const _FullDiagramOverlay({required this.diagram, required this.title});

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      backgroundColor: Colors.white,
      child: Stack(
        children: [
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 56, 24, 24),
              child: DiagramEmbed(
                diagram: diagram,
                showBorder: false,
              ),
            ),
          ),
          // Title top-center.
          Positioned(
            top: 16,
            left: 56,
            right: 56,
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          // Close button top-right.
          Positioned(
            top: 8,
            right: 8,
            child: IconButton(
              icon: const Icon(Icons.close, size: 24),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
    );
  }
}
