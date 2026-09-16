/// Content of a step, modelled as an ordered list of typed blocks.
///
/// A [StepBlock] is *what* a step contains; a skin decides *how* it looks, and
/// a category pack can add new block types. The base is intentionally an
/// abstract class (not `sealed`) so packs in other libraries can contribute
/// their own blocks; dispatch happens via the registry by runtime type.
abstract class StepBlock {
  const StepBlock();
}

enum MediaKind { image, video }

/// A media item reference (asset path, local file, or `remote:<id>`).
class MediaRef {
  final String src;
  const MediaRef(this.src);
}

/// A document reference (typically a PDF).
class DocRef {
  final String src;
  final String? name;
  final int? pages;
  const DocRef(this.src, {this.name, this.pages});
}

/// One branch of a decision, pointing at the next step.
class Choice {
  final String label;
  final String targetId;
  const Choice(this.label, this.targetId);
}

// ── Core block types ────────────────────────────────────────────────

class TextBlock extends StepBlock {
  final String text;
  const TextBlock(this.text);
}

class MediaBlock extends StepBlock {
  final MediaKind kind;
  final List<MediaRef> items;
  const MediaBlock(this.kind, this.items);
}

class DocBlock extends StepBlock {
  final List<DocRef> docs;
  const DocBlock(this.docs);
}

class LinkBlock extends StepBlock {
  final String url;
  final String label;
  const LinkBlock(this.url, this.label);
}

class ChoiceBlock extends StepBlock {
  final List<Choice> options;
  const ChoiceBlock(this.options);
}

/// One tappable point on a [HotspotBlock] image, positioned by normalized
/// coordinates (0..1 of the image's width/height) so it's resolution-independent.
class Hotspot {
  final double x;
  final double y;
  final String label;
  final String detail;
  const Hotspot(this.x, this.y, this.label, this.detail);
}

/// An image with tappable hotspots — tap a labeled point to reveal a detail
/// (e.g. tap a status light to learn what solid / blinking / red means). The
/// interactive, visual primitive a chatbot can't replicate.
class HotspotBlock extends StepBlock {
  final String imageSrc;
  final List<Hotspot> spots;
  const HotspotBlock(this.imageSrc, this.spots);
}

/// Severity of a [CalloutBlock] — decides its tint and icon.
enum CalloutSeverity { warning, note, tip }

/// A highlighted aside (a warning, note, or tip) rendered as a tinted tile,
/// so safety/important text stands out instead of blending into the prose.
class CalloutBlock extends StepBlock {
  final CalloutSeverity severity;
  final String text;
  const CalloutBlock(this.severity, this.text);
}
