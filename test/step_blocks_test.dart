import 'package:flutter_test/flutter_test.dart';
import 'package:bpmn_editor/diagram/model/diagram_model.dart';
import 'package:bpmn_editor/steps/model/step_block.dart';
import 'package:bpmn_editor/steps/adapter/task_content_adapter.dart';

void main() {
  test('adapter maps TaskContent to ordered blocks', () {
    final content = TaskContent(
      text: 'Do this.',
      imagePaths: ['assets/a.jpg'],
      pdfPaths: ['remote:x'],
      linkUrl: 'https://example.com',
      linkLabel: 'Portal',
    );
    final blocks = blocksFromTaskContent(content);

    // Order: text → image → doc → link
    expect(blocks[0], isA<TextBlock>());
    expect(blocks[1], isA<MediaBlock>());
    expect((blocks[1] as MediaBlock).kind, MediaKind.image);
    expect(blocks[2], isA<DocBlock>());
    expect(blocks[3], isA<LinkBlock>());
    expect((blocks[3] as LinkBlock).label, 'Portal');
  });

  test('empty content yields no blocks', () {
    expect(blocksFromTaskContent(null), isEmpty);
    expect(blocksFromTaskContent(TaskContent()), isEmpty);
  });
}
