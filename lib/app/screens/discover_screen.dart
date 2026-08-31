import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../diagram/io/api_client.dart';
import '../../diagram/io/diagram_storage.dart';
import '../../diagram/model/diagram_model.dart';
import '../../diagram/samples/sample_diagrams.dart';
import '../widgets/close_circle_button.dart';
import 'presentation_screen.dart';
import 'editor_screen.dart';

/// YouTube-inspired discovery screen for browsing process content.
class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  static const _categories = ['All', 'Tutorials', 'Technical', 'Certification', 'Templates', 'Recent'];
  String _selected = 'All';
  List<ApiModel> _myModels = [];
  bool _myLoading = false;
  List<ApiModelMeta> _remoteModels = [];
  final Map<String, DiagramModel> _remoteDiagrams = {};
  bool _remoteLoading = false;

  /// The Featured / Tutorials / Certification / Technical / Flow Patterns
  /// sections are driven by SampleDiagrams (local hardcoded dummy data).
  /// Set to false to hide them so the screen shows only real backend data
  /// (My Flowcharts + Discover). Flip to true to bring the samples back.
  final bool _showSampleSections = false;

  @override
  void initState() {
    super.initState();
    _loadMyModels();
    _loadRemote();
  }

  Future<void> _refresh() async {
    _remoteDiagrams.clear();
    await Future.wait([_loadMyModels(), _loadRemote()]);
  }

  /// Load the authenticated user's own models from the backend for the
  /// "My Flowcharts" section (only renderable ones).
  Future<void> _loadMyModels() async {
    setState(() => _myLoading = true);
    try {
      final models = await DiagramStorage.instance.listMyModels();
      final renderable = models.where((m) => m.diagram != null).toList();
      if (mounted) setState(() => _myModels = renderable);
    } catch (_) {
      // Server unavailable — keep whatever we had.
    } finally {
      if (mounted) setState(() => _myLoading = false);
    }
  }

  Future<void> _loadRemote() async {
    setState(() => _remoteLoading = true);
    try {
      final models = await DiagramStorage.instance.listRemote();
      // Load each model in parallel to check for BpmnXml and cache diagrams.
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
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;

    final samples = SampleDiagrams.all;
    final featured = samples.isNotEmpty ? samples.first : null;
    final rest = samples.length > 1 ? samples.sublist(1) : <SampleDiagramEntry>[];

    final tutorials = rest.where((s) =>
        s.name.contains('IKEA') ||
        s.name.contains('Content') ||
        s.name.contains('Employee') ||
        s.name.contains('Emergency') ||
        s.name.contains('Coffee') ||
        s.name.contains('Flat Tire') ||
        s.name.contains('Plant') ||
        s.name.contains('Text Only') ||
        s.name.contains('Car Configurator') ||
        s.name.contains('Pasta') ||
        s.name.contains('Car Import') ||
        s.name.contains('Electric Step')).toList();
    final certification = rest.where((s) =>
        s.name.contains('FDA') ||
        s.name.contains('CE Marking') ||
        s.name.contains('ISO 13485')).toList();
    final technical = rest.where((s) =>
        s.name.contains('Debug') ||
        s.name.contains('Sprint') ||
        s.name.contains('Git') ||
        s.name.contains('CI/CD') ||
        s.name.contains('Database')).toList();
    final patterns = rest.where((s) =>
        !tutorials.contains(s) &&
        !certification.contains(s) &&
        !technical.contains(s)).toList();

    final showFeatured = _selected == 'All' || _selected == 'Recent';
    final showMyFlowcharts = _selected == 'All' || _selected == 'Recent';
    final showTutorials = _selected == 'All' || _selected == 'Tutorials' || _selected == 'Recent';
    final showCertification = _selected == 'All' || _selected == 'Certification' || _selected == 'Recent';
    final showTechnical = _selected == 'All' || _selected == 'Technical' || _selected == 'Recent';
    final showPatterns = _selected == 'All' || _selected == 'Templates' || _selected == 'Recent';

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: Colors.grey[50],
        body: Column(
          children: [
            // ── Fixed header ──────────────────────────────────
            Padding(
              padding: EdgeInsets.only(
                  top: topPad + 16, left: 20, right: 20, bottom: 8),
              child: Row(
                children: [
                  Text(
                    'Processes',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF1C1C1E),
                        ),
                  ),
                  const Spacer(),
                  _Pressable(
                    onTap: () => Navigator.push(
                      context,
                      _bottomToTopRoute(
                          EditorScreen(showCloseButton: true, onSaved: _loadMyModels)),
                    ),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFF007AFF),
                      ),
                      child: const Icon(Icons.add, size: 26, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),

            // ── Fixed category chips ──────────────────────────
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 8),
              child: SizedBox(
                height: 36,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    for (final cat in _categories)
                      _CategoryChip(
                        label: cat,
                        selected: _selected == cat,
                        onTap: () => setState(() => _selected = cat),
                      ),
                  ],
                ),
              ),
            ),

            // ── Scrollable content ────────────────────────────
            Expanded(
              child: RefreshIndicator(
                onRefresh: _refresh,
                child: CustomScrollView(
                slivers: [
            // ── Featured card (hardcoded sample) ────────────────
            if (_showSampleSections && showFeatured && featured != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                  child: _FeaturedCard(entry: featured),
                ),
              ),

            // ── My Flowcharts section (backend, owner-filtered) ──
            if (showMyFlowcharts && (_myModels.isNotEmpty || _myLoading)) ...[
              _sectionHeader(context, 'My Flowcharts'),
              if (_myModels.isEmpty && _myLoading)
                const SliverToBoxAdapter(
                  child: SizedBox(
                    height: 210,
                    child: Center(
                      child: SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  ),
                )
              else
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 210,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: _myModels.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 12),
                      itemBuilder: (context, i) => _MyModelCard(
                        model: _myModels[i],
                        onChanged: _loadMyModels,
                      ),
                    ),
                  ),
                ),
            ],

            // ── Server Models section ────────────────────────────
            if (_selected == 'All' || _selected == 'Recent') ...[
              if (_remoteLoading)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
                    child: Row(
                      children: [
                        Text(
                          'Discover',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF1C1C1E),
                              ),
                        ),
                        const SizedBox(width: 12),
                        const SizedBox(
                          width: 16, height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ],
                    ),
                  ),
                )
              else if (_remoteModels.isNotEmpty) ...[
                _sectionHeader(context, 'Discover'),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 210,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: _remoteModels.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 12),
                      itemBuilder: (context, i) => _RemoteModelCard(
                        meta: _remoteModels[i],
                        diagram: _remoteDiagrams[_remoteModels[i].id],
                      ),
                    ),
                  ),
                ),
              ],
            ],

            // ── Tutorials section ───────────────────────────────
            if (_showSampleSections && showTutorials && tutorials.isNotEmpty) ...[
              _sectionHeader(context, 'Tutorials'),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 210,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: tutorials.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 12),
                    itemBuilder: (context, i) =>
                        _SmallCard(entry: tutorials[i]),
                  ),
                ),
              ),
            ],

            // ── Certification section ─────────────────────────────
            if (_showSampleSections && showCertification && certification.isNotEmpty) ...[
              _sectionHeader(context, 'Certification Processes'),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 210,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: certification.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 12),
                    itemBuilder: (context, i) =>
                        _SmallCard(entry: certification[i]),
                  ),
                ),
              ),
            ],

            // ── Technical section ───────────────────────────────
            if (_showSampleSections && showTechnical && technical.isNotEmpty) ...[
              _sectionHeader(context, 'Technical'),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 210,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: technical.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 12),
                    itemBuilder: (context, i) =>
                        _SmallCard(entry: technical[i]),
                  ),
                ),
              ),
            ],

            // ── Flow Patterns section ───────────────────────────
            if (_showSampleSections && showPatterns && patterns.isNotEmpty) ...[
              _sectionHeader(context, 'Flow Patterns'),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, i) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _ListCard(entry: patterns[i]),
                    ),
                    childCount: patterns.length,
                  ),
                ),
              ),
            ],

            const SliverToBoxAdapter(child: SizedBox(height: 40)),
                ],
              ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static SliverToBoxAdapter _sectionHeader(BuildContext context, String title) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
        child: Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1C1C1E),
              ),
        ),
      ),
    );
  }
}

