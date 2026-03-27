import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../diagram/model/diagram_model.dart';
import '../../diagram/samples/sample_diagrams.dart';
import '../widgets/mini_process_map.dart';
import 'editor_screen.dart';
import 'presentation_screen.dart';

/// Search tab — search bar + filterable list of all processes.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    final all = SampleDiagrams.all;
    final filtered = _query.isEmpty
        ? all
        : all
            .where((e) =>
                e.name.toLowerCase().contains(_query.toLowerCase()) ||
                e.creator.name.toLowerCase().contains(_query.toLowerCase()))
            .toList();

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: Colors.grey[50],
        body: Column(
          children: [
            Padding(
              padding: EdgeInsets.only(
                  top: topPad + 16, left: 20, right: 20, bottom: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Search',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
            ),
            // Search bar.
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Container(
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TextField(
                  controller: _controller,
                  onChanged: (v) => setState(() => _query = v),
                  decoration: InputDecoration(
                    hintText: 'Search processes...',
                    hintStyle: TextStyle(color: Colors.grey[500], fontSize: 15),
                    prefixIcon:
                        Icon(Icons.search, size: 20, color: Colors.grey[500]),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Results.
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Text('No results',
                          style: TextStyle(color: Colors.grey[500])),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 8),
                      itemCount: filtered.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, i) {
                        final entry = filtered[i];
                        return _SearchResultCard(entry: entry);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchResultCard extends StatefulWidget {
  final SampleDiagramEntry entry;

  const _SearchResultCard({required this.entry});

  @override
  State<_SearchResultCard> createState() => _SearchResultCardState();
}

class _SearchResultCardState extends State<_SearchResultCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    final diagram = entry.builder();
    final teaser = _findTeaserImage(diagram);
    final subtitle = _subtitle(entry.name);

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PresentationScreen(
              diagram: diagram,
              title: entry.name,
              role: DiagramRole.viewer,
              creator: entry.creator,
            ),
          ),
        );
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedOpacity(
        opacity: _pressed ? 0.5 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          height: 96,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              // Teaser preview.
              _buildTeaser(diagram, teaser),
              Expanded(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        entry.name,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (subtitle.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          subtitle,
                          style:
                              TextStyle(fontSize: 12, color: Colors.grey[500]),
                        ),
                      ],
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color(entry.creator.colorValue),
                            ),
                            child: Center(
                              child: Text(
                                entry.creator.initials,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              entry.creator.name,
                              style: const TextStyle(
                                  fontSize: 11, fontWeight: FontWeight.w500),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Icon(Icons.chevron_right, color: Colors.grey[400]),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTeaser(DiagramModel diagram, String? imagePath) {
    const width = 90.0;
    const height = 96.0;
    const br = BorderRadius.horizontal(left: Radius.circular(12));

    if (imagePath != null && imagePath.startsWith('assets/')) {
      return ClipRRect(
        borderRadius: br,
        child: Image.asset(
          imagePath,
          width: width,
          height: height,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _teaserFallback(diagram, width, height, br),
        ),
      );
    }
    return _teaserFallback(diagram, width, height, br);
  }

  Widget _teaserFallback(
      DiagramModel diagram, double w, double h, BorderRadius br) {
    return ClipRRect(
      borderRadius: br,
      child: Container(
        width: w,
        height: h,
        color: const Color(0xFFE8EAF6), // soft indigo tint
        child: Center(
          child: MiniProcessMap(
            steps: diagram.nodes.values.toList(),
            diagram: diagram,
            currentNodeId: '',
            backgroundColor: const Color(0xFFE8EAF6),
            showShadow: false,
          ),
        ),
      ),
    );
  }
}

String? _findTeaserImage(DiagramModel diagram) {
  for (final node in diagram.nodes.values) {
    final img = node.content?.imagePath;
    if (img != null) return img;
  }
  return null;
}

String _subtitle(String name) {
  if (name.contains('IKEA')) return '9 steps · Assembly guide';
  if (name.contains('Emergency')) return '11 steps · Safety procedure';
  if (name.contains('Debug')) return '12 steps · Technical';
  if (name.contains('Sprint')) return '5 steps · Agile workflow';
  if (name.contains('Content')) return '12 steps · All card types';
  if (name.contains('Coffee')) return '7 steps · Brewing guide';
  if (name.contains('Flat Tire')) return '8 steps · Roadside repair';
  if (name.contains('Plant')) return '7 steps · Care routine';
  if (name.contains('Git')) return '8 steps · Developer guide';
  if (name.contains('CI/CD')) return '8 steps · DevOps pipeline';
  if (name.contains('Database')) return '6 steps · Migration checklist';
  if (name.contains('Text Only')) return '10 steps · Text-only layouts';
  if (name.contains('Car Configurator')) return '6 steps · 10 color options';
  if (name.contains('Pasta')) return '9 steps · Video recipe';
  if (name.contains('Car Import')) return '13 steps · Import guide';
  if (name.contains('FDA')) return '12 steps · Medical device';
  if (name.contains('CE Marking')) return '13 steps · EU MDR';
  if (name.contains('ISO 13485')) return '11 steps · QMS certification';
  return '';
}
