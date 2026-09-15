import 'step_block.dart';

/// Progress info for the eyebrow / indicator. For a linear flow [index]/[total]
/// are meaningful; for a branched flow only the ordinal [index] is (no [total]).
class ProgressInfo {
  final int? index;
  final int? total;
  final bool linear;
  const ProgressInfo({this.index, this.total, this.linear = true});

  const ProgressInfo.none() : index = null, total = null, linear = true;
}

/// A skin-agnostic view of one step: what to show, not how.
/// [eyebrow] is the category label; the skin composes it with [progress].
class StepView {
  final String title;
  final String? eyebrow;
  final ProgressInfo progress;
  final List<StepBlock> blocks;

  const StepView({
    required this.title,
    this.eyebrow,
    this.progress = const ProgressInfo.none(),
    this.blocks = const [],
  });
}
