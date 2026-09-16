import 'package:flutter/material.dart';

/// A content slot a step can carry. Title is always present, so it isn't listed.
enum CardSlot { image, video, pdf, text, link }

/// A card template: a named combination of slots the author swipes between on
/// the Edit Step screen. It decides which fields are shown (and previewed);
/// content the template doesn't show is preserved, never deleted.
class CardTemplate {
  final String id;
  final String label;
  final IconData icon;
  final Set<CardSlot> slots;
  const CardTemplate(this.id, this.label, this.icon, this.slots);

  bool has(CardSlot s) => slots.contains(s);
}

const List<CardTemplate> kTemplates = [
  CardTemplate('image_text', 'Image + Text', Icons.image_outlined,
      {CardSlot.image, CardSlot.text}),
  CardTemplate('video_text', 'Video + Text', Icons.videocam_outlined,
      {CardSlot.video, CardSlot.text}),
  CardTemplate('image_pdf', 'Image + PDF', Icons.picture_as_pdf_outlined,
      {CardSlot.image, CardSlot.pdf}),
  CardTemplate('text_only', 'Text only', Icons.notes_outlined,
      {CardSlot.text}),
];

CardTemplate get defaultTemplate => kTemplates.first;

CardTemplate templateById(String? id) {
  for (final t in kTemplates) {
    if (t.id == id) return t;
  }
  return defaultTemplate;
}

/// Best-guess template for existing content, so opening a step lands on a
/// template that shows what's already there.
CardTemplate inferTemplate({
  required bool hasImage,
  required bool hasVideo,
  required bool hasPdf,
  required bool hasText,
}) {
  if (hasVideo) return templateById('video_text');
  if (hasImage && hasPdf) return templateById('image_pdf');
  if (hasImage) return templateById('image_text');
  if (hasText && !hasImage && !hasPdf) return templateById('text_only');
  return defaultTemplate;
}
