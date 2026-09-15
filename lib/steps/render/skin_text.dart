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

  /// A neutral bar tuned to the text's own tone: light text (over a dark hero)
  /// gets a translucent white bar; dark text gets an iOS-gray bar.
  static Color _barColor(Color? color) {
    final base = color ?? const Color(0xFF1C1C1E);
    return base.computeLuminance() > 0.6
        ? Colors.white.withValues(alpha: 0.6)
        : const Color(0xFFCED0D6);
  }
}
