import 'package:flutter/widgets.dart';
import '../model/step_block.dart';
import '../model/step_view.dart';
import 'block_view.dart';

/// Renders a single block. The registry supplies this to a skin so the skin
/// need not know the registry (avoids a circular dependency).
typedef RenderBlock = Widget Function(
    BuildContext context, StepBlock block, SkinContext ctx);

/// A skin decides the *layout & look* of a step: title position, media
/// treatment, background, progress. It delegates per-block rendering to
/// [renderBlock]. Add a new skin by implementing this — nothing else changes.
abstract interface class StepSkin {
  String get id;
  String get label;

  /// The full step card. The miniature is derived from this same tree (scaled
  /// down by the registry), so a skin never draws a separate thumbnail — card
  /// and miniature always match by construction. Text abstracts to gray bars at
  /// small scale via [SkinText]; use it instead of [Text] for readable content.
  Widget buildStep(BuildContext context, StepView step, RenderBlock renderBlock);
}
