import 'package:flutter/material.dart';
import '../../steps/model/step_block.dart';
import '../../steps/render/block_view.dart';
import '../widgets/step_media.dart';

/// Real-media renderer for [MediaBlock], registered by the app over the render
/// layer's placeholder. Full-bleed in the immersive skin (it's the hero),
/// thumbnail tiles otherwise. The render layer stays pure — the loader lives
/// here in the app layer.
class AppMediaView implements BlockView<MediaBlock> {
  const AppMediaView();

  @override
  Widget build(BuildContext c, MediaBlock b, SkinContext ctx) {
    if (b.items.isEmpty) return const SizedBox.shrink();

    if (ctx.immersive) {
      // Hero: the first medium fills the card.
      final first = b.items.first.src;
      return b.kind == MediaKind.video ? StepVideo(first) : StepImage(first);
    }

    // Classic: a video tile, or a row of image thumbnails.
    if (b.kind == MediaKind.video) {
      return Padding(
        padding: const EdgeInsets.only(top: 12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: AspectRatio(aspectRatio: 16 / 9, child: StepVideo(b.items.first.src)),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final item in b.items)
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                  width: 120, height: 90, child: StepImage(item.src, fit: BoxFit.cover)),
            ),
        ],
      ),
    );
  }
}
