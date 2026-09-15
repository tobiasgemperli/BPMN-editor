import 'package:flutter/material.dart';

/// Below this many logical pixels on screen, text is unreadable, so the
/// miniature draws gray bars in its place instead of illegible glyphs.
const double _legiblePx = 7.0;

/// Carries the on-screen scale a card is being drawn at, so [SkinText] deep in
/// the tree can tell whether its text will be legible. 1.0 = full-size card;
/// the miniature wraps the same card tree at a fraction (e.g. 0.35).
class SkinScale extends InheritedWidget {
  final double scale;
  const SkinScale({super.key, required this.scale, required super.child});

  static double of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SkinScale>()?.scale ?? 1.0;

  @override
  bool updateShouldNotify(SkinScale oldWidget) => oldWidget.scale != scale;
}

/// Wraps a small detail — a play button, an arrow, a glyph icon — that carries
/// little meaning once the card is shrunk. Below the point where the detail
/// would render smaller than [minPx] on screen it collapses to nothing, so a
/// tiny miniature is left with just its boxes and bars instead of illegible
/// specks. [size] is the detail's on-card size (e.g. the icon's `size`).
class SkinDetail extends StatelessWidget {
  final double size;
  final double minPx;
  final Widget child;
  const SkinDetail({
    super.key,
    required this.size,
    required this.child,
    this.minPx = 13.0,
  });

  @override
  Widget build(BuildContext context) {
    final scale = SkinScale.of(context);
    if (size * scale < minPx) return const SizedBox.shrink();
    return child;
  }
}

/// Collapses a cluster of small sibling boxes into a single merged box once
/// they would be packed too tightly to read as separate things. [itemExtent] is
/// the on-card size of one item along the cluster's axis; below the point where
/// that would render smaller than [minItemPx] on screen, [merged] is shown
/// instead of [detailed]. The general counterpart to [SkinDetail]: where that
/// hides a lone detail, this combines a group.
class SkinMerge extends StatelessWidget {
  final double itemExtent;
  final double minItemPx;
  final Widget detailed;
  final Widget merged;
  const SkinMerge({
    super.key,
    required this.itemExtent,
    required this.detailed,
    required this.merged,
    this.minItemPx = 26.0,
  });

  @override
  Widget build(BuildContext context) {
    final scale = SkinScale.of(context);
    return itemExtent * scale < minItemPx ? merged : detailed;
  }
}

/// Drop-in for [Text] inside skins. At full size (or whenever the text is still
/// large enough to read) it renders normally. When the card is scaled down far
/// enough that this text would be sub-legible, it renders gray placeholder bars
/// that mirror the real line breaks and ragged edges — so the miniature keeps
/// the same layout as the card, just with unreadable text abstracted away.
class SkinText extends StatelessWidget {
  final String data;
  final TextStyle style;
  final int? maxLines;
  final TextAlign textAlign;

  const SkinText(
    this.data, {
    super.key,
    required this.style,
    this.maxLines,
    this.textAlign = TextAlign.start,
  });

  @override
  Widget build(BuildContext context) {
    final scale = SkinScale.of(context);
    final fontSize = style.fontSize ?? 14;
    if (fontSize * scale >= _legiblePx) {
      return Text(
        data,
        style: style,
        maxLines: maxLines,
        overflow: maxLines == null ? null : TextOverflow.ellipsis,
        textAlign: textAlign,
      );
    }

    // Too small to read at this scale → skeleton bars matching the real lines.
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth =
            constraints.maxWidth.isFinite ? constraints.maxWidth : double.infinity;
        final painter = TextPainter(
          text: TextSpan(text: data, style: style),
          textDirection: TextDirection.ltr,
          textAlign: textAlign,
          maxLines: maxLines,
        )..layout(maxWidth: maxWidth);
        final lines = painter.computeLineMetrics();
        final barColor = _barColor(style.color);
        final radius = (fontSize * 0.3).clamp(1.0, 5.0);
        final barHeight = (fontSize * 0.58).clamp(3.0, fontSize);

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: textAlign == TextAlign.center
              ? CrossAxisAlignment.center
              : CrossAxisAlignment.start,
          children: [
            for (final line in lines)
              SizedBox(
                height: line.height,
                child: Align(
                  alignment: textAlign == TextAlign.center
                      ? Alignment.center
                      : Alignment.centerLeft,
                  child: Container(
                    width: line.width.clamp(6.0, 100000.0),
                    height: barHeight,
                    decoration: BoxDecoration(
                      color: barColor,
                      borderRadius: BorderRadius.circular(radius),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  /// The bar keeps the text's own colour, softened so it reads as a skeleton
  /// line rather than a solid block: a blue eyebrow degrades to a faint blue
  /// bar, the red "PDF" badge to a red bar, dark body copy to a light gray.
  /// Translucency keeps it legible on both light cards and dark heroes.
  static Color _barColor(Color? color) {
    final base = color ?? const Color(0xFF1C1C1E);
    final alpha = base.computeLuminance() > 0.6 ? 0.6 : 0.5;
    return base.withValues(alpha: alpha);
  }
}
