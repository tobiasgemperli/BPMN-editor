import 'package:flutter/widgets.dart';
import '../model/step_block.dart';
import '../model/step_view.dart';
import '../render/block_view.dart';
import '../render/skin_text.dart';
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
    final skin = _skinOr(skinId);
    if (skin == null) return const SizedBox.shrink();
    return skin.buildStep(context, step, (c, b, cx) => renderBlock(c, b, cx));
  }

  /// Design-space width the miniature lays the card out at before scaling. The
  /// card is built once at this width, then uniformly shrunk to the thumbnail —
  /// so the miniature has the *same layout and element positions* as the card,
  /// just smaller.
  static const double _miniatureDesignWidth = 300.0;

  /// Render the miniature: the real [buildStep] card, laid out at a fixed design
  /// width and scaled down to fit. [SkinText] inside degrades to gray bars once
  /// a run of text becomes too small to read, so tiny thumbnails show boxes
  /// while larger ones keep the big text legible.
  ///
  /// [degradeZoom] multiplies the legibility scale WITHOUT changing the layout —
  /// pass the canvas zoom when the miniature lives inside a Transform (e.g. the
  /// editor), so text resolves from bars as the user zooms in.
  Widget renderMiniature(BuildContext context, String skinId, StepView step,
      {double degradeZoom = 1.0}) {
    final skin = _skinOr(skinId);
    if (skin == null) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, constraints) {
        final boxWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : _miniatureDesignWidth;
        final boxHeight = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : boxWidth * 4 / 3;
        final scale = boxWidth / _miniatureDesignWidth;
        final designHeight = boxHeight / scale;
        return SkinScale(
          scale: scale * degradeZoom,
          child: ClipRect(
            child: FittedBox(
              fit: BoxFit.fill,
              child: SizedBox(
                width: _miniatureDesignWidth,
                height: designHeight,
                // Strip the device safe-area insets: a miniature is a fixed
                // design-space card, not the full screen, so skins must not add
                // home-indicator / notch padding here.
                child: MediaQuery(
                  data: MediaQuery.of(context).removePadding(
                    removeTop: true,
                    removeBottom: true,
                    removeLeft: true,
                    removeRight: true,
                  ),
                  child: skin.buildStep(
                      context, step, (c, b, cx) => renderBlock(c, b, cx)),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  StepSkin? _skinOr(String id) =>
      _skins[id] ?? (_skins.isEmpty ? null : _skins.values.first);
}
