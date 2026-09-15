import 'package:flutter/material.dart';
import '../../steps/model/step_block.dart';
import '../../steps/model/step_view.dart';
import '../../steps/registry/step_registry.dart';
import '../../steps/registry/packs/workout_pack.dart';
import '../skins/app_skins.dart';

/// One page in the fullscreen preview: a sample step rendered through a skin.
class _Preview {
  final String skin;
  final int posInSkin; // 1-based position within this skin's set
  final int countInSkin;
  final StepView view;
  const _Preview(this.skin, this.posInSkin, this.countInSkin, this.view);
}

/// Dev preview that shows the skins edge-to-edge, the way they'll actually
/// appear in presentation — two fullscreen samples per skin. The top-right
/// button reveals the current step's miniature so card and thumbnail can be
/// judged together. Not wired into the real presentation; media is placeholder.
class FullscreenPreviewScreen extends StatefulWidget {
  const FullscreenPreviewScreen({super.key});

  @override
  State<FullscreenPreviewScreen> createState() =>
      _FullscreenPreviewScreenState();
}

class _FullscreenPreviewScreenState extends State<FullscreenPreviewScreen> {
  final StepRegistry _registry = appStepRegistry;
  final PageController _controller = PageController();
  int _index = 0;

  // Two samples per skin, each picked to flatter that skin's strengths:
  // Classic = document-style (image+text, PDF); Immersive = media-first.
  static const List<_Preview> _pages = [
    _Preview(
      'classic',
      1,
      2,
      StepView(
        title: 'Attach the cam locks',
        eyebrow: 'Assembly',
        progress: ProgressInfo(index: 4, total: 10),
        blocks: [
          MediaBlock(MediaKind.image, [MediaRef('assets/sample_image.jpg')]),
          TextBlock('Slide it on until both clips click into place.'),
        ],
      ),
    ),
    _Preview(
      'classic',
      2,
      2,
      StepView(
        title: 'File an objection',
        eyebrow: 'Permit',
        progress: ProgressInfo(index: 5, total: 6),
        blocks: [
          TextBlock('Within 30 days of the decision. Use the standard form.'),
          DocBlock([DocRef('remote:x', name: 'Widerspruch.pdf', pages: 3)]),
        ],
      ),
    ),
    _Preview(
      'immersive',
      1,
      2,
      StepView(
        title: 'Goblet squats',
        eyebrow: 'Strength',
        progress: ProgressInfo(index: 4, total: 9),
        blocks: [
          MediaBlock(MediaKind.video, [MediaRef('assets/sample_video_1.mp4')]),
          RepsBlock(sets: 3, reps: 12, rest: Duration(seconds: 60)),
          MusicBlock('Uptown Funk', bpm: 128),
        ],
      ),
    ),
    _Preview(
      'immersive',
      2,
      2,
      StepView(
        title: 'Do you live in this district?',
        eyebrow: 'Eligibility',
        progress: ProgressInfo(index: 9, linear: false),
        blocks: [
          TextBlock('Your answer decides the next steps.'),
          ChoiceBlock([
            Choice('Yes, this district', 'a'),
            Choice('No / not sure', 'b'),
          ]),
        ],
      ),
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Render one sample edge-to-edge. Immersive draws its own full-bleed dark
  /// background; Classic is a light document, so we ground it in white and let
  /// it scroll if the content is tall.
  Widget _page(BuildContext context, _Preview p) {
    final content = Builder(
      builder: (cc) => _registry.renderStep(cc, p.skin, p.view),
    );
    if (p.skin == 'immersive') return content;
    return Container(
      color: Colors.white,
      child: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(top: 44), // clear the overlay bar
          child: content,
        ),
      ),
    );
  }

  void _showMiniature() {
    final p = _pages[_index];
    showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 200,
              height: 200 * 4 / 3,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: const [
                    BoxShadow(
                        color: Colors.black45,
                        blurRadius: 30,
                        offset: Offset(0, 12)),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                padding: const EdgeInsets.all(10),
                child: Builder(
                  builder: (cc) =>
                      _registry.renderMiniature(cc, p.skin, p.view),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Miniature · ${_skinLabel(p.skin)}',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3),
            ),
          ],
        ),
      ),
    );
  }

  String _skinLabel(String id) => id == 'immersive' ? 'Immersive' : 'Classic';

  @override
  Widget build(BuildContext context) {
    final p = _pages[_index];
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _controller,
            itemCount: _pages.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (c, i) => _page(c, _pages[i]),
          ),
          // Top overlay: back · skin label · miniature. Translucent chips read
          // on both the light (Classic) and dark (Immersive) grounds.
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                children: [
                  _circleBtn(Icons.arrow_back_ios_new,
                      () => Navigator.of(context).pop()),
                  const Spacer(),
                  _pill('${_skinLabel(p.skin)} · ${p.posInSkin} / ${p.countInSkin}'),
                  const Spacer(),
                  _circleBtn(Icons.branding_watermark_outlined, _showMiniature,
                      tooltip: 'Show miniature'),
                ],
              ),
            ),
          ),
          // Bottom page dots, in a dark chip so they show on either ground.
          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.32),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var i = 0; i < _pages.length; i++)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 3),
                          child: Container(
                            width: i == _index ? 18 : 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: i == _index
                                  ? Colors.white
                                  : Colors.white54,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _circleBtn(IconData icon, VoidCallback onTap, {String? tooltip}) {
    final btn = Material(
      color: Colors.black.withValues(alpha: 0.32),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(9),
          child: Icon(icon, size: 18, color: Colors.white),
        ),
      ),
    );
    return tooltip == null ? btn : Tooltip(message: tooltip, child: btn);
  }

  Widget _pill(String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.32),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          text,
          style: const TextStyle(
              color: Colors.white,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4),
        ),
      );
}
