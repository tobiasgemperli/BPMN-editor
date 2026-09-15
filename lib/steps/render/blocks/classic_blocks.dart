import 'package:flutter/material.dart';
import '../../model/step_block.dart';
import '../block_view.dart';
import '../skin_text.dart';

// iOS-clean palette (matches the current card look).
const _ink = Color(0xFF1C1C1E);
const _ink2 = Color(0xFF3A3A3C);
const _ink3 = Color(0xFF8E8E93);
const _accent = Color(0xFF007AFF);
const _surface = Color(0xFFF3F3F1);
const _hair = Color(0xFFE5E5EA);
const _pdf = Color(0xFFE2453B);
const _pdfSoft = Color(0xFFFDECEA);

class ClassicTextView implements BlockView<TextBlock> {
  const ClassicTextView();
  @override
  Widget build(BuildContext c, TextBlock b, SkinContext ctx) => Padding(
        padding: const EdgeInsets.only(top: 12),
        child: SkinText(b.text,
            style: const TextStyle(fontSize: 16, height: 1.5, color: _ink2)),
      );
}

/// Placeholder media in the Classic skin. Faithful image/video loading is
/// wired in when the skin replaces ProcessCard (reusing the existing loaders);
/// here we only prove composition, so unresolved refs show a neutral tile.
class ClassicMediaView implements BlockView<MediaBlock> {
  const ClassicMediaView();
  @override
  Widget build(BuildContext c, MediaBlock b, SkinContext ctx) {
    if (b.kind == MediaKind.video) {
      return Padding(
        padding: const EdgeInsets.only(top: 12),
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: Container(
            decoration: BoxDecoration(
                color: const Color(0xFF191919),
                borderRadius: BorderRadius.circular(12)),
            child: const Center(
                child: SkinDetail(
                    size: 40,
                    child: Icon(Icons.play_circle_outline,
                        color: Colors.white70, size: 40))),
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final _ in b.items)
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Container(
                  width: 120,
                  height: 90,
                  color: _hair,
                  child: const SkinDetail(
                      size: 24,
                      child: Icon(Icons.image_outlined, color: _ink3))),
            ),
        ],
      ),
    );
  }
}

class ClassicDocView implements BlockView<DocBlock> {
  const ClassicDocView();
  @override
  Widget build(BuildContext c, DocBlock b, SkinContext ctx) => Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Column(
          children: [
            for (final d in b.docs)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _docTile(d),
              ),
          ],
        ),
      );

  Widget _docTile(DocRef d) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: _hair),
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 46,
              decoration: BoxDecoration(
                  color: _pdfSoft, borderRadius: BorderRadius.circular(6)),
              child: const Center(
                  child: SkinDetail(
                      size: 22,
                      child: Icon(Icons.picture_as_pdf, color: _pdf, size: 22))),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  SkinText(d.name ?? 'PDF document',
                      maxLines: 1,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600, color: _ink)),
                  const SizedBox(height: 4),
                  Row(children: [
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                          color: _pdf, borderRadius: BorderRadius.circular(4)),
                      child: const SkinText('PDF',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w800)),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: SkinText(
                          d.pages != null ? '${d.pages} pages' : 'Tap to open',
                          maxLines: 1,
                          style: const TextStyle(color: _ink3, fontSize: 12)),
                    ),
                  ]),
                ],
              ),
            ),
            const SkinDetail(
                size: 18, child: Icon(Icons.arrow_outward, size: 18, color: _ink3)),
          ],
        ),
      );
}

class ClassicLinkView implements BlockView<LinkBlock> {
  const ClassicLinkView();
  @override
  Widget build(BuildContext c, LinkBlock b, SkinContext ctx) => Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SkinDetail(
                size: 18, child: Icon(Icons.link, size: 18, color: _ink)),
            const SizedBox(width: 6),
            Flexible(
              child: SkinText(b.label,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w500, color: _ink)),
            ),
          ],
        ),
      );
}

class ClassicChoiceView implements BlockView<ChoiceBlock> {
  const ClassicChoiceView();
  @override
  Widget build(BuildContext c, ChoiceBlock b, SkinContext ctx) => Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Column(
          children: [
            for (final o in b.options)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                      color: _surface, borderRadius: BorderRadius.circular(12)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(children: [
                    Expanded(
                        child: SkinText(o.label,
                            style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: _ink))),
                    const SkinDetail(
                        size: 18,
                        child: Icon(Icons.arrow_forward, size: 18, color: _accent)),
                  ]),
                ),
              ),
          ],
        ),
      );
}