// ── Helpers ──────────────────────────────────────────────────────

String _subtitle(String name) {
  if (name.contains('Employee Onboarding')) return '14 steps · HR & Compliance';
  if (name.contains('IKEA')) return '9 steps · Assembly guide';
  if (name.contains('Emergency')) return '11 steps · Safety procedure';
  if (name.contains('Debug')) return '12 steps · Technical';
  if (name.contains('Sprint')) return '5 steps · Agile workflow';
  if (name.contains('Content')) return '12 steps · All card types';
  if (name.contains('Linear')) return '5 steps · Simple flow';
  if (name.contains('Diamond')) return '7–9 steps · Branch & merge';
  if (name.contains('Three-Way')) return '7 steps · 3-way merge';
  if (name.contains('Four-Way')) return '8 steps · 4-way merge';
  if (name.contains('Coffee')) return '6 steps · Daily routine';
  if (name.contains('Flat Tire')) return '7 steps · Emergency guide';
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

/// Find the first image path used in any node's content.
String? _findTeaserImage(DiagramModel diagram) {
  for (final node in diagram.nodes.values) {
    final img = node.content?.imagePath;
    if (img != null) return img;
  }
  return null;
}

void _openOwnedEditor(BuildContext context, DiagramModel diagram,
    {String? title, String? savedId, VoidCallback? onSaved}) {
  Navigator.push(
    context,
    _bottomToTopRoute(_ModalNavigatorShell(
      diagram: diagram,
      title: title,
      role: DiagramRole.owner,
      savedId: savedId,
      onSaved: onSaved,
    )),
  );
}

void _openPresentation(BuildContext context, DiagramModel diagram,
    {String? title, SampleCreator? creator, SampleDiagramEntry? entry}) {
  Navigator.push(
    context,
    _bottomToTopRoute(_ModalNavigatorShell(
      diagram: diagram,
      title: title,
      role: DiagramRole.viewer,
      creator: creator,
      entry: entry,
    )),
  );
}

/// Modal shell with a nested Navigator inside.
/// The stepper is the initial route; subsequent screens (editor, etc.)
/// push inside the nested navigator. Close dismisses the entire modal.
class _ModalNavigatorShell extends StatelessWidget {
  final DiagramModel diagram;
  final String? title;
  final DiagramRole role;
  final SampleCreator? creator;
  final SampleDiagramEntry? entry;
  final String? savedId;
  final VoidCallback? onSaved;

  const _ModalNavigatorShell({
    required this.diagram,
    this.title,
    this.role = DiagramRole.owner,
    this.creator,
    this.entry,
    this.savedId,
    this.onSaved,
  });

  @override
  Widget build(BuildContext context) {
    return Navigator(
      onGenerateRoute: (_) => MaterialPageRoute(
        builder: (_) => PresentationScreen(
          diagram: diagram,
          title: title,
          role: role,
          creator: creator,
          entry: entry,
          savedId: savedId,
          onSaved: onSaved,
        ),
      ),
    );
  }
}

Route<T> _bottomToTopRoute<T>(Widget page) {
  return PageRouteBuilder<T>(
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 1),
          end: Offset.zero,
        ).animate(CurvedAnimation(
          parent: animation,
          curve: Curves.easeOut,
        )),
        child: child,
      );
    },
  );
}

