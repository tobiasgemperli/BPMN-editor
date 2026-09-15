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
