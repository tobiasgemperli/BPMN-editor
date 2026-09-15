import 'package:flutter/widgets.dart';
import '../model/step_block.dart';
import '../model/step_view.dart';
import '../render/block_view.dart';
import '../render/step_skin.dart';
import 'category_pack.dart';

/// Central wiring for skins and block renderers. Category packs extend it at
/// startup. Block views are stored type-erased as closures so a
/// `BlockView<TextBlock>` can live next to a `BlockView<MediaBlock>` without
/// generic-variance trouble.
class StepRegistry {
  final Map<String, StepSkin> _skins = {};
  final Map<Type, Widget Function(BuildContext, StepBlock, SkinContext)>
      _blockViews = {};

  // ── registration ──
  void registerSkin(StepSkin skin) => _skins[skin.id] = skin;

  void registerBlock<T extends StepBlock>(BlockView<T> view) {
    _blockViews[T] = (context, block, ctx) => view.build(context, block as T, ctx);
  }

  void install(CategoryPack pack) => pack.register(this);

  // ── lookup ──
  StepSkin? skin(String id) => _skins[id];
  Iterable<StepSkin> get skins => _skins.values;

  /// Resolve which skin to use: explicit user choice → flow → category → first.
  String resolveSkinId({String? user, String? flow, String? category}) =>
      user ?? flow ?? category ?? (_skins.keys.isEmpty ? '' : _skins.keys.first);

  // ── rendering ──
  Widget renderBlock(BuildContext context, StepBlock block, SkinContext ctx) {
    final view = _blockViews[block.runtimeType];
    // Unknown block (e.g. a pack not installed) → render nothing, never crash.
    if (view == null) return const SizedBox.shrink();
    return view(context, block, ctx);
  }

  /// Render a whole step with the given skin (falls back to the first skin).
  /// The skin supplies each block's [SkinContext] when it calls the renderer.
  Widget renderStep(BuildContext context, String skinId, StepView step) {
    final skin = _skins[skinId] ?? (_skins.isEmpty ? null : _skins.values.first);
    if (skin == null) return const SizedBox.shrink();
    return skin.buildStep(context, step, (c, b, cx) => renderBlock(c, b, cx));
  }
}