/// Dismiss the entire modal stack back to the dashboard.
/// Removes pushed routes silently, then pops the modal route
/// so only the vertical slide-down animation plays.
void dismissToDashboard(BuildContext context) {
  final nav = Navigator.of(context);

  // Collect all routes above the dashboard.
  final routes = <Route>[];
  nav.popUntil((route) {
    if (!route.isFirst) routes.add(route);
    return true; // don't pop — just collect
  });

  if (routes.isEmpty) return;

  // If only one route above dashboard, just pop it (it's the modal).
  if (routes.length == 1) {
    nav.pop();
    return;
  }

  // Remove all pushed routes above the modal without animation.
  // The modal is routes.last (closest to dashboard), pushed ones are before it.
  for (int i = 0; i < routes.length - 1; i++) {
    nav.removeRoute(routes[i]);
  }

  // Now pop the modal route — its slide-down animation plays.
  nav.pop();
}

// ── Creator avatar ──────────────────────────────────────────────

class _CreatorAvatar extends StatelessWidget {
  final SampleCreator creator;
  final double size;

  const _CreatorAvatar({required this.creator, this.size = 34});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Color(creator.colorValue),
      ),
      child: creator.avatarUrl != null
          ? ClipOval(
              child: Image.network(
                creator.avatarUrl!,
                width: size,
                height: size,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _initialsFallback(),
              ),
            )
          : _initialsFallback(),
    );
  }

  Widget _initialsFallback() {
    return Center(
      child: Text(
        creator.initials,
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.38,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// Row: avatar + creator name. Tappable to open profile.
class _CreatorRow extends StatelessWidget {
  final SampleCreator creator;
  final double avatarSize;
  final double fontSize;

  const _CreatorRow({
    required this.creator,
    this.avatarSize = 28,
    this.fontSize = 12,
  });

  @override
  Widget build(BuildContext context) {
    return _Pressable(
      onTap: () => showCreatorProfile(context, creator),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _CreatorAvatar(creator: creator, size: avatarSize),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              creator.name,
              style: TextStyle(
                fontSize: fontSize,
                color: Colors.grey[600],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Creator profile sheet ───────────────────────────────────────

void showCreatorProfile(BuildContext context, SampleCreator creator) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => _CreatorProfileScreen(creator: creator),
    ),
  );
}

String _formatNumber(int n) {
  if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
  return n.toString();
}

/// Card shown inside the creator profile sheet.
class _ProfileDiagramCard extends StatelessWidget {
  final String name;
  final DiagramModel diagram;
  final String subtitle;
  final String? teaserImage;
  final SampleCreator? creator;

  const _ProfileDiagramCard({
    required this.name,
    required this.diagram,
    this.subtitle = '',
    this.teaserImage,
    this.creator,
  });

  @override
  Widget build(BuildContext context) {
    return _Pressable(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PresentationScreen(
              diagram: diagram,
              title: name,
              creator: creator,
            ),
          ),
        );
      },
      child: Container(
        height: 80,
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            _buildPreview(),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(name,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1C1C1E)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(subtitle,
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey[600])),
                    ],
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
    );
  }

  Widget _buildPreview() {
    if (teaserImage != null && teaserImage!.startsWith('assets/')) {
      return ClipRRect(
        borderRadius: const BorderRadius.horizontal(left: Radius.circular(12)),
        child: Image.asset(
          teaserImage!,
          width: 90,
          height: 80,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _diagramFallback(),
        ),
      );
    }
    return _diagramFallback();
  }

  Widget _diagramFallback() {
    return Container(
      width: 90,
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: const BorderRadius.horizontal(left: Radius.circular(12)),
      ),
      child: Center(
        child: _DiagramThumbnail(diagram: diagram, width: 70, height: 60),
      ),
    );
  }
}

