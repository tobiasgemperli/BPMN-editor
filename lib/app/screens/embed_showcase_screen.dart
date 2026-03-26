import 'package:flutter/material.dart';
import '../../diagram/model/diagram_model.dart';
import '../../diagram/samples/sample_diagrams.dart';

/// A web-friendly showcase page with embedded steppers scrolling left-to-right.
class EmbedShowcaseScreen extends StatelessWidget {
  const EmbedShowcaseScreen({super.key});

  static const _samples = [
    ('IKEA KALLAX Assembly', SampleDiagrams.ikeaAssembly),
    ('Sprint Cycle', SampleDiagrams.sprintCycle),
    ('CI/CD Pipeline', SampleDiagrams.cicdPipeline),
    ('Coffee Brewing Guide', SampleDiagrams.coffeeBrewing),
    ('Emergency: Fire Evacuation', SampleDiagrams.emergencyProcedure),
    ('FDA 510(k) Clearance', SampleDiagrams.fda510k),
    ('Car Import USA → Germany', SampleDiagrams.carImportUSA),
    ('Debug: API 500 Errors', SampleDiagrams.technicalDebugging),
    ('CE Marking (EU MDR)', SampleDiagrams.ceMedicalDevice),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 48),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(32, 0, 32, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Process Steppers',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Embedded process steppers for the web. '
                  'Scroll left-to-right through each process.',
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.grey[600],
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          for (final (title, builder) in _samples) ...[
            _EmbeddedStepper(title: title, builder: builder),
            const SizedBox(height: 32),
          ],
        ],
      ),
    );
  }
}

typedef _DiagramBuilder = DiagramModel Function();

/// An embedded horizontal stepper that walks through a diagram's nodes
/// left-to-right with step cards.
class _EmbeddedStepper extends StatelessWidget {
  final String title;
  final _DiagramBuilder builder;

  const _EmbeddedStepper({required this.title, required this.builder});

  /// Walk the diagram from start, following single outgoing edges.
  /// Stops at gateways (shows options) or end events.
  List<NodeModel> _buildLinearPath(DiagramModel diagram) {
    // Find start node.
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

      // For gateways, follow all branches breadth-first.
      if (current.type == NodeType.exclusiveGateway) {
        for (final edge in outgoing) {
          final target = diagram.nodes[edge.targetId];
          if (target != null && !visited.contains(target.id)) {
            visited.add(target.id);
            path.add(target);
            // Follow this branch linearly.
            var branchNode = target;
            while (true) {
              final branchOut = diagram.outgoingEdges(branchNode.id);
              if (branchOut.isEmpty) break;
              if (branchOut.length == 1) {
                final next = diagram.nodes[branchOut.first.targetId];
                if (next == null || visited.contains(next.id)) break;
                visited.add(next.id);
                path.add(next);
                branchNode = next;
              } else {
                break;
              }
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

  @override
  Widget build(BuildContext context) {
    final diagram = builder();
    final steps = _buildLinearPath(diagram);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 32, bottom: 12),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        SizedBox(
          height: 420,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 32),
            itemCount: steps.length,
            separatorBuilder: (context, index) => const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: Center(
                child: Icon(Icons.arrow_forward, size: 20, color: Colors.grey),
              ),
            ),
            itemBuilder: (context, index) {
              final node = steps[index];
              return SizedBox(
                width: 320,
                child: _StepCard(
                  node: node,
                  diagram: diagram,
                  stepIndex: index,
                  totalSteps: steps.length,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// A compact step card for the web embed — shows node content in a card frame.
class _StepCard extends StatelessWidget {
  final NodeModel node;
  final DiagramModel diagram;
  final int stepIndex;
  final int totalSteps;

  const _StepCard({
    required this.node,
    required this.diagram,
    required this.stepIndex,
    required this.totalSteps,
  });

  @override
  Widget build(BuildContext context) {
    final content = node.content;
    final displayTitle = content?.title ?? node.name;
    final text = content?.text;
    final isEvent = node.type == NodeType.startEvent ||
        node.type == NodeType.endEvent;
    final isGateway = node.type == NodeType.exclusiveGateway;

    List<String> options = [];
    if (isGateway) {
      final outgoing = diagram.outgoingEdges(node.id);
      options = outgoing
          .map((e) => e.name.isNotEmpty ? e.name : 'Option')
          .toList();
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Step indicator.
          Row(
            children: [
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
                          : 'STEP ${stepIndex + 1}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                '${stepIndex + 1} / $totalSteps',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[400],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Title.
          Text(
            displayTitle,
            style: const TextStyle(
              fontSize: 20,
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
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.6,
                  color: Colors.grey[600],
                ),
                overflow: TextOverflow.fade,
              ),
            ),
          ] else
            const Spacer(),

          // Gateway options.
          if (isGateway && options.isNotEmpty) ...[
            const SizedBox(height: 12),
            for (final option in options) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
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
        ],
      ),
    );
  }
}
