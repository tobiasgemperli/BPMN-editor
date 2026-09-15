import 'package:flutter/material.dart';
import '../../model/step_block.dart';
import '../../model/step_view.dart';
import '../../registry/step_registry.dart';
import '../block_view.dart';
import '../step_skin.dart';
import '../blocks/classic_blocks.dart';

const _ink = Color(0xFF1C1C1E);
const _ink3 = Color(0xFF8E8E93);
const _accent = Color(0xFF007AFF);
const _hair = Color(0xFFE5E5EA);

/// The document-style card (today's look): flush-left eyebrow + title, then the
/// blocks stacked in order. Progress: "X / N" on linear flows, "Step X" on
/// branched (no total).
class ClassicSkin implements StepSkin {
  const ClassicSkin();

  @override
  String get id => 'classic';
  @override
  String get label => 'Classic';

  @override
  Widget buildStep(BuildContext context, StepView step, RenderBlock renderBlock) {
    const ctx = SkinContext('classic');
    final eyebrow = _eyebrow(step);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (eyebrow != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(eyebrow,
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.4,
                      color: _accent)),
            ),
          Text(step.title,
              style: const TextStyle(
                  fontSize: 22,
                  height: 1.1,
                  fontWeight: FontWeight.w700,
                  color: _ink)),
          for (final block in step.blocks) renderBlock(context, block, ctx),
        ],
      ),
    );
  }

  @override
  Widget buildMiniature(BuildContext context, StepView step) {
    // Small doc-style card: title + a row of content-type icons.
    final icons = <IconData>[];
    for (final b in step.blocks) {
      if (b is MediaBlock) {
        icons.add(b.kind == MediaKind.video
            ? Icons.play_circle_outline
            : Icons.image_outlined);
      } else if (b is DocBlock) {
        icons.add(Icons.picture_as_pdf);
      } else if (b is LinkBlock) {
        icons.add(Icons.link);
      } else if (b is ChoiceBlock) {
        icons.add(Icons.call_split);
      }
    }
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _hair),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(step.title,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 12, height: 1.15, fontWeight: FontWeight.w700, color: _ink)),
          const Spacer(),
          Row(
            children: [
              for (final i in icons.take(3))
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Icon(i, size: 14, color: _ink3),
                ),
            ],
          ),
        ],
      ),
    );
  }

  String? _eyebrow(StepView s) {
    final parts = <String>[];
    final e = s.eyebrow;
    if (e != null && e.isNotEmpty) parts.add(e.toUpperCase());
    final p = s.progress;
    if (p.index != null) {
      parts.add(p.linear && p.total != null ? '${p.index} / ${p.total}' : 'STEP ${p.index}');
    }
    return parts.isEmpty ? null : parts.join(' · ');
  }
}

/// Install the Classic skin and its block views into [registry].
void installClassic(StepRegistry registry) {
  registry.registerSkin(const ClassicSkin());
  registry.registerBlock<TextBlock>(const ClassicTextView());
  registry.registerBlock<MediaBlock>(const ClassicMediaView());
  registry.registerBlock<DocBlock>(const ClassicDocView());
  registry.registerBlock<LinkBlock>(const ClassicLinkView());
  registry.registerBlock<ChoiceBlock>(const ClassicChoiceView());
}