// ── Category chip ────────────────────────────────────────────────

class _CategoryChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  const _CategoryChip({required this.label, this.selected = false, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? Colors.black : Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: selected ? null : Border.all(color: Colors.grey[300]!),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: selected ? Colors.white : Colors.black87,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Diagram thumbnail ────────────────────────────────────────────

class _DiagramThumbnail extends StatelessWidget {
  final DiagramModel diagram;
  final double width;
  final double height;

  const _DiagramThumbnail({
    required this.diagram,
    required this.width,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(width, height),
      painter: _ThumbnailPainter(diagram: diagram),
    );
  }
}

class _ThumbnailPainter extends CustomPainter {
  final DiagramModel diagram;

  _ThumbnailPainter({required this.diagram});

  @override
  void paint(Canvas canvas, Size size) {
    final nodes = diagram.nodes.values.toList();
    if (nodes.isEmpty) return;

    double minX = double.infinity, minY = double.infinity;
    double maxX = -double.infinity, maxY = -double.infinity;
    for (final node in nodes) {
      final c = node.rect.center;
      if (c.dx < minX) minX = c.dx;
      if (c.dy < minY) minY = c.dy;
      if (c.dx > maxX) maxX = c.dx;
      if (c.dy > maxY) maxY = c.dy;
    }

    final dw = (maxX - minX).clamp(1.0, double.infinity);
    final dh = (maxY - minY).clamp(1.0, double.infinity);
    const pad = 12.0;
    final scale = ((size.width - pad * 2) / dw)
        .clamp(0.0, (size.height - pad * 2) / dh);

    Offset map(Offset c) => Offset(
          (c.dx - minX) * scale + (size.width - dw * scale) / 2,
          (c.dy - minY) * scale + (size.height - dh * scale) / 2,
        );

    final linePaint = Paint()
      ..color = Colors.black12
      ..strokeWidth = 1;
    final dotPaint = Paint()..color = Colors.black26;

    // Edges.
    for (final edge in diagram.edges.values) {
      final src = diagram.nodes[edge.sourceId];
      final tgt = diagram.nodes[edge.targetId];
      if (src == null || tgt == null) continue;

      final points = <Offset>[
        map(src.rect.center),
        if (edge.waypoints.length >= 3)
          for (int i = 1; i < edge.waypoints.length - 1; i++)
            map(edge.waypoints[i]),
        map(tgt.rect.center),
      ];
      for (int i = 0; i < points.length - 1; i++) {
        canvas.drawLine(points[i], points[i + 1], linePaint);
      }
    }

    // Nodes.
    final bgPaint = Paint()..color = Colors.white;
    for (final node in nodes) {
      final c = map(node.rect.center);
      if (node.type == NodeType.exclusiveGateway) {
        const s = 5.0;
        final path = Path()
          ..moveTo(c.dx, c.dy - s)
          ..lineTo(c.dx + s, c.dy)
          ..lineTo(c.dx, c.dy + s)
          ..lineTo(c.dx - s, c.dy)
          ..close();
        canvas.drawPath(path, bgPaint);
        canvas.drawPath(path, dotPaint);
      } else {
        canvas.drawCircle(c, 3.5, bgPaint);
        canvas.drawCircle(c, 3.5, dotPaint);
      }
    }
  }

  @override
  bool shouldRepaint(_ThumbnailPainter old) => false;
}

// ── Teaser preview (image or diagram thumbnail) ──────────────────

class _TeaserPreview extends StatelessWidget {
  final DiagramModel diagram;
  final double width;
  final double height;
  final BorderRadius borderRadius;

  const _TeaserPreview({
    required this.diagram,
    required this.width,
    required this.height,
    required this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final teaser = _findTeaserImage(diagram);
    if (teaser != null && teaser.startsWith('assets/')) {
      return ClipRRect(
        borderRadius: borderRadius,
        child: Image.asset(
          teaser,
          width: width,
          height: height,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _fallback(),
        ),
      );
    }
    return _fallback();
  }

  Widget _fallback() {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: borderRadius,
      ),
      child: Center(
        child: _DiagramThumbnail(
          diagram: diagram,
          width: width - 20,
          height: height - 20,
        ),
      ),
    );
  }
}

// ── Featured card (large, top of screen) ─────────────────────────

class _FeaturedCard extends StatelessWidget {
  final SampleDiagramEntry entry;

  const _FeaturedCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    final diagram = entry.builder();
    return _Pressable(
      onTap: () => _openPresentation(context, diagram,
                              title: entry.name, creator: entry.creator, entry: entry),
      child: Container(
        height: 220,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            _TeaserPreview(
              diagram: diagram,
              width: 160,
              height: 220,
              borderRadius:
                  const BorderRadius.horizontal(left: Radius.circular(16)),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'FEATURED',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      entry.name,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF1C1C1E)),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _subtitle(entry.name),
                      style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        _CreatorRow(creator: entry.creator),
                        const Spacer(),
                        _Pressable(
                          onTap: () => _openPresentation(context, diagram,
                              title: entry.name, creator: entry.creator, entry: entry),
                          child: Icon(Icons.play_circle_filled,
                              size: 32, color: Colors.grey[800]),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Badge icons (favorite / paid) ─────────────────────────────────

class _BadgeIcons extends StatelessWidget {
  final bool isFavorite;
  final bool isPaid;

  const _BadgeIcons({this.isFavorite = false, this.isPaid = false});

  @override
  Widget build(BuildContext context) {
    if (!isFavorite && !isPaid) return const SizedBox.shrink();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isFavorite)
          _BadgeCircle(
            icon: Icons.favorite,
            color: const Color(0xFFFF2D55),
            bgColor: const Color(0xFFFF2D55).withValues(alpha: 0.12),
          ),
        if (isFavorite && isPaid) const SizedBox(width: 4),
        if (isPaid)
          _BadgeCircle(
            icon: Icons.attach_money,
            color: const Color(0xFF34C759),
            bgColor: const Color(0xFF34C759).withValues(alpha: 0.12),
          ),
      ],
    );
  }
}

class _BadgeCircle extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Color bgColor;

  const _BadgeCircle({
    required this.icon,
    required this.color,
    required this.bgColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: bgColor,
      ),
      child: Icon(icon, size: 14, color: color),
    );
  }
}

