import 'package:flutter/material.dart';
import '../../steps/model/step_view.dart';
import '../../steps/registry/step_registry.dart';

/// Inspect one step's miniature across zoom: a live slider plus a fixed ladder
/// of sizes, so the text→bar degradation (and which runs stay readable at which
/// scale) is visible on the same view. Opened from the Skin Preview.
class ZoomLevelsView extends StatefulWidget {
  final StepRegistry registry;
  final String skinId;
  final StepView view;
  const ZoomLevelsView({
    super.key,
    required this.registry,
    required this.skinId,
    required this.view,
  });

  @override
  State<ZoomLevelsView> createState() => _ZoomLevelsViewState();
}

class _ZoomLevelsViewState extends State<ZoomLevelsView> {
  double _width = 120;

  static const _ladder = [48.0, 64.0, 90.0, 120.0, 160.0, 210.0];

  Widget _mini(double w) => Container(
        width: w,
        height: w * 4 / 3,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          boxShadow: const [
            BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 3))
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: widget.registry.renderMiniature(context, widget.skinId, widget.view),
      );

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFFF2F2F4),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: ListView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 32),
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text('Zoom levels · ${widget.view.title}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text('Drag the slider — text becomes gray bars once it is too small '
                'to read, and returns as you zoom in.',
                style: TextStyle(fontSize: 12.5, color: Colors.grey[600])),
            const SizedBox(height: 20),

            // Live, slider-driven preview.
            Center(child: _mini(_width)),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.photo_size_select_small, size: 18, color: Colors.black45),
                Expanded(
                  child: Slider(
                    min: 40,
                    max: 300,
                    value: _width,
                    onChanged: (v) => setState(() => _width = v),
                  ),
                ),
                const Icon(Icons.crop_original, size: 20, color: Colors.black45),
              ],
            ),
            Center(
              child: Text('${_width.toInt()} px  ·  scale ${(_width / 300).toStringAsFixed(2)}',
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black54)),
            ),

            const SizedBox(height: 28),
            Text('Ladder',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                    color: Colors.grey[600])),
            const SizedBox(height: 12),
            Wrap(
              spacing: 14,
              runSpacing: 16,
              crossAxisAlignment: WrapCrossAlignment.end,
              children: [
                for (final w in _ladder)
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _mini(w),
                      const SizedBox(height: 5),
                      Text('${w.toInt()}px',
                          style: const TextStyle(fontSize: 10, color: Colors.black54)),
                    ],
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
