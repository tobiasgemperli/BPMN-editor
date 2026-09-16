import 'package:flutter/material.dart';
import '../../steps/model/step_block.dart';
import '../../steps/render/block_view.dart';
import '../widgets/step_media.dart';

/// Interactive renderer for [HotspotBlock]: the image fills the card and each
/// hotspot is a tappable marker; tapping one reveals its detail in a panel over
/// the image. Stateful — this is the first block that responds to touch.
class AppHotspotView implements BlockView<HotspotBlock> {
  const AppHotspotView();

  @override
  Widget build(BuildContext c, HotspotBlock b, SkinContext ctx) =>
      _HotspotCard(block: b);
}

class _HotspotCard extends StatefulWidget {
  final HotspotBlock block;
  const _HotspotCard({required this.block});
  @override
  State<_HotspotCard> createState() => _HotspotCardState();
}

class _HotspotCardState extends State<_HotspotCard> {
  int? _selected;

  @override
  Widget build(BuildContext context) {
    final spots = widget.block.spots;
    return LayoutBuilder(builder: (context, constraints) {
      final w = constraints.maxWidth;
      final h = constraints.hasBoundedHeight ? constraints.maxHeight : w * 16 / 9;
      return Stack(
        fit: StackFit.expand,
        children: [
          StepImage(widget.block.imageSrc, fit: BoxFit.cover),
          for (var i = 0; i < spots.length; i++)
            Positioned(
              left: spots[i].x * w - 22,
              top: spots[i].y * h - 22,
              child: _Marker(
                index: i + 1,
                active: _selected == i,
                onTap: () => setState(() => _selected = _selected == i ? null : i),
              ),
            ),
          if (_selected != null)
            Positioned(
              left: 16,
              right: 16,
              bottom: 20,
              child: _DetailPanel(
                spot: spots[_selected!],
                onClose: () => setState(() => _selected = null),
              ),
            )
          else
            const Positioned(
              left: 16,
              right: 16,
              bottom: 20,
              child: _Hint(),
            ),
        ],
      );
    });
  }
}

class _Marker extends StatelessWidget {
  final int index;
  final bool active;
  final VoidCallback onTap;
  const _Marker({required this.index, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = active ? const Color(0xFF007AFF) : Colors.white;
    final fg = active ? Colors.white : const Color(0xFF007AFF);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFF007AFF), width: 2),
          boxShadow: const [
            BoxShadow(color: Colors.black38, blurRadius: 8, offset: Offset(0, 2)),
          ],
        ),
        alignment: Alignment.center,
        child: Text('$index',
            style: TextStyle(
                color: fg, fontWeight: FontWeight.w800, fontSize: 18)),
      ),
    );
  }
}

class _DetailPanel extends StatelessWidget {
  final Hotspot spot;
  final VoidCallback onClose;
  const _DetailPanel({required this.spot, required this.onClose});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 12, 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(color: Colors.black26, blurRadius: 20, offset: Offset(0, 8)),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(spot.label,
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1C1C1E))),
                  const SizedBox(height: 4),
                  Text(spot.detail,
                      style: const TextStyle(
                          fontSize: 14, height: 1.4, color: Color(0xFF3A3A3C))),
                ],
              ),
            ),
            GestureDetector(
              onTap: onClose,
              child: const Padding(
                padding: EdgeInsets.only(left: 8, top: 2),
                child: Icon(Icons.close, size: 20, color: Color(0xFF8E8E93)),
              ),
            ),
          ],
        ),
      );
}

class _Hint extends StatelessWidget {
  const _Hint();
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.touch_app_outlined, size: 18, color: Colors.white),
            SizedBox(width: 8),
            Flexible(
              child: Text('Tap a light to see what it means',
                  style: TextStyle(color: Colors.white, fontSize: 13)),
            ),
          ],
        ),
      );
}
