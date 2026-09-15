import 'package:flutter/material.dart';
import '../../steps/model/step_block.dart';
import '../../steps/model/step_view.dart';
import '../../steps/registry/step_registry.dart';
import '../../steps/registry/packs/workout_pack.dart';
import '../skins/app_skins.dart';
import 'zoom_levels_view.dart';

/// Dev preview: renders sample steps through the skin system so the skins and
/// their miniatures can be tried live, without wiring them into the real
/// presentation yet.
class StepsPreviewScreen extends StatefulWidget {
  const StepsPreviewScreen({super.key});

  @override
  State<StepsPreviewScreen> createState() => _StepsPreviewScreenState();
}

class _StepsPreviewScreenState extends State<StepsPreviewScreen> {
  // Shared app registry so the preview shows the same real media as the
  // live presentation (not placeholders).
  final StepRegistry _registry = appStepRegistry;
  String _skin = 'classic';

  static const List<StepView> _samples = [
    StepView(
      title: 'Attach the cam locks',
      eyebrow: 'Assembly',
      progress: ProgressInfo(index: 4, total: 10),
      blocks: [
        MediaBlock(MediaKind.image, [MediaRef('assets/sample_image.jpg')]),
        TextBlock('Slide it on until both clips click.'),
      ],
    ),
    StepView(
      title: 'Barbell back squat',
      eyebrow: 'Strength',
      progress: ProgressInfo(index: 4, total: 9),
      blocks: [
        // Portrait squat clip on the backend file store (YMove, free for
        // commercial use); see exerciseClipIds in app_skins.dart.
        MediaBlock(MediaKind.video, [MediaRef('remote:f_c9LJjW')]),
        RepsBlock(sets: 3, reps: 12, rest: Duration(seconds: 60)),
        MusicBlock('Uptown Funk', bpm: 128),
      ],
    ),
    StepView(
      title: 'Do you live in this district?',
      eyebrow: 'Eligibility',
      progress: ProgressInfo(index: 9, linear: false),
      blocks: [
        TextBlock('Your answer decides the next steps.'),
        ChoiceBlock([Choice('Yes, this district', 'a'), Choice('No / not sure', 'b')]),
      ],
    ),
    StepView(
      title: 'File an objection',
      eyebrow: 'Permit',
      progress: ProgressInfo(index: 5, total: 6),
      blocks: [
        TextBlock('Within 30 days of the decision. Use the standard form.'),
        DocBlock([DocRef('remote:x', name: 'Widerspruch.pdf', pages: 3)]),
      ],
    ),
    StepView(
      title: 'Before you switch on',
      eyebrow: 'Safety',
      progress: ProgressInfo(index: 4, total: 9),
      blocks: [TextBlock('Check the cable, seat the guard, clear the work area.')],
    ),
    // ── more combinations ──
    StepView(
      title: 'Compare the three finishes',
      eyebrow: 'Gallery',
      progress: ProgressInfo(index: 2, total: 8),
      blocks: [
        TextBlock('Hold each sample to the light before deciding.'),
        MediaBlock(MediaKind.image, [
          MediaRef('assets/sample_image.jpg'),
          MediaRef('assets/sample_image_2.jpg'),
          MediaRef('assets/sample_image.jpg'),
        ]),
      ],
    ),
    StepView(
      title: 'Watch the full technique',
      eyebrow: 'Tutorial',
      progress: ProgressInfo(index: 3, total: 12),
      blocks: [
        MediaBlock(MediaKind.video, [MediaRef('assets/sample_video_1.mp4')]),
        TextBlock('Follow along, then try it once slowly yourself.'),
        LinkBlock('https://example.com/guide', 'Full written guide'),
      ],
    ),
    StepView(
      title: 'Gather the required documents',
      eyebrow: 'Application',
      progress: ProgressInfo(index: 1, total: 5),
      blocks: [
        TextBlock('Bring all three forms, completed and signed.'),
        DocBlock([
          DocRef('remote:a', name: 'Antrag.pdf', pages: 4),
          DocRef('remote:b', name: 'Nachweis.pdf', pages: 2),
          DocRef('remote:c', name: 'Vollmacht.pdf', pages: 1),
        ]),
      ],
    ),
    StepView(
      title: 'Which surface are you working on?',
      eyebrow: 'Prep',
      progress: ProgressInfo(index: 6, linear: false),
      blocks: [
        MediaBlock(MediaKind.image, [MediaRef('assets/sample_image_2.jpg')]),
        TextBlock('The primer differs by surface.'),
        ChoiceBlock([
          Choice('Bare wood', 'a'),
          Choice('Painted / sealed', 'b'),
          Choice('Metal', 'c'),
        ]),
      ],
    ),
    StepView(
      title: 'Helpful resources',
      eyebrow: 'Reference',
      progress: ProgressInfo(index: 8, total: 8),
      blocks: [
        TextBlock('Everything you may need for this step.'),
        DocBlock([DocRef('remote:d', name: 'Checklist.pdf', pages: 1)]),
        LinkBlock('https://example.com/rules', 'Official rules'),
        LinkBlock('https://example.com/faq', 'FAQ'),
      ],
    ),
    StepView(
      title: 'Warm-up set',
      eyebrow: 'Mobility',
      progress: ProgressInfo(index: 1, total: 6),
      blocks: [
        RepsBlock(sets: 2, reps: 15),
        TextBlock('Keep it light — this is just to loosen up.'),
      ],
    ),
    StepView(
      title: 'Read this before you begin',
      eyebrow: 'Overview',
      progress: ProgressInfo(index: 1, total: 10),
      blocks: [
        TextBlock('This guide walks you through the entire process from '
            'start to finish. Set aside about twenty minutes, work somewhere '
            'well lit, and keep the parts tray within reach. You can pause at '
            'any step and pick up again later.'),
      ],
    ),
  ];

  void _openZoomLevels(StepView view) => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => ZoomLevelsView(
          registry: _registry,
          skinId: _skin,
          view: view,
        ),
      );

  Widget _frame(Widget child, double radius) => Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(radius),
          boxShadow: const [
            BoxShadow(color: Colors.black12, blurRadius: 18, offset: Offset(0, 6))
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: child,
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F4),
      appBar: AppBar(
        title: const Text('Skin Preview'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'classic', label: Text('Classic')),
                ButtonSegment(value: 'immersive', label: Text('Immersive')),
              ],
              selected: {_skin},
              onSelectionChanged: (s) => setState(() => _skin = s.first),
            ),
          ),
          Expanded(
            child: PageView.builder(
              controller: PageController(viewportFraction: 0.82),
              itemCount: _samples.length,
              itemBuilder: (c, i) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: _frame(
                  Builder(
                      builder: (cc) => _registry.renderStep(cc, _skin, _samples[i])),
                  24,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
            child: Row(
              children: [
                Text('Miniatures',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                        color: Colors.grey[600])),
                const SizedBox(width: 8),
                Flexible(
                  child: Text('tap to see zoom levels',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 120,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              itemCount: _samples.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (c, i) => AspectRatio(
                aspectRatio: 3 / 4,
                child: GestureDetector(
                  key: ValueKey('mini_$i'),
                  onTap: () => _openZoomLevels(_samples[i]),
                  child: _frame(
                    Builder(
                        builder: (cc) =>
                            _registry.renderMiniature(cc, _skin, _samples[i])),
                    12,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
