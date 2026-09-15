import 'package:flutter/widgets.dart';
import '../model/step_block.dart';

/// Hints a skin passes down so a shared block renderer can adapt (e.g. an image
/// renders full-bleed in the immersive skin but as a tile in the classic skin).
class SkinContext {
  final String skinId;
  final bool immersive;
  const SkinContext(this.skinId, {this.immersive = false});
}

/// Renders a single block of type [T]. Registered per block type in the
/// [StepRegistry]; category packs contribute views for their own block types.
abstract interface class BlockView<T extends StepBlock> {
  Widget build(BuildContext context, T block, SkinContext ctx);
}
