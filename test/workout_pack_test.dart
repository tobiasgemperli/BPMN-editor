import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bpmn_editor/steps/model/step_block.dart';
import 'package:bpmn_editor/steps/model/step_view.dart';
import 'package:bpmn_editor/steps/registry/step_registry.dart';
import 'package:bpmn_editor/steps/registry/packs/workout_pack.dart';
import 'package:bpmn_editor/steps/render/skins/classic_skin.dart';
import 'package:bpmn_editor/steps/render/skins/immersive_skin.dart';

StepRegistry _registry() {
  final r = StepRegistry();
  installClassic(r);
  r.registerSkin(const ImmersiveSkin());
  r.install(const WorkoutPack());
  return r;
}

Widget _host(Widget child) => MaterialApp(
    home: Scaffold(body: Center(child: SizedBox(width: 240, height: 480, child: child))));

void main() {
  testWidgets('Classic renders reps + music blocks', (tester) async {
    final r = _registry();
    const view = StepView(title: 'Goblet squats', eyebrow: 'Strength', blocks: [
      RepsBlock(sets: 3, reps: 12, rest: Duration(seconds: 60)),
      MusicBlock('Uptown Funk', bpm: 128),
    ]);
    await tester.pumpWidget(
        _host(Builder(builder: (c) => r.renderStep(c, 'classic', view))));
    expect(find.text('SETS'), findsOneWidget);
    expect(find.text('REPS'), findsOneWidget);
    expect(find.text('REST'), findsOneWidget);
    expect(find.text('Uptown Funk'), findsOneWidget);
    expect(find.text('128 BPM'), findsOneWidget);
  });

  testWidgets('Immersive also shows category blocks (via renderBlock)',
      (tester) async {
    final r = _registry();
    // media hero + reps → reps rendered in the scrim
    const view = StepView(title: 'Squats', blocks: [
      MediaBlock(MediaKind.video, [MediaRef('a.mp4')]),
      RepsBlock(sets: 3, reps: 12),
    ]);
    await tester.pumpWidget(
        _host(Builder(builder: (c) => r.renderStep(c, 'immersive', view))));
    expect(find.text('SETS'), findsOneWidget);

    // reps only (no hero) → typo slide still shows reps
    const view2 = StepView(title: 'Squats', blocks: [RepsBlock(sets: 3, reps: 12)]);
    await tester.pumpWidget(
        _host(Builder(builder: (c) => r.renderStep(c, 'immersive', view2))));
    expect(find.text('SETS'), findsWidgets);
  });

  test('WorkoutPack exposes reps/music in its palette', () {
    const pack = WorkoutPack();
    expect(pack.paletteBlocks, contains(RepsBlock));
    expect(pack.paletteBlocks, contains(MusicBlock));
    expect(pack.defaultSkinId, 'classic');
  });
}
