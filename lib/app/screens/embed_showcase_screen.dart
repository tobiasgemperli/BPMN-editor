import 'package:flutter/material.dart';
import '../../diagram/model/diagram_model.dart';
import '../../diagram/samples/sample_diagrams.dart';
import '../widgets/diagram_embed.dart';

/// A web-friendly showcase page displaying embedded sample diagrams.
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
    final width = MediaQuery.of(context).size.width;
    // Responsive: 1 column on mobile, 2 on tablet, 3 on desktop.
    final crossCount = width > 1200 ? 3 : (width > 700 ? 2 : 1);

    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(32, 48, 32, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'BPMN Diagram Embeds',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Lightweight, read-only diagram embeds for the web. '
                    'Each card renders a complete BPMN process diagram.',
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.grey[600],
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            sliver: SliverGrid(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossCount,
                mainAxisSpacing: 20,
                crossAxisSpacing: 20,
                childAspectRatio: 0.75,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final (title, builder) = _samples[index];
                  return _EmbedCard(title: title, builder: builder);
                },
                childCount: _samples.length,
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 48)),
        ],
      ),
    );
  }
}

class _EmbedCard extends StatelessWidget {
  final String title;
  final DiagramModelBuilder builder;

  const _EmbedCard({required this.title, required this.builder});

  @override
  Widget build(BuildContext context) {
    final diagram = builder();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          child: DiagramEmbed(diagram: diagram),
        ),
      ],
    );
  }
}

typedef DiagramModelBuilder = DiagramModel Function();
