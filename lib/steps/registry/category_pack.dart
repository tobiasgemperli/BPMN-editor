import '../model/step_block.dart';
import 'step_registry.dart';

/// A domain plugin (workout, assembly, permit, …). Declares which block types
/// its editor offers, a default skin, and registers renderers/editors for its
/// own block types. The core never imports a pack; packs are installed at
/// startup via [StepRegistry.install].
abstract interface class CategoryPack {
  String get id;
  String get defaultSkinId;

  /// Block types this category offers in the editor palette (core + own).
  List<Type> get paletteBlocks;

  /// Register this pack's skins and block views into [registry].
  void register(StepRegistry registry);
}

/// Marker so [paletteBlocks] can reference core types conveniently.
const coreBlockTypes = <Type>[
  TextBlock,
  MediaBlock,
  DocBlock,
  LinkBlock,
  ChoiceBlock,
];
