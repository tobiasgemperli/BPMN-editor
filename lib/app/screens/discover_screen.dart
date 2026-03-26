import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../diagram/model/diagram_model.dart';
import '../../diagram/samples/sample_diagrams.dart';
import '../widgets/close_circle_button.dart';
import 'presentation_screen.dart';
import 'editor_screen.dart';

/// YouTube-inspired discovery screen for browsing process content.
class DiscoverScreen extends StatelessWidget {
  const DiscoverScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;

    final samples = SampleDiagrams.all;
    final featured = samples.isNotEmpty ? samples.first : null;
    final rest = samples.length > 1 ? samples.sublist(1) : <SampleDiagramEntry>[];

    final tutorials = rest.where((s) =>
        s.name.contains('IKEA') ||
        s.name.contains('Content') ||
        s.name.contains('Emergency') ||
        s.name.contains('Coffee') ||
        s.name.contains('Flat Tire') ||
        s.name.contains('Plant') ||
        s.name.contains('Text Only') ||
        s.name.contains('Car Configurator') ||
        s.name.contains('Pasta') ||
        s.name.contains('Car Import')).toList();
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

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: Colors.grey[50],
        body: CustomScrollView(
          slivers: [
            // ── Top bar ─────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.only(
                    top: topPad + 16, left: 20, right: 20, bottom: 8),
                child: Row(
                  children: [
                    Text(
                      'Processes',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const Spacer(),
                    _Pressable(
                      onTap: () => Navigator.push(
                        context,
                        _bottomToTopRoute(
                            const EditorScreen(showCloseButton: true)),
                      ),
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFF007AFF),
                        ),
                        child: const Icon(Icons.add, size: 22, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Search bar ──────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                child: Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const SizedBox(width: 14),
                      Icon(Icons.search, size: 20, color: Colors.grey[500]),
                      const SizedBox(width: 10),
                      Text(
                        'Search processes...',
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ── Category chips ──────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(top: 16, bottom: 8),
                child: SizedBox(
                  height: 36,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    children: const [
                      _CategoryChip(label: 'All', selected: true),
                      _CategoryChip(label: 'Tutorials'),
                      _CategoryChip(label: 'Technical'),
                      _CategoryChip(label: 'Certification'),
                      _CategoryChip(label: 'Templates'),
                      _CategoryChip(label: 'Recent'),
                    ],
                  ),
                ),
              ),
            ),

            // ── Featured card ───────────────────────────────────
            if (featured != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                  child: _FeaturedCard(entry: featured),
                ),
              ),

            // ── My Flowcharts section ──────────────────────────
            if (SampleDiagrams.myDiagrams.isNotEmpty) ...[
              _sectionHeader(context, 'My Flowcharts'),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 210,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: SampleDiagrams.myDiagrams.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 12),
                    itemBuilder: (context, i) => _SmallCard(
                      entry: SampleDiagrams.myDiagrams[i],
                      isOwned: true,
                    ),
                  ),
                ),
              ),
            ],

            // ── Tutorials section ───────────────────────────────
            if (tutorials.isNotEmpty) ...[
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
            if (certification.isNotEmpty) ...[
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
            if (technical.isNotEmpty) ...[
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
            if (patterns.isNotEmpty) ...[
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
              ),
        ),
      ),
    );
  }
}

// ── Helpers ──────────────────────────────────────────────────────

String _subtitle(String name) {
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
    {String? title}) {
  Navigator.push(
    context,
    _bottomToTopRoute(EditorScreen(
      initialDiagram: diagram,
      title: title,
      role: DiagramRole.owner,
      showCloseButton: true,
    )),
  );
}

void _openPresentation(BuildContext context, DiagramModel diagram,
    {String? title, SampleCreator? creator}) {
  Navigator.push(
    context,
    _bottomToTopRoute(PresentationScreen(
      diagram: diagram,
      title: title,
      role: DiagramRole.viewer,
      creator: creator,
    )),
  );
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

// ── Creator avatar ──────────────────────────────────────────────

class _CreatorAvatar extends StatelessWidget {
  final SampleCreator creator;
  final double size;

  const _CreatorAvatar({required this.creator, this.size = 28});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Color(creator.colorValue),
      ),
      child: Center(
        child: Text(
          creator.initials,
          style: TextStyle(
            color: Colors.white,
            fontSize: size * 0.38,
            fontWeight: FontWeight.w700,
          ),
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
    this.avatarSize = 22,
    this.fontSize = 12,
  });

  @override
  Widget build(BuildContext context) {
    return _Pressable(
      onTap: () => _showCreatorProfile(context, creator),
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

void _showCreatorProfile(BuildContext context, SampleCreator creator) {
  Navigator.push(
    context,
    _bottomToTopRoute(_CreatorProfileScreen(creator: creator)),
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
        _openPresentation(context, diagram,
            title: name, creator: creator);
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
                            fontSize: 14, fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(subtitle,
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey[500])),
                    ],
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

  const _CategoryChip({required this.label, this.selected = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
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
                              title: entry.name, creator: entry.creator),
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
                          fontSize: 18, fontWeight: FontWeight.w700),
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
                              title: entry.name, creator: entry.creator),
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

// ── Small card (horizontal scroll) ───────────────────────────────

class _SmallCard extends StatelessWidget {
  final SampleDiagramEntry entry;
  final bool isOwned;

  const _SmallCard({required this.entry, this.isOwned = false});

  @override
  Widget build(BuildContext context) {
    final diagram = entry.builder();
    return _Pressable(
      onTap: () {
        if (isOwned) {
          _openOwnedEditor(context, diagram, title: entry.name);
        } else {
          _openPresentation(context, diagram,
              title: entry.name, creator: entry.creator);
        }
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
        child: Column(
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
                    fontSize: 13, fontWeight: FontWeight.w600),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                _subtitle(entry.name),
                style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              child: _CreatorRow(creator: entry.creator, avatarSize: 18, fontSize: 11),
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
                              title: entry.name, creator: entry.creator),
      child: Container(
        height: 88,
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
            _TeaserPreview(
              diagram: diagram,
              width: 90,
              height: 88,
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
                          fontSize: 14, fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _subtitle(entry.name),
                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                    ),
                    const SizedBox(height: 6),
                    _CreatorRow(
                        creator: entry.creator,
                        avatarSize: 18,
                        fontSize: 11),
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
    );
  }
}

// ── Pressable wrapper ─────────────────────────────────────────

/// Wraps a child with press-down opacity feedback.
class _Pressable extends StatefulWidget {
  final VoidCallback onTap;
  final Widget child;

  const _Pressable({required this.onTap, required this.child});

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
                  CloseCircleButton(onPressed: () => Navigator.pop(context)),
                  const Spacer(),
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
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_formatNumber(creator.followers)} followers · '
                    '${creatorDiagrams.length} processes',
                    style: TextStyle(fontSize: 13, color: Colors.grey[500]),
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
