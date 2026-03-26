import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../widgets/close_circle_button.dart';
import '../widgets/process_card.dart';

/// Full-screen swipeable reference of all card variations.
class ComponentLibraryScreen extends StatefulWidget {
  const ComponentLibraryScreen({super.key});

  @override
  State<ComponentLibraryScreen> createState() => _ComponentLibraryScreenState();
}

class _ComponentLibraryScreenState extends State<ComponentLibraryScreen> {
  final _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Stack(
          children: [
            PageView.builder(
              controller: _pageController,
              scrollDirection: Axis.vertical,
              itemCount: _cards.length,
              onPageChanged: (i) => setState(() => _currentPage = i),
              itemBuilder: (context, index) => _cards[index].card,
            ),
            // Minimal top bar: back + label.
            Positioned(
              top: topPad + 8,
              left: 16,
              child: CloseCircleButton(
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Sample content ────────────────────────────────────────────

const _shortText =
    'Review the sprint backlog and confirm priorities with the team. '
    'Ensure all acceptance criteria are clearly defined.';

const _longText =
    'Begin by reviewing the current sprint backlog with the entire team. '
    'Each team member should provide a brief status update on their assigned '
    'tasks, highlighting any blockers or dependencies that need resolution.\n\n'
    'Next, examine the burndown chart to assess whether the team is on track '
    'to meet the sprint goal. If the team is behind, discuss which items can '
    'be deprioritized or moved to the next sprint.\n\n'
    'Document all decisions made during the meeting and update the project '
    'management tool accordingly. Assign action items for any follow-up tasks '
    'and set clear deadlines.\n\n'
    'Finally, confirm the date and agenda for the next sprint review with '
    'stakeholders. Make sure demo environments are prepared and test data '
    'is loaded for any live demonstrations.';

const _sampleImage = 'assets/sample_image.jpg';
const _sampleVideo = '/tmp/bpmn_sample_video.mp4';

// ── Card variations ───────────────────────────────────────────

final _cards = <({String label, Widget card, bool darkBg})>[
  (
    label: 'Title',
    darkBg: false,
    card: const ProcessCard(
      title: 'Define Sprint Goal',
    ),
  ),
  (
    label: 'Title + Text',
    darkBg: false,
    card: const ProcessCard(
      title: 'Review Backlog',
      text: _shortText,
    ),
  ),
  (
    label: 'Title + Long Text',
    darkBg: false,
    card: const ProcessCard(
      title: 'Conduct Sprint Retrospective',
      text: _longText,
    ),
  ),
  (
    label: 'Title + Image',
    darkBg: false,
    card: const ProcessCard(
      title: 'Inspect Hydraulic System',
      imagePath: _sampleImage,
      imageIsAsset: true,
    ),
  ),
  (
    label: 'Title + Text + Image',
    darkBg: false,
    card: const ProcessCard(
      title: 'Pre-Operation Safety Check',
      text: 'Walk around the machine and verify all safety guards are in place. '
          'Check fluid levels, tire pressure, and confirm no warning lights are active.',
      imagePath: _sampleImage,
      imageIsAsset: true,
    ),
  ),
  (
    label: 'Title + Long Text + Image',
    darkBg: false,
    card: const ProcessCard(
      title: 'Complete Maintenance Report',
      text: _longText,
      imagePath: _sampleImage,
      imageIsAsset: true,
    ),
  ),
  (
    label: 'Video only (TikTok)',
    darkBg: true,
    card: const ProcessCard(
      videoPath: _sampleVideo,
    ),
  ),
  (
    label: 'Title + Video',
    darkBg: true,
    card: const ProcessCard(
      title: 'Crane Operation Demo',
      videoPath: _sampleVideo,
    ),
  ),
  (
    label: 'Title + Text + Video',
    darkBg: true,
    card: const ProcessCard(
      title: 'Load Securing Procedure',
      text: 'Attach the sling at the designated lifting points. '
          'Verify the load weight does not exceed crane capacity.',
      videoPath: _sampleVideo,
    ),
  ),
  (
    label: 'Title + Text + Image + URL',
    darkBg: false,
    card: const ProcessCard(
      title: 'Equipment Registration',
      text: _shortText,
      imagePath: _sampleImage,
      imageIsAsset: true,
      linkUrl: 'https://example.com/equipment-manual',
      linkLabel: 'Equipment Manual',
    ),
  ),
  (
    label: 'Event (Start)',
    darkBg: false,
    card: const ProcessCard(
      isEvent: true,
      nodeName: 'Begin Inspection',
    ),
  ),
  (
    label: 'Event (End)',
    darkBg: false,
    card: const ProcessCard(
      isEvent: true,
      nodeName: 'Inspection Complete',
    ),
  ),
  (
    label: 'Gateway — 2 options',
    darkBg: false,
    card: const ProcessCard(
      isGateway: true,
      nodeName: 'Safety Check Passed?',
      gatewayOptions: ['Yes', 'No'],
    ),
  ),
  (
    label: 'Gateway — 3 options',
    darkBg: false,
    card: const ProcessCard(
      isGateway: true,
      nodeName: 'Damage Severity?',
      gatewayOptions: ['Minor', 'Moderate', 'Critical'],
    ),
  ),
  (
    label: 'Gateway — 5 options (modal)',
    darkBg: false,
    card: const ProcessCard(
      isGateway: true,
      nodeName: 'Assign Repair Team',
      gatewayOptions: [
        'Hydraulics',
        'Electrical',
        'Structural',
        'Engine',
        'Safety Systems',
      ],
    ),
  ),
];

