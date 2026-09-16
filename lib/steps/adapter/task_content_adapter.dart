import '../../diagram/model/diagram_model.dart';
import '../model/step_block.dart';

/// Backward-compatible bridge: turn today's [TaskContent] into ordered
/// [StepBlock]s so existing diagrams render through the new skin system with no
/// data migration. Order follows the attachment rule: text → image → video →
/// documents → links.
List<StepBlock> blocksFromTaskContent(TaskContent? content) {
  if (content == null) return const [];
  final blocks = <StepBlock>[];

  final text = content.text;
  if (text != null && text.isNotEmpty) blocks.add(TextBlock(text));

  for (final c in content.callouts) {
    blocks.add(CalloutBlock(_severity(c.kind), c.text));
  }

  if (content.imagePaths.isNotEmpty) {
    blocks.add(MediaBlock(
        MediaKind.image, content.imagePaths.map(MediaRef.new).toList()));
  }
  if (content.videoPaths.isNotEmpty) {
    blocks.add(MediaBlock(
        MediaKind.video, content.videoPaths.map(MediaRef.new).toList()));
  }
  if (content.pdfPaths.isNotEmpty) {
    blocks.add(DocBlock(content.pdfPaths.map((p) => DocRef(p)).toList()));
  }

  final url = content.linkUrl;
  if (url != null && url.isNotEmpty) {
    blocks.add(LinkBlock(url, content.linkLabel ?? url));
  }
  for (final link in content.links) {
    blocks.add(LinkBlock(link.url, link.label));
  }

  return blocks;
}

CalloutSeverity _severity(CalloutKind k) => switch (k) {
      CalloutKind.warning => CalloutSeverity.warning,
      CalloutKind.note => CalloutSeverity.note,
      CalloutKind.tip => CalloutSeverity.tip,
    };
