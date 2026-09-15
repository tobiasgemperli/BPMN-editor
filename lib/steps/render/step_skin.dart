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
  Widget buildStep(BuildContext context, StepView step, RenderBlock renderBlock);
}
