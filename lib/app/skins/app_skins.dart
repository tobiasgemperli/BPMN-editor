import '../../diagram/model/diagram_model.dart';
import '../../steps/adapter/task_content_adapter.dart';
import '../../steps/model/step_block.dart';
import '../../steps/model/step_view.dart';
import '../../steps/registry/packs/workout_pack.dart';
import '../../steps/registry/step_registry.dart';
import '../../steps/render/skins/classic_skin.dart';
import '../../steps/render/skins/immersive_skin.dart';
import 'app_media_view.dart';
import 'app_hotspot_view.dart';

/// The app's shared skin registry: the render-layer skins/packs plus real media
/// wired in over the placeholders. One instance is reused everywhere (previews
/// and the live presentation).
final StepRegistry appStepRegistry = _build();

StepRegistry _build() {
  final r = StepRegistry();
  installClassic(r);
  installImmersive(r);
  r.install(const WorkoutPack());
  // Override the placeholder media view with the real loader.
  r.registerBlock<MediaBlock>(const AppMediaView());
  // Interactive hotspot block (tappable image regions).
  r.registerBlock<HotspotBlock>(const AppHotspotView());
  return r;
}

/// Portrait exercise clips (YMove, free for commercial use) uploaded to the
/// backend file store. Reference as `remote:<id>` in content. Uploaded by
/// test/upload_exercise_media (qa); files are served globally by id.
const Map<String, String> exerciseClipIds = {
  'squat': 'f_c9LJjW',
  'kettlebell_swing': 'f_HjOUiH',
  'deadlift': 'f_80sgeL',
  'hip_thrust': 'f_avCGHU',
  'overhead_press': 'f_xxVqL3',
};

/// Skins offered to the user in the picker.
const List<({String id, String label})> selectableSkins = [
  (id: 'classic', label: 'Classic'),
  (id: 'immersive', label: 'Immersive'),
];

/// Adapt a diagram node into a [StepView] for the skin system. A gateway's
/// outgoing edges become a [ChoiceBlock]; content maps via the existing adapter.
StepView nodeToStepView(
  NodeModel node,
  DiagramModel diagram, {
  int? index,
  int? total,
  bool linear = true,
  String? eyebrow,
}) {
  final blocks = <StepBlock>[...blocksFromTaskContent(node.content)];

  // Workout metadata → the workout pack's reps/music blocks (app layer knows
  // about packs; the core adapter stays pack-agnostic).
  final w = node.content?.workout;
  if (w != null) {
    blocks.add(RepsBlock(
        sets: w.sets,
        reps: w.reps,
        rest: w.restSeconds != null ? Duration(seconds: w.restSeconds!) : null));
    if (w.musicTitle != null) {
      blocks.add(MusicBlock(w.musicTitle!, bpm: w.musicBpm));
    }
  }

  if (node.type == NodeType.exclusiveGateway) {
    final outgoing = diagram.outgoingEdges(node.id);
    if (outgoing.isNotEmpty) {
      blocks.add(ChoiceBlock([
        for (final e in outgoing)
          Choice(e.name.isNotEmpty ? e.name : 'Option', e.targetId),
      ]));
    }
  }

  return StepView(
    title: node.name,
    eyebrow: eyebrow,
    progress: index != null
        ? ProgressInfo(index: index + 1, total: total, linear: linear)
        : const ProgressInfo.none(),
    blocks: blocks,
  );
}
