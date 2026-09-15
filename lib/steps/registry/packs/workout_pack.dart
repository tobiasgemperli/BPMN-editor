import 'package:flutter/material.dart';
import '../../model/step_block.dart';
import '../../render/block_view.dart';
import '../category_pack.dart';
import '../step_registry.dart';

const _ink = Color(0xFF1C1C1E);
const _ink3 = Color(0xFF8E8E93);
const _accent = Color(0xFF007AFF);
const _surface = Color(0xFFF3F3F1);

// ── Category blocks contributed by this pack ────────────────────────
// These extend StepBlock from *this* library — exactly why StepBlock is an
// abstract base rather than `sealed`.

class RepsBlock extends StepBlock {
  final int sets;
  final int reps;
  final Duration? rest;
  const RepsBlock({required this.sets, required this.reps, this.rest});
}

class MusicBlock extends StepBlock {
  final String title;
  final int? bpm;
  const MusicBlock(this.title, {this.bpm});
}

// ── Views (theme-neutral so they read on light and immersive grounds) ──

class RepsView implements BlockView<RepsBlock> {
  const RepsView();
  @override
  Widget build(BuildContext c, RepsBlock b, SkinContext ctx) {
    Widget metric(String n, String u, {bool last = false}) => Expanded(
          child: Container(
            margin: EdgeInsets.only(right: last ? 0 : 8),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
                color: _surface, borderRadius: BorderRadius.circular(12)),
            child: Column(children: [
              Text(n,
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w700, color: _ink)),
              const SizedBox(height: 2),
              Text(u,
                  style: const TextStyle(
                      fontSize: 9, letterSpacing: 0.8, color: _ink3)),
            ]),
          ),
        );
    final rest = b.rest;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(children: [
        metric('${b.sets}', 'SETS'),
        metric('${b.reps}', 'REPS', last: rest == null),
        if (rest != null) metric('${rest.inSeconds}s', 'REST', last: true),
      ]),
    );
  }
}

class MusicView implements BlockView<MusicBlock> {
  const MusicView();
  @override
  Widget build(BuildContext c, MusicBlock b, SkinContext ctx) => Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
              color: _surface, borderRadius: BorderRadius.circular(12)),
          child: Row(children: [
            Container(
              width: 28,
              height: 28,
              decoration: const BoxDecoration(color: _accent, shape: BoxShape.circle),
              child: const Icon(Icons.play_arrow, color: Colors.white, size: 16),
            ),
            const SizedBox(width: 9),
            Expanded(
                child: Text(b.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600, color: _ink))),
            if (b.bpm != null)
              Text('${b.bpm} BPM',
                  style: const TextStyle(fontSize: 10, color: _ink3)),
          ]),
        ),
      );
}

/// Workout domain: adds reps/timing + music blocks. Any skin renders them via
/// the registered views; core never imports this pack.
class WorkoutPack implements CategoryPack {
  const WorkoutPack();

  @override
  String get id => 'workout';
  @override
  String get defaultSkinId => 'classic';
  @override
  List<Type> get paletteBlocks => const [...coreBlockTypes, RepsBlock, MusicBlock];

  @override
  void register(StepRegistry registry) {
    registry.registerBlock<RepsBlock>(const RepsView());
    registry.registerBlock<MusicBlock>(const MusicView());
  }
}
