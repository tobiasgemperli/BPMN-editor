import 'package:flutter/material.dart';
import '../widgets/process_card.dart';

/// Showcases all ProcessCard variations in a scrollable PageView.
/// Dev-only screen — not visible to end users.
class ComponentLibraryScreen extends StatefulWidget {
  const ComponentLibraryScreen({super.key});

  @override
  State<ComponentLibraryScreen> createState() => _ComponentLibraryScreenState();
}

class _ComponentLibraryScreenState extends State<ComponentLibraryScreen> {
  final PageController _controller = PageController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView.builder(
        controller: _controller,
        scrollDirection: Axis.vertical,
        itemCount: _cards.length,
        itemBuilder: (context, index) {
          final entry = _cards[index];
          return Stack(
            children: [
              entry.darkBg
                  ? Container(color: Colors.black, child: entry.card)
                  : entry.card,
              // Label at top.
              Positioned(
                top: MediaQuery.of(context).padding.top + 8,
                left: 16,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${index + 1}/${_cards.length} — ${entry.label}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ── Sample data ──────────────────────────────────────────────

const _shortText =
    'Walk around the machine and verify all safety guards are in place. '
    'Check fluid levels, tire pressure, and confirm no warning lights are active.';

const _longText =
    'Before beginning any maintenance work, ensure the machine is completely powered '
    'down and all energy sources are locked out according to LOTO procedures. Document '
    'the current readings from all pressure gauges and temperature sensors. Inspect all '
    'hydraulic lines for leaks, cracks, or bulging. Check electrical connections for '
    'signs of corrosion or overheating. Verify that all safety interlocks are functioning '
    'correctly by testing each one individually. Replace any worn seals or gaskets '
    'according to the manufacturer\'s specifications. Record all findings in the '
    'maintenance log with date, time, and technician ID.';

const _sampleImage = 'assets/sample_image.jpg';
const _sampleVideo = '/tmp/bpmn_sample_video.mp4';

// ── Card variations ───────────────────────────────────────────

final _cards = <({String label, Widget card, bool darkBg})>[
  (
    label: 'Title',
    darkBg: false,
    card: const ProcessCard(
      nodeName: 'Define Sprint Goal',
    ),
  ),
  (
    label: 'Title + Text',
    darkBg: false,
    card: const ProcessCard(
      nodeName: 'Review Backlog',
      text: _shortText,
    ),
  ),
  (
    label: 'Title + Long Text',
    darkBg: false,
    card: const ProcessCard(
      nodeName: 'Conduct Sprint Retrospective',
      text: _longText,
    ),
  ),
  (
    label: 'Title + Image',
    darkBg: false,
    card: const ProcessCard(
      nodeName: 'Inspect Hydraulic System',
      imagePaths: [_sampleImage],
      imageIsAsset: true,
    ),
  ),
  (
    label: 'Title + Text + Image',
    darkBg: false,
    card: const ProcessCard(
      nodeName: 'Pre-Operation Safety Check',
      text: 'Walk around the machine and verify all safety guards are in place. '
          'Check fluid levels, tire pressure, and confirm no warning lights are active.',
      imagePaths: [_sampleImage],
      imageIsAsset: true,
    ),
  ),
  (
    label: 'Title + Long Text + Image',
    darkBg: false,
    card: const ProcessCard(
      nodeName: 'Complete Maintenance Report',
      text: _longText,
      imagePaths: [_sampleImage],
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
      nodeName: 'Crane Operation Demo',
      videoPath: _sampleVideo,
    ),
  ),
  (
    label: 'Title + Text + Video',
    darkBg: true,
    card: const ProcessCard(
      nodeName: 'Load Securing Procedure',
      text: 'Attach the sling at the designated lifting points. '
          'Verify the load weight does not exceed crane capacity.',
      videoPath: _sampleVideo,
    ),
  ),
  (
    label: 'Title + Text + Image + URL',
    darkBg: false,
    card: const ProcessCard(
      nodeName: 'Equipment Registration',
      text: _shortText,
      imagePaths: [_sampleImage],
      imageIsAsset: true,
      linkUrl: 'https://example.com/equipment-manual',
      linkLabel: 'Equipment Manual',
    ),
  ),
  (
    label: 'Event (Start)',
    darkBg: false,
    card: const ProcessCard(
      nodeName: 'Begin Inspection',
      isEvent: true,
    ),
  ),
  (
    label: 'Gateway (2 options)',
    darkBg: false,
    card: const ProcessCard(
      nodeName: 'Hydraulic pressure OK?',
      isGateway: true,
      gatewayOptions: ['Yes — proceed', 'No — escalate'],
    ),
  ),
  (
    label: 'Gateway (5 options → modal)',
    darkBg: false,
    card: const ProcessCard(
      nodeName: 'Select repair category',
      isGateway: true,
      gatewayOptions: [
        'Electrical',
        'Hydraulic',
        'Mechanical',
        'Software',
        'Other',
      ],
    ),
  ),
];
