import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../diagram/edit/editor_controller.dart';
import '../../diagram/io/bpmn_parser.dart';
import '../../diagram/io/bpmn_serializer.dart';
import '../../diagram/model/diagram_model.dart';
import '../widgets/diagram_canvas.dart';
import '../widgets/toolbar.dart';
import '../widgets/properties_sheet.dart';

/// The main editor screen.
class EditorScreen extends StatefulWidget {
  const EditorScreen({super.key});

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  late final EditorController _controller;
  final TransformationController _transformController =
      TransformationController();

  @override
  void initState() {
    super.initState();
    _controller = EditorController();
  }

  @override
  void dispose() {
    _transformController.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('BPMN Editor'),
        actions: [
          ListenableBuilder(
            listenable: _controller,
            builder: (context, _) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.undo),
                    onPressed: _controller.canUndo ? _controller.undo : null,
                    tooltip: 'Undo',
                  ),
                  IconButton(
                    icon: const Icon(Icons.redo),
                    onPressed: _controller.canRedo ? _controller.redo : null,
                    tooltip: 'Redo',
                  ),
                  if (_controller.selectedNodeId != null ||
                      _controller.selectedEdgeId != null)
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: _controller.deleteSelected,
                      tooltip: 'Delete',
                    ),
                  if (_controller.selectedNodeId != null)
                    IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () =>
                          showPropertiesSheet(context, _controller),
                      tooltip: 'Properties',
                    ),
                  PopupMenuButton<String>(
                    onSelected: _handleMenuAction,
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'sample',
                        child: ListTile(
                          leading: Icon(Icons.file_open),
                          title: Text('Load Sample'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'export',
                        child: ListTile(
                          leading: Icon(Icons.code),
                          title: Text('View BPMN XML'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'clear',
                        child: ListTile(
                          leading: Icon(Icons.clear_all),
                          title: Text('New Diagram'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: DiagramCanvas(
              controller: _controller,
              transformationController: _transformController,
            ),
          ),
          EditorToolbar(
            controller: _controller,
            transformationController: _transformController,
          ),
        ],
      ),
    );
  }

  Future<void> _handleMenuAction(String action) async {
    switch (action) {
      case 'sample':
        await _loadSample();
        break;
      case 'export':
        _showExportedXml();
        break;
      case 'clear':
        _controller.loadDiagram(DiagramModel());
        break;
    }
  }

  Future<void> _loadSample() async {
    try {
      final content =
          await rootBundle.loadString('assets/sample.bpmn');
      final parser = BpmnParser();
      final diagram = parser.parse(content);
      _controller.loadDiagram(diagram);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sample BPMN loaded')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Load error: $e')),
        );
      }
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
