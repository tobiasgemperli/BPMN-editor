import 'package:flutter/material.dart';
import '../../model/step_block.dart';
import '../../model/step_view.dart';
import '../../registry/step_registry.dart';
import '../block_view.dart';
import '../skin_text.dart';
import '../step_skin.dart';
import '../blocks/classic_blocks.dart';

const _ink = Color(0xFF1C1C1E);
const _accent = Color(0xFF007AFF);

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
              child: SkinText(eyebrow,
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.4,
                      color: _accent)),
            ),
          SkinText(step.title,
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
  registry.registerBlock<CalloutBlock>(const ClassicCalloutView());
}
