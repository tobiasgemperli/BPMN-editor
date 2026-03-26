import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../diagram/edit/editor_controller.dart';
import '../../diagram/io/bpmn_parser.dart';
import '../../diagram/io/bpmn_serializer.dart';
import '../../diagram/model/diagram_model.dart';
import '../widgets/diagram_canvas.dart';
import '../widgets/toolbar.dart';
import '../widgets/properties_sheet.dart';
import 'presentation_screen.dart';

/// The main editor screen.
class EditorScreen extends StatefulWidget {
  final DiagramModel? initialDiagram;
  final String? title;

  const EditorScreen({super.key, this.initialDiagram, this.title});

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  late final EditorController _controller;
  final TransformationController _transformController =
      TransformationController();
  final GlobalKey _canvasKey = GlobalKey();

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
        title: Text(
          widget.title ?? 'New Diagram',
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        ),
        actions: [
          PopupMenuButton<String>(
            onSelected: _handleMenuAction,
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'export',
                child: ListTile(
                  leading: Icon(Icons.code),
                  title: Text('View BPMN XML'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
      body: Stack(
        children: [
          DiagramCanvas(
            key: _canvasKey,
            controller: _controller,
            transformationController: _transformController,
          ),
          // ── Right-side shape palette (vertical) ──
          Positioned(
            right: 12,
            top: 12,
            child: EditorToolbar(
              controller: _controller,
              transformationController: _transformController,
              canvasKey: _canvasKey,
              vertical: true,
            ),
          ),
          // ── Bottom action bar ──
          Positioned(
            left: 0,
            right: 0,
            bottom: bottomPad + 12,
            child: Center(
              child: ListenableBuilder(
                listenable: _controller,
                builder: (context, _) {
                  return Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
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
                          onPressed:
                              _controller.canUndo ? _controller.undo : null,
                          tooltip: 'Undo',
                        ),
                        IconButton(
                          icon: const Icon(Icons.redo, size: 22),
                          onPressed:
                              _controller.canRedo ? _controller.redo : null,
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
        ],
      ),
    );
  }

  void _handleMenuAction(String action) {
    switch (action) {
      case 'export':
        _showExportedXml();
        break;
    }
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
