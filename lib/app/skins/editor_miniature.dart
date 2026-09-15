import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../steps/model/step_block.dart';
import '../../steps/registry/packs/workout_pack.dart';
import '../../steps/registry/step_registry.dart';
import '../../steps/render/block_view.dart';
import '../../steps/render/skin_text.dart';
import '../../steps/render/skins/classic_skin.dart';
import '../../steps/render/skins/immersive_skin.dart';

/// Carries a node's already-decoded media (from the editor's Content view) down
/// to the media view, so editor miniatures render **statically** — no video
/// players, no async loads (the canvas shows every node at once).
class EditorMedia extends InheritedWidget {
  final List<ui.Image> images;
  final ui.Image? videoThumb;
  const EditorMedia({
    super.key,
    required this.images,
    this.videoThumb,
    required super.child,
  });

  static EditorMedia? of(BuildContext c) =>
      c.dependOnInheritedWidgetOfExactType<EditorMedia>();

  @override
  bool updateShouldNotify(EditorMedia old) =>
      old.images != images || old.videoThumb != videoThumb;
}

/// Media view for editor miniatures: draws the pre-decoded `ui.Image` (image, or
/// a video's first-frame thumbnail) — full-bleed in immersive, tiles in classic.
class EditorMediaView implements BlockView<MediaBlock> {
  const EditorMediaView();

  @override
  Widget build(BuildContext c, MediaBlock b, SkinContext ctx) {
    final media = EditorMedia.of(c);
    if (b.kind == MediaKind.video) {
      final thumb = media?.videoThumb;
      return ctx.immersive
          ? _fill(thumb, dark: true, play: true)
          : Padding(
              padding: const EdgeInsets.only(top: 12),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: AspectRatio(
                    aspectRatio: 16 / 9, child: _fill(thumb, dark: true, play: true)),
              ),
            );
    }
    final imgs = media?.images ?? const <ui.Image>[];
    if (ctx.immersive) {
      return _fill(imgs.isNotEmpty ? imgs.first : null, dark: false, play: false);
    }
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Wrap(spacing: 8, runSpacing: 8, children: [
        for (final im in imgs)
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(width: 120, height: 90, child: _fill(im, dark: false, play: false)),
          ),
      ]),
    );
  }

  Widget _fill(ui.Image? im, {required bool dark, required bool play}) {
    final bg = dark ? const Color(0xFF191919) : const Color(0xFFE5E5EA);
    return Stack(
      fit: StackFit.expand,
      children: [
        if (im != null) RawImage(image: im, fit: BoxFit.cover) else Container(color: bg),
        if (play)
          const Center(
              child: SkinDetail(
                  size: 44,
                  child: Icon(Icons.play_circle_fill, size: 44, color: Colors.white))),
      ],
    );
  }
}

/// Registry for editor miniatures: the skins/packs with a **static** media view
/// (backed by the editor's decoded images) over the async loader.
final StepRegistry editorStepRegistry = _build();

StepRegistry _build() {
  final r = StepRegistry();
  installClassic(r);
  installImmersive(r);
  r.install(const WorkoutPack());
  r.registerBlock<MediaBlock>(const EditorMediaView());
  return r;
}
