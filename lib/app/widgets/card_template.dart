import 'package:flutter/material.dart';

/// A content slot a step can carry. Title is always present, so it isn't listed.
/// `workout` (reps/sets/rest + music) and `hotspot` are theme-specific.
enum CardSlot { image, video, pdf, text, link, workout, hotspot }

/// A card template: a named combination of slots the author swipes between on
/// the Edit Step screen. It decides which fields are shown (and previewed);
/// content the template doesn't show is preserved, never deleted.
///
/// [themeId] scopes a template to one theme (e.g. the reps/music template only
/// appears for Workout). Null = universal, offered by every theme.
class CardTemplate {
  final String id;
  final String label;
  final IconData icon;
  final Set<CardSlot> slots;
  final String? themeId;
  const CardTemplate(this.id, this.label, this.icon, this.slots,
      {this.themeId});

  bool has(CardSlot s) => slots.contains(s);
}

const List<CardTemplate> kTemplates = [
  // ── Universal ──
  CardTemplate('image_text', 'Image + Text', Icons.image_outlined,
      {CardSlot.image, CardSlot.text}),
  CardTemplate('video_text', 'Video + Text', Icons.videocam_outlined,
      {CardSlot.video, CardSlot.text}),
  CardTemplate('image_pdf', 'Image + PDF', Icons.picture_as_pdf_outlined,
      {CardSlot.image, CardSlot.pdf}),
  CardTemplate('image_only', 'Image only', Icons.photo_outlined,
      {CardSlot.image}),
  CardTemplate('pdf', 'PDF', Icons.description_outlined, {CardSlot.pdf}),
  CardTemplate('text_only', 'Text only', Icons.notes_outlined, {CardSlot.text}),

  // ── Workout theme ──
  CardTemplate('exercise', 'Exercise', Icons.fitness_center,
      {CardSlot.video, CardSlot.text, CardSlot.workout}, themeId: 'workout'),
  CardTemplate('exercise_photo', 'Exercise (photo)', Icons.sports_gymnastics,
      {CardSlot.image, CardSlot.text, CardSlot.workout}, themeId: 'workout'),

  // ── Troubleshooting theme ──
  CardTemplate('hotspot', 'Diagram + Hotspots', Icons.touch_app_outlined,
      {CardSlot.image, CardSlot.hotspot, CardSlot.text},
      themeId: 'troubleshooting'),
];

CardTemplate get defaultTemplate => kTemplates.first;

/// The templates available to a diagram of [themeId]: every universal template
/// plus the ones scoped to that theme.
List<CardTemplate> templatesForTheme(String? themeId) => [
      for (final t in kTemplates)
        if (t.themeId == null || t.themeId == themeId) t,
    ];

CardTemplate templateById(String? id, {String? themeId}) {
  for (final t in templatesForTheme(themeId)) {
    if (t.id == id) return t;
  }
  return templatesForTheme(themeId).first;
}

/// Best-guess template for existing content, so opening a step lands on a
/// template that shows what's already there.
CardTemplate inferTemplate({
  required String? themeId,
  required bool hasImage,
  required bool hasVideo,
  required bool hasPdf,
  required bool hasText,
  required bool hasWorkout,
  required bool hasHotspot,
}) {
  final available = templatesForTheme(themeId);
  bool avail(String id) => available.any((t) => t.id == id);
  if (hasHotspot && avail('hotspot')) return templateById('hotspot', themeId: themeId);
  if (hasWorkout && avail('exercise')) {
    return templateById(hasImage && !hasVideo ? 'exercise_photo' : 'exercise',
        themeId: themeId);
  }
  if (hasVideo) return templateById('video_text', themeId: themeId);
  if (hasImage && hasPdf) return templateById('image_pdf', themeId: themeId);
  if (hasImage) return templateById('image_text', themeId: themeId);
  if (hasPdf) return templateById('pdf', themeId: themeId);
  if (hasText && !hasImage) return templateById('text_only', themeId: themeId);
  return available.first;
}
