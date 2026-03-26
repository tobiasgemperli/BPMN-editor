import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../diagram/edit/editor_controller.dart';
import '../../diagram/io/bpmn_parser.dart';
import '../../diagram/io/bpmn_serializer.dart';
import '../../diagram/model/diagram_model.dart';
import '../../diagram/samples/sample_diagrams.dart';
import '../widgets/close_circle_button.dart';
import '../widgets/diagram_canvas.dart';
import '../widgets/toolbar.dart';
import '../widgets/properties_sheet.dart';
import 'presentation_screen.dart';

/// Role determines what the user can do with the diagram.
enum DiagramRole { owner, viewer }

/// The main editor screen.
class EditorScreen extends StatefulWidget {
  final DiagramModel? initialDiagram;
  final String? title;
  final DiagramRole role;
  final SampleCreator? creator;
  final bool showCloseButton;

  const EditorScreen({
    super.key,
    this.initialDiagram,
    this.title,
    this.role = DiagramRole.owner,
    this.creator,
    this.showCloseButton = false,
  });

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  late final EditorController _controller;
  final TransformationController _transformController =
      TransformationController();
  final GlobalKey _canvasKey = GlobalKey();

  bool get _isOwner => widget.role == DiagramRole.owner;

  @override
  void initState() {
    super.initState();
    _controller = EditorController();
    if (widget.initialDiagram != null) {
      _controller.loadDiagram(widget.initialDiagram!);
    } else {
      _loadSampleOnStart();
    }
  }

  Future<void> _loadSampleOnStart() async {
    try {
      final content = await rootBundle.loadString('assets/sample.bpmn');
      final parser = BpmnParser();
      final diagram = parser.parse(content);
      _controller.loadDiagram(diagram);
    } catch (_) {
      // Silently ignore — start with empty diagram.
    }
  }

  @override
  void dispose() {
    _transformController.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.grey[50],
        surfaceTintColor: Colors.transparent,
        automaticallyImplyLeading: !widget.showCloseButton,
        leading: widget.showCloseButton
            ? Padding(
                padding: const EdgeInsets.all(8),
                child: CloseCircleButton(
                  onPressed: () => Navigator.pop(context),
                ),
              )
            : null,
        title: Text(
          widget.title ?? 'New Diagram',
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        ),
        actions: [
          if (_isOwner) ...[
            TextButton(
              onPressed: _showExportedXml,
              child: const Text('XML'),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: TextButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Diagram saved')),
                  );
                },
                style: TextButton.styleFrom(
                  backgroundColor: const Color(0xFF007AFF),
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  textStyle: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600),
                ),
                child: const Text('Save'),
              ),
            ),
          ],
        ],
      ),
      body: Stack(
        children: [
          DiagramCanvas(
            key: _canvasKey,
            controller: _controller,
            transformationController: _transformController,
            readOnly: !_isOwner,
          ),
          // ── Right-side shape palette (owner only) ──
          if (_isOwner)
            Positioned(
              right: 12,
              top: 0,
              bottom: 0,
              child: Center(
                child: EditorToolbar(
                controller: _controller,
                transformationController: _transformController,
                canvasKey: _canvasKey,
                vertical: true,
              ),
              ),
            ),
          // ── Bottom action bar (owner only) ──
          if (_isOwner)
            Positioned(
              left: 0,
              right: 0,
              bottom: bottomPad + 12,
              child: Center(
                child: ListenableBuilder(
                  listenable: _controller,
                  builder: (context, _) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.undo, size: 22),
                            onPressed: _controller.canUndo
                                ? _controller.undo
                                : null,
                            tooltip: 'Undo',
                          ),
                          IconButton(
                            icon: const Icon(Icons.redo, size: 22),
                            onPressed: _controller.canRedo
                                ? _controller.redo
                                : null,
                            tooltip: 'Redo',
                          ),
                          if (_controller.selectedNodeId != null ||
                              _controller.selectedEdgeId != null)
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 22),
                              onPressed: _controller.deleteSelected,
                              tooltip: 'Delete',
                            ),
                          if (_controller.selectedNodeId != null)
                            IconButton(
                              icon: const Icon(Icons.edit, size: 22),
                              onPressed: () =>
                                  showPropertiesSheet(context, _controller),
                              tooltip: 'Properties',
                            ),
                          IconButton(
                            icon: const Icon(Icons.play_arrow, size: 22),
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => PresentationScreen(
                                    diagram: _controller.diagram),
                              ),
                            ),
                            tooltip: 'Presentation Mode',
                          ),
                          IconButton(
                            icon: const Icon(Icons.clear_all, size: 22),
                            onPressed: () =>
                                _controller.loadDiagram(DiagramModel()),
                            tooltip: 'Clear',
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          // ── Creator bar (viewer only) ──
          if (!_isOwner && widget.creator != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _CreatorBar(
                creator: widget.creator!,
                diagramTitle: widget.title ?? 'this diagram',
              ),
            ),
        ],
      ),
    );
  }

  void _showExportedXml() {
    final serializer = BpmnSerializer();
    final xml = serializer.serialize(_controller.diagram);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.3,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('BPMN XML',
                          style: Theme.of(context).textTheme.titleMedium),
                      IconButton(
                        icon: const Icon(Icons.copy),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: xml));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('XML copied to clipboard')),
                          );
                        },
                        tooltip: 'Copy',
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: SingleChildScrollView(
                      controller: scrollController,
                      child: SelectableText(
                        xml,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

/// YouTube-style creator bar at the bottom of the viewer screen.
class _CreatorBar extends StatelessWidget {
  final SampleCreator creator;
  final String diagramTitle;

  const _CreatorBar({
    required this.creator,
    required this.diagramTitle,
  });

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, bottomPad + 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Creator avatar.
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Color(creator.colorValue),
            ),
            child: Center(
              child: Text(
                creator.initials,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Name and subtitle.
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  creator.name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  diagramTitle,
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          // Message button.
          OutlinedButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                      'Messaging ${creator.name} is not available yet'),
                ),
              );
            },
            icon: const Icon(Icons.chat_bubble_outline, size: 16),
            label: const Text('Message'),
            style: OutlinedButton.styleFrom(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              textStyle: const TextStyle(fontSize: 13),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
