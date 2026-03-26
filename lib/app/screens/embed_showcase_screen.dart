import 'dart:math' as math;
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
    final width = MediaQuery.of(context).size.width;
    final crossCount = width > 1100 ? 2 : 1;

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

          // Stepper embeds grid.
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(32, 24, 32, 32),
            sliver: SliverGrid(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossCount,
                mainAxisSpacing: 24,
                crossAxisSpacing: 24,
                childAspectRatio: crossCount == 2 ? 0.85 : 1.1,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final (title, builder) = _samples[index];
                  return _FramedStepper(title: title, builder: builder);
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
      // Swap x/y, also swap width/height for tasks.
      final newCenter = Offset(c.dy, c.dx);
      final newW = n.rect.height;
      final newH = n.rect.width;
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
  late final List<NodeModel> _steps;
  late final List<NodeModel> _allNodes;
  int _currentStep = 0;
  bool _animatingForward = true;

  @override
  void initState() {
    super.initState();
    _diagram = widget.builder();
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

      if (current.type == NodeType.exclusiveGateway) {
        // Follow first branch for the embed.
        for (final edge in outgoing) {
          final target = diagram.nodes[edge.targetId];
          if (target != null && !visited.contains(target.id)) {
            visited.add(target.id);
            path.add(target);
            var branchNode = target;
            while (true) {
              final bo = diagram.outgoingEdges(branchNode.id);
              if (bo.isEmpty || bo.length > 1) break;
              final next = diagram.nodes[bo.first.targetId];
              if (next == null || visited.contains(next.id)) break;
              visited.add(next.id);
              path.add(next);
              branchNode = next;
            }
          }
        }
        break;
      }

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
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 12),
                MiniProcessMap(
                  steps: _allNodes,
                  diagram: _diagram,
                  currentNodeId: _steps[_currentStep].id,
                  horizontal: true,
                  backgroundColor: Colors.grey[50]!,
                  showShadow: false,
                ),
              ],
            ),
          ),

          // Step content with slide animation.
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (child, animation) {
                // Slide from right when going forward, from left when going back.
                final isIncoming = child.key == ValueKey(_currentStep);
                final offset = isIncoming
                    ? Tween(
                        begin: Offset(_animatingForward ? 1.0 : -1.0, 0),
                        end: Offset.zero,
                      )
                    : Tween(
                        begin: Offset.zero,
                        end: Offset(_animatingForward ? -1.0 : 1.0, 0),
                      );
                return SlideTransition(
                  position: offset.animate(CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeInOut,
                  )),
                  child: child,
                );
              },
              layoutBuilder: (currentChild, previousChildren) {
                return Stack(
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
                // Progress dots.
                Expanded(
                  child: _ProgressDots(
                    total: _steps.length,
                    current: _currentStep,
                  ),
                ),
                const SizedBox(width: 12),
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
                // Continue / Restart button.
                FilledButton(
                  onPressed: isLast
                      ? () => setState(() {
                                                _currentStep = 0;
                            _animatingForward = false;
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
                  child: Text(isLast ? 'Restart' : 'Continue'),
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

  const _EmbedStepContent({
    super.key,
    required this.node,
    required this.diagram,
  });

  @override
  Widget build(BuildContext context) {
    final content = node.content;
    final displayTitle = content?.title ?? node.name;
    final text = content?.text;
    final isEvent =
        node.type == NodeType.startEvent || node.type == NodeType.endEvent;
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Badge.
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isEvent
                  ? Colors.grey[800]
                  : isGateway
                      ? Colors.amber[700]
                      : Colors.indigo,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              isEvent
                  ? (node.type == NodeType.startEvent ? 'START' : 'END')
                  : isGateway
                      ? 'DECISION'
                      : 'STEP',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Title.
          Text(
            displayTitle,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              height: 1.3,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),

          // Body text.
          if (text != null) ...[
            const SizedBox(height: 12),
            Expanded(
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
          ] else
            const Spacer(),

          // Gateway options.
          if (isGateway && options.isNotEmpty) ...[
            const SizedBox(height: 8),
            for (final option in options)
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  option,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[800],
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

/// Compact progress dots.
class _ProgressDots extends StatelessWidget {
  final int total;
  final int current;

  const _ProgressDots({required this.total, required this.current});

  @override
  Widget build(BuildContext context) {
    // If too many dots, show a condensed progress bar.
    if (total > 15) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(2),
        child: LinearProgressIndicator(
          value: (current + 1) / total,
          backgroundColor: Colors.grey[200],
          valueColor: const AlwaysStoppedAnimation(Colors.indigo),
          minHeight: 4,
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        math.min(total, 15),
        (i) => Container(
          width: i == current ? 16 : 6,
          height: 6,
          margin: const EdgeInsets.only(right: 4),
          decoration: BoxDecoration(
            color: i == current
                ? Colors.indigo
                : i < current
                    ? Colors.indigo.withValues(alpha: 0.3)
                    : Colors.grey[300],
            borderRadius: BorderRadius.circular(3),
          ),
        ),
      ),
    );
  }
}
