import 'package:flutter/material.dart';

/// A diagram "vertical" (content pack): the kind of guide being authored. It's
/// chosen once when the diagram is created and can't be changed later, because
/// it decides which content fields the editor offers.
class VerticalOption {
  final String? id; // null = plain
  final String title;
  final String subtitle;
  final IconData icon;
  const VerticalOption(this.id, this.title, this.subtitle, this.icon);
}

const List<VerticalOption> kVerticals = [
  VerticalOption(null, 'Plain guide',
      'Steps with a title, a photo or video, and text.', Icons.description_outlined),
  VerticalOption('workout', 'Workout',
      'Exercises with sets, reps, rest and a backing track.', Icons.fitness_center),
  VerticalOption('troubleshooting', 'Troubleshooting',
      'Branching diagnostics with tappable image hotspots.', Icons.build_outlined),
];

/// Ask which kind of guide to create. Returns the chosen [VerticalOption], or
/// null if dismissed. The choice is permanent, so the sheet says so.
Future<VerticalOption?> showVerticalPicker(BuildContext context) {
  return showModalBottomSheet<VerticalOption>(
    context: context,
    backgroundColor: Colors.white,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const Text('What kind of guide?',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1C1C1E))),
            const SizedBox(height: 4),
            Text('This sets the fields you can add — and can\'t be changed later.',
                style: TextStyle(fontSize: 13, color: Colors.grey[700])),
            const SizedBox(height: 16),
            for (final v in kVerticals) ...[
              _VerticalTile(option: v, onTap: () => Navigator.pop(ctx, v)),
              const SizedBox(height: 10),
            ],
          ],
        ),
      ),
    ),
  );
}

class _VerticalTile extends StatelessWidget {
  final VerticalOption option;
  final VoidCallback onTap;
  const _VerticalTile({required this.option, required this.onTap});

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF007AFF);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF7F7F9),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE6E6EA)),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(11)),
              child: Icon(option.icon, color: accent, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(option.title,
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1C1C1E))),
                  const SizedBox(height: 2),
                  Text(option.subtitle,
                      style: const TextStyle(
                          fontSize: 13, height: 1.3, color: Color(0xFF6A6A6E))),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, color: Color(0xFFB0B0B5)),
          ],
        ),
      ),
    );
  }
}
