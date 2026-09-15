import 'package:flutter/material.dart';
import '../../model/step_block.dart';
import '../../model/step_view.dart';
import '../../registry/step_registry.dart';
import '../block_view.dart';
import '../skin_text.dart';
import '../step_skin.dart';

const _accent = Color(0xFF007AFF);
const _ink = Color(0xFF1C1C1E);
const _ink2 = Color(0xFF3A3A3C);
const _surface = Color(0xFFF3F3F1);
const _pdf = Color(0xFFE2453B);

/// Media-first skin: a hero medium fills the card, the cue overlays on a scrim,
/// progress is segmented at the top. Text-only steps become a typographic
/// slide. Unlike ClassicSkin this composes holistically (it picks a hero from
/// the blocks) rather than stacking every block.
class ImmersiveSkin implements StepSkin {
  const ImmersiveSkin();

  @override
  String get id => 'immersive';
  @override
  String get label => 'Immersive';

  @override
  Widget buildStep(BuildContext context, StepView step, RenderBlock renderBlock) {
    MediaBlock? media;
    DocBlock? heroDoc;
    TextBlock? text;
    ChoiceBlock? choice;
    final links = <LinkBlock>[];
    final extraDocs = <DocBlock>[];
    final extras = <StepBlock>[]; // category blocks (reps, music, …)

    for (final b in step.blocks) {
      if (b is MediaBlock && media == null) {
        media = b;
      } else if (b is TextBlock && text == null) {
        text = b;
      } else if (b is ChoiceBlock && choice == null) {
        choice = b;
      } else if (b is DocBlock) {
        if (media == null && heroDoc == null) {
          heroDoc = b;
        } else {
          extraDocs.add(b);
        }
      } else if (b is LinkBlock) {
        links.add(b);
      } else if (b is! MediaBlock && b is! TextBlock && b is! ChoiceBlock) {
        extras.add(b); // unknown/category block → render via its registered view
      }
    }

    final hasHero = media != null || heroDoc != null;
    if (!hasHero) {
      return _typoSlide(context, step, text, choice, links, extras, renderBlock);
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        if (media != null)
          renderBlock(context, media, const SkinContext('immersive', immersive: true))
        else if (heroDoc != null)
          _docBg(),
        _scrim(context, step, text, choice, links, extraDocs, extras, renderBlock,
            onDark: media != null),
      ],
    );
  }

  // ── doc hero background (placeholder) ──
  Widget _docBg() => Container(
        color: _surface,
        alignment: Alignment.center,
        child: Container(
          width: 150,
          height: 200,
          margin: const EdgeInsets.only(bottom: 40),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            boxShadow: const [
              BoxShadow(color: Colors.black26, blurRadius: 18, offset: Offset(0, 8))
            ],
          ),
          child: const Align(
            alignment: Alignment.topLeft,
            child: Padding(
              padding: EdgeInsets.all(12),
              child: SkinDetail(
                  size: 28, child: Icon(Icons.picture_as_pdf, color: _pdf, size: 28)),
            ),
          ),
        ),
      );

  // ── bottom scrim overlay over media/doc ──
  Widget _scrim(BuildContext context, StepView step, TextBlock? text,
      ChoiceBlock? choice, List<LinkBlock> links, List<DocBlock> extraDocs,
      List<StepBlock> extras, RenderBlock renderBlock,
      {required bool onDark}) {
    final fg = onDark ? Colors.white : _ink;
    return Align(
      alignment: Alignment.bottomLeft,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 40, 16, 20),
        decoration: onDark
            ? const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Color(0xCC000000), Color(0x00000000)],
                ),
              )
            : null,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_eyebrow(step) != null)
              SkinText(_eyebrow(step)!,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                      color: onDark ? Colors.white70 : _accent)),
            const SizedBox(height: 4),
            SkinText(step.title,
                style: TextStyle(
                    fontSize: 20, fontWeight: FontWeight.w700, color: fg)),
            if (text != null) ...[
              const SizedBox(height: 6),
              SkinText(text.text,
                  maxLines: 3,
                  style: TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      color: onDark ? Colors.white : _ink2)),
            ],
            if (choice != null)
              for (final o in choice.options) _optionPill(o.label, onDark),
            for (final e in extras)
              renderBlock(context, e, SkinContext(id, immersive: onDark)),
            if (links.isNotEmpty || extraDocs.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Wrap(spacing: 6, runSpacing: 6, children: [
                  for (final _ in extraDocs) _chip('PDF', onDark),
                  for (final l in links) _chip('↗ ${l.label}', onDark),
                ]),
              ),
          ],
        ),
      ),
    );
  }

  Widget _optionPill(String label, bool onDark) => Padding(
        padding: const EdgeInsets.only(top: 7),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: onDark ? Colors.white24 : _surface,
            borderRadius: BorderRadius.circular(11),
            border: onDark ? Border.all(color: Colors.white38) : null,
          ),
          child: Row(children: [
            Expanded(
                child: SkinText(label,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: onDark ? Colors.white : _ink))),
            SkinDetail(
                size: 16,
                child: Icon(Icons.arrow_forward,
                    size: 16, color: onDark ? Colors.white : _accent)),
          ]),
        ),
      );

  Widget _chip(String label, bool onDark) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: onDark ? Colors.white24 : _surface,
          borderRadius: BorderRadius.circular(6),
        ),
        child: SkinText(label,
            style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: onDark ? Colors.white : _ink2)),
      );

  // A soft, deterministic pastel gradient derived from the title, so text-only
  // steps get a distinct colourful backdrop instead of flat gray. Kept light so
  // the dark ink text stays readable.
  static LinearGradient _titleGradient(String title) {
    final base = (title.hashCode % 360).abs().toDouble();
    // Two clearly distinct hues (~85° apart) with a real lightness drop, so the
    // gradient reads as a gradient — but kept light enough for dark ink text.
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        HSLColor.fromAHSL(1, base, 0.78, 0.86).toColor(),
        HSLColor.fromAHSL(1, (base + 85) % 360, 0.72, 0.66).toColor(),
      ],
    );
  }

  // ── typographic slide (no hero medium) ──
  Widget _typoSlide(BuildContext context, StepView step, TextBlock? text,
          ChoiceBlock? choice, List<LinkBlock> links, List<StepBlock> extras,
          RenderBlock renderBlock) =>
      Container(
        decoration: BoxDecoration(gradient: _titleGradient(step.title)),
        padding: const EdgeInsets.all(22),
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_eyebrow(step) != null)
              SkinText(_eyebrow(step)!,
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                      color: _accent)),
            const SizedBox(height: 6),
            SkinText(step.title,
                style: const TextStyle(
                    fontSize: 22, fontWeight: FontWeight.w700, color: _ink)),
            if (text != null) ...[
              const SizedBox(height: 10),
              SkinText(text.text,
                  style: const TextStyle(fontSize: 14, height: 1.5, color: _ink2)),
            ],
            if (choice != null)
              for (final o in choice.options) _optionPill(o.label, false),
            for (final e in extras)
              renderBlock(context, e, const SkinContext('immersive')),
            for (final l in links) _optionPill('↗ ${l.label}', false),
          ],
        ),
      );

  String? _eyebrow(StepView s) {
    final parts = <String>[];
    final e = s.eyebrow;
    if (e != null && e.isNotEmpty) parts.add(e.toUpperCase());
    final p = s.progress;
    if (p.index != null) {
      parts.add(
          p.linear && p.total != null ? '${p.index} / ${p.total}' : 'STEP ${p.index}');
    }
    return parts.isEmpty ? null : parts.join(' · ');
  }
}

/// Install the Immersive skin. It composes holistically, so it needs no
/// per-block views registered.
void installImmersive(StepRegistry registry) =>
    registry.registerSkin(const ImmersiveSkin());
