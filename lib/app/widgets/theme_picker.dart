import 'package:flutter/material.dart';

/// A diagram "theme": the kind of guide being authored. Chosen once when the
/// diagram is created and fixed thereafter. A theme bundles the visual style
/// ([skinId], formerly the Classic/Immersive look) and the pool of content
/// fields the editor offers.
class GuideTheme {
  final String id;
  final String title;
  final String subtitle;
  final IconData icon;

  /// The look this theme renders with (a registered skin id).
  final String skinId;

  const GuideTheme(this.id, this.title, this.subtitle, this.icon, this.skinId);
}

const List<GuideTheme> kThemes = [
  GuideTheme('course', 'Course',
      'Media-first lessons — big visuals, short text.', Icons.school_outlined,
      'immersive'),
  GuideTheme('regulation', 'Regulation',
      'Formal, document-style steps with PDFs and notes.',
      Icons.gavel_outlined, 'classic'),
  GuideTheme('workout', 'Workout',
      'Exercises with sets, reps, rest and a backing track.',
      Icons.fitness_center, 'immersive'),
  GuideTheme('troubleshooting', 'Troubleshooting',
      'Branching diagnostics with tappable image hotspots.',
      Icons.build_outlined, 'classic'),
];

GuideTheme? themeById(String? id) {
  if (id == null) return null;
  for (final t in kThemes) {
    if (t.id == id) return t;
  }
  return null;
}

/// Ask which theme to create with. Returns the chosen [GuideTheme], or null if
/// dismissed. The choice is permanent, so the sheet says so.
Future<GuideTheme?> showThemePicker(BuildContext context) {
  return showModalBottomSheet<GuideTheme>(
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
            Text('This sets the look and the fields you can add — '
                'and can\'t be changed later.',
                style: TextStyle(fontSize: 13, color: Colors.grey[700])),
            const SizedBox(height: 16),
            for (final t in kThemes) ...[
              _ThemeTile(theme: t, onTap: () => Navigator.pop(ctx, t)),
              const SizedBox(height: 10),
            ],
          ],
        ),
      ),
    ),
  );
}

class _ThemeTile extends StatelessWidget {
  final GuideTheme theme;
  final VoidCallback onTap;
  const _ThemeTile({required this.theme, required this.onTap});

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
              child: Icon(theme.icon, color: accent, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(theme.title,
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1C1C1E))),
                  const SizedBox(height: 2),
                  Text(theme.subtitle,
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