// ── My model card (backend-owned, horizontal scroll) ────────────

class _MyModelCard extends StatelessWidget {
  final ApiModel model;

  /// Called after the model is edited or deleted so the list can refresh.
  final VoidCallback onChanged;

  const _MyModelCard({required this.model, required this.onChanged});

  String get _localId => 'remote_${model.meta.id}';

  Future<void> _open(BuildContext context) async {
    final diagram = model.diagram;
    if (diagram == null) return;
    // Cache locally (keyed by remote id) so edits save back to the server.
    await DiagramStorage.instance
        .importRemote(model.meta.id, model.meta.name, diagram);
    if (!context.mounted) return;
    _openOwnedEditor(
      context,
      diagram,
      title: model.meta.name,
      savedId: _localId,
      onSaved: onChanged,
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Diagram'),
        content: Text('Delete "${model.meta.name}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: const Color(0xFFFF3B30)),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await DiagramStorage.instance.deleteMyModel(model.meta.id);
      onChanged();
    }
  }

  @override
  Widget build(BuildContext context) {
    final diagram = model.diagram;
    return _Pressable(
      onTap: () => _open(context),
      onLongPress: () => _confirmDelete(context),
      child: Container(
        width: 160,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (diagram != null)
              _TeaserPreview(
                diagram: diagram,
                width: 160,
                height: 100,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(12)),
              )
            else
              Container(
                width: 160,
                height: 100,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(12)),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
              child: Text(
                model.meta.name,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1C1C1E)),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: ListenableBuilder(
                listenable: DiagramStorage.instance.syncStatusNotifier,
                builder: (context, _) {
                  final status =
                      DiagramStorage.instance.getSyncStatus(_localId);
                  return Row(
                    children: [
                      Expanded(
                        child: Text(
                          _formatDate(model.meta.createdAt),
                          style:
                              TextStyle(fontSize: 11, color: Colors.grey[500]),
                          maxLines: 1,
                        ),
                      ),
                      if (status == SyncStatus.syncing)
                        const SizedBox(
                          width: 12, height: 12,
                          child: CircularProgressIndicator(strokeWidth: 1.5),
                        )
                      else if (status == SyncStatus.failed)
                        const Icon(Icons.cloud_off_outlined,
                            size: 14, color: Color(0xFFFF3B30)),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatDate(DateTime dt) {
  final now = DateTime.now();
  final diff = now.difference(dt);
  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inHours < 1) return '${diff.inMinutes}m ago';
  if (diff.inDays < 1) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return '${dt.day}.${dt.month}.${dt.year}';
}

// ── Remote model card (horizontal scroll) ────────────────────────

class _RemoteModelCard extends StatelessWidget {
  final ApiModelMeta meta;
  final DiagramModel? diagram;

  const _RemoteModelCard({required this.meta, this.diagram});

  void _openModel(BuildContext context) {
    if (diagram == null) return;
    final ownerName = meta.ownerName;
    final parts = ownerName.split(' ');
    final initials = parts.length >= 2
        ? '${parts.first[0]}${parts.last[0]}'.toUpperCase()
        : ownerName.isNotEmpty ? ownerName[0].toUpperCase() : '?';
    _openPresentation(context, diagram!,
        title: meta.name,
        creator: SampleCreator(
          id: meta.ownerId,
          name: ownerName,
          initials: initials,
          bio: '',
          colorValue: 0xFF007AFF,
          followers: 0,
        ));
  }

  @override
  Widget build(BuildContext context) {
    return _Pressable(
      onTap: () => _openModel(context),
      child: Container(
        width: 160,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (diagram != null)
              _TeaserPreview(
                diagram: diagram!,
                width: 160,
                height: 100,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(12)),
              )
            else
              Container(
                width: 160,
                height: 100,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(12)),
                ),
                child: Center(
                  child: Icon(Icons.cloud_off, color: Colors.grey[400]),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
              child: Text(
                meta.name,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1C1C1E)),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                meta.ownerName.isNotEmpty
                    ? meta.ownerName
                    : 'v${meta.version}',
                style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                maxLines: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Small card (horizontal scroll) ───────────────────────────────

class _SmallCard extends StatelessWidget {
  final SampleDiagramEntry entry;

  const _SmallCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    final diagram = entry.builder();
    return _Pressable(
      onTap: () {
        _openPresentation(context, diagram,
            title: entry.name, creator: entry.creator, entry: entry);
      },
      child: Container(
        width: 160,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _TeaserPreview(
                  diagram: diagram,
                  width: 160,
                  height: 100,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(12)),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
                  child: Text(
                    entry.name,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1C1C1E)),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    _subtitle(entry.name),
                    style: const TextStyle(fontSize: 11, color: Color(0xFF636366)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                  child: _CreatorRow(creator: entry.creator, avatarSize: 24, fontSize: 11),
                ),
              ],
            ),
            if (entry.isFavorite || entry.isPaid)
              Positioned(
                top: 6,
                right: 6,
                child: _BadgeIcons(
                    isFavorite: entry.isFavorite, isPaid: entry.isPaid),
              ),
          ],
        ),
      ),
    );
  }
}

// ── List card (vertical list) ────────────────────────────────────

class _ListCard extends StatelessWidget {
  final SampleDiagramEntry entry;

  const _ListCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    final diagram = entry.builder();
    return _Pressable(
      onTap: () => _openPresentation(context, diagram,
                              title: entry.name, creator: entry.creator, entry: entry),
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
        child: Stack(
          children: [
            Row(
              children: [
                _TeaserPreview(
                  diagram: diagram,
                  width: 90,
                  height: 96,
                  borderRadius:
                      const BorderRadius.horizontal(left: Radius.circular(12)),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
                        const SizedBox(height: 3),
                        Text(
                          _subtitle(entry.name),
                          style: const TextStyle(fontSize: 12, color: Color(0xFF636366)),
                        ),
                        const SizedBox(height: 6),
                        _CreatorRow(
                            creator: entry.creator,
                            avatarSize: 24,
                            fontSize: 11),
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
            if (entry.isFavorite || entry.isPaid)
              Positioned(
                top: 6,
                right: 6,
                child: _BadgeIcons(
                    isFavorite: entry.isFavorite, isPaid: entry.isPaid),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Pressable wrapper ─────────────────────────────────────────

/// Wraps a child with press-down opacity feedback.
class _Pressable extends StatefulWidget {
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final Widget child;

  const _Pressable({required this.onTap, this.onLongPress, required this.child});

  @override
  State<_Pressable> createState() => _PressableState();
}

class _PressableState extends State<_Pressable> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      onLongPress: widget.onLongPress,
      child: AnimatedOpacity(
        opacity: _pressed ? 0.5 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: widget.child,
      ),
    );
  }
}

// ── Creator profile screen (fullscreen) ───────────────────────

class _CreatorProfileScreen extends StatelessWidget {
  final SampleCreator creator;

  const _CreatorProfileScreen({required this.creator});

  @override
  Widget build(BuildContext context) {
    final creatorDiagrams =
        SampleDiagrams.all.where((e) => e.creator.id == creator.id).toList();
    final topPad = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: CustomScrollView(
        slivers: [
          // ── Top bar with close button ──
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.only(top: topPad + 8, left: 16, right: 16),
              child: Row(
                children: [
                  CloseCircleButton(onPressed: () => Navigator.pop(context), isBack: true),
                  const Spacer(),
                  CloseCircleButton(
                    onPressed: () => dismissToDashboard(context),
                  ),
                ],
              ),
            ),
          ),
          // ── Profile header ──
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: Column(
                children: [
                  _CreatorAvatar(creator: creator, size: 72),
                  const SizedBox(height: 12),
                  Text(
                    creator.name,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1C1C1E),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_formatNumber(creator.followers)} followers · '
                    '${creatorDiagrams.length} processes',
                    style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    creator.bio,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {},
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF1C1C1E),
                            side: const BorderSide(color: Color(0xFF1C1C1E)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text('Follow'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                    'Messaging ${creator.name} is not available yet'),
                              ),
                            );
                          },
                          icon: const Icon(Icons.chat_bubble_outline, size: 16),
                          label: const Text('Message'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF1C1C1E),
                            side: const BorderSide(color: Color(0xFF1C1C1E)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Processes',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey[800],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
          // ── Diagram list ──
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, i) {
                  final entry = creatorDiagrams[i];
                  final diagram = entry.builder();
                  final teaser = _findTeaserImage(diagram);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _ProfileDiagramCard(
                      name: entry.name,
                      diagram: diagram,
                      subtitle: _subtitle(entry.name),
                      teaserImage: teaser,
                      creator: entry.creator,
                    ),
                  );
                },
                childCount: creatorDiagrams.length,
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }
}
