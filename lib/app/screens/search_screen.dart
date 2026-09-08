import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../diagram/io/api_client.dart';
import '../../diagram/io/diagram_storage.dart';
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

  List<ApiModelMeta> _remoteModels = [];
  final Map<String, DiagramModel> _remoteDiagrams = {};
  bool _remoteLoading = false;

  /// Include hardcoded SampleDiagrams in the results. Disabled so search only
  /// returns real backend models. Flip to true to bring the samples back.
  final bool _showSampleResults = false;

  @override
  void initState() {
    super.initState();
    _loadRemote();
  }

  Future<void> _refresh() async {
    _remoteDiagrams.clear();
    await _loadRemote();
  }

  Future<void> _loadRemote() async {
    setState(() => _remoteLoading = true);
    try {
      final models = await DiagramStorage.instance.listRemote();
      final results = await Future.wait(
        models.map((m) async {
          try {
            final full = await DiagramStorage.instance.loadRemote(m.id);
            if (full.diagram != null) {
              _remoteDiagrams[m.id] = full.diagram!;
              return m;
            }
            return null;
          } catch (_) {
            return null;
          }
        }),
      );
      final valid = results.whereType<ApiModelMeta>().toList();
      if (mounted) setState(() => _remoteModels = valid);
    } catch (_) {
      // Server unavailable — keep empty list.
    } finally {
      if (mounted) setState(() => _remoteLoading = false);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    final q = _query.toLowerCase();

    // Filter sample diagrams (hardcoded — disabled unless _showSampleResults).
    final allSamples = SampleDiagrams.all;
    final filteredSamples = !_showSampleResults
        ? const <SampleDiagramEntry>[]
        : q.isEmpty
            ? allSamples
            : allSamples
                .where((e) =>
                    e.name.toLowerCase().contains(q) ||
                    e.creator.name.toLowerCase().contains(q))
                .toList();

    // Filter remote models.
    final filteredRemote = q.isEmpty
        ? _remoteModels
        : _remoteModels
            .where((m) =>
                m.name.toLowerCase().contains(q) ||
                m.ownerName.toLowerCase().contains(q) ||
                m.keywords.any((k) => k.toLowerCase().contains(q)))
            .toList();

    final totalResults = filteredRemote.length + filteredSamples.length;
    final hasResults = totalResults > 0;

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
                        color: const Color(0xFF1C1C1E),
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
                  style: const TextStyle(fontSize: 15, color: Color(0xFF1C1C1E)),
                  decoration: InputDecoration(
                    hintText: 'Search processes...',
                    hintStyle: TextStyle(color: Colors.grey[600], fontSize: 15),
                    prefixIcon:
                        Icon(Icons.search, size: 20, color: Colors.grey[600]),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Results.
            Expanded(
              child: _remoteLoading && _remoteModels.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      onRefresh: _refresh,
                      child: !hasResults
                          ? ListView(
                              children: [
                                SizedBox(
                                  height: MediaQuery.of(context).size.height * 0.5,
                                  child: Center(
                                    child: Text('No results',
                                        style: TextStyle(color: Colors.grey[600])),
                                  ),
                                ),
                              ],
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 8),
                              itemCount: totalResults,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 8),
                              itemBuilder: (context, i) {
                                // Remote results first, then samples.
                                if (i < filteredRemote.length) {
                                  final model = filteredRemote[i];
                                  final diagram = _remoteDiagrams[model.id];
                                  return _RemoteResultCard(
                                    model: model,
                                    diagram: diagram,
                                  );
                                }
                                final entry =
                                    filteredSamples[i - filteredRemote.length];
                                return _SearchResultCard(entry: entry);
                              },
                            ),
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
                            fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1C1C1E)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (subtitle.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          subtitle,
                          style:
                              TextStyle(fontSize: 12, color: Colors.grey[600]),
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
                                  fontSize: 11, fontWeight: FontWeight.w500, color: Color(0xFF636366)),
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
                child: Icon(Icons.chevron_right, color: Colors.grey[600]),
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

class _RemoteResultCard extends StatefulWidget {
  final ApiModelMeta model;
  final DiagramModel? diagram;

  const _RemoteResultCard({required this.model, this.diagram});

  @override
  State<_RemoteResultCard> createState() => _RemoteResultCardState();
}

class _RemoteResultCardState extends State<_RemoteResultCard> {
  bool _pressed = false;

  /// Preview: prefer the model's stored thumbnail, falling back to the live
  /// mini-process-map, then a cloud placeholder.
  Widget _preview(DiagramModel? diagram) {
    final fileId = widget.model.thumbnailFileId;
    if (fileId.isNotEmpty) {
      return FutureBuilder<Uint8List?>(
        future: ApiClient.instance.getFileBytes(fileId),
        builder: (context, snap) {
          if (snap.data != null) {
            return Image.memory(snap.data!,
                width: 90, height: 96, fit: BoxFit.cover);
          }
          return _miniOrPlaceholder(diagram);
        },
      );
    }
    return _miniOrPlaceholder(diagram);
  }

  Widget _miniOrPlaceholder(DiagramModel? diagram) {
    if (diagram != null) {
      return Center(
        child: MiniProcessMap(
          steps: diagram.nodes.values.toList(),
          diagram: diagram,
          currentNodeId: '',
          backgroundColor: const Color(0xFFE8EAF6),
          showShadow: false,
        ),
      );
    }
    return const Center(
      child: Icon(Icons.cloud_outlined, color: Color(0xFF9FA8DA), size: 28),
    );
  }

  @override
  Widget build(BuildContext context) {
    final model = widget.model;
    final diagram = widget.diagram;
    final stepCount = diagram?.nodes.values
            .where((n) => n.type == NodeType.task)
            .length ??
        0;

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        if (diagram != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PresentationScreen(
                diagram: diagram,
                title: model.name,
                role: DiagramRole.viewer,
                creator: SampleCreator(
                  id: model.ownerId,
                  name: model.ownerName,
                  initials: _initials(model.ownerName),
                  colorValue: 0xFF6C63FF,
                  bio: '',
                  followers: 0,
                ),
              ),
            ),
          );
        }
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
              ClipRRect(
                borderRadius:
                    const BorderRadius.horizontal(left: Radius.circular(12)),
                child: Container(
                  width: 90,
                  height: 96,
                  color: const Color(0xFFE8EAF6),
                  child: _preview(diagram),
                ),
              ),
              Expanded(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        model.name,
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1C1C1E)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (stepCount > 0) ...[
                        const SizedBox(height: 3),
                        Text(
                          '$stepCount steps',
                          style:
                              TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                      ],
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color(0xFF6C63FF),
                            ),
                            child: Center(
                              child: Text(
                                _initials(model.ownerName),
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
                              model.ownerName,
                              style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF636366)),
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
                child: Icon(Icons.chevron_right, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+'));
  if (parts.length >= 2) {
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }
  return name.isNotEmpty ? name[0].toUpperCase() : '?';
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
