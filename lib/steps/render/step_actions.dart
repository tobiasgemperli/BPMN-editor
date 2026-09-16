import 'package:flutter/widgets.dart';

/// How interactive elements in a skin (link pills, choice options) reach the
/// host. Provided by the presentation; read by skins via [StepActions.of]. Kept
/// in the render layer as plain callbacks so skins stay free of url_launcher /
/// navigation dependencies.
class StepActions extends InheritedWidget {
  /// Open an external link (a LinkBlock was tapped).
  final void Function(String url)? onOpenLink;

  /// Follow a choice/gateway option to [targetId] (a ChoiceBlock was tapped).
  final void Function(String targetId)? onChoose;

  const StepActions({
    super.key,
    this.onOpenLink,
    this.onChoose,
    required super.child,
  });

  static StepActions? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<StepActions>();

  @override
  bool updateShouldNotify(StepActions oldWidget) =>
      onOpenLink != oldWidget.onOpenLink || onChoose != oldWidget.onChoose;
}
