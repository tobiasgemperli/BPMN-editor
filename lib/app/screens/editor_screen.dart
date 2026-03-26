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
import 'discover_screen.dart' show showCreatorProfile, dismissToDashboard;
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
  final bool showBackButton;

  const EditorScreen({
    super.key,
    this.initialDiagram,
    this.title,
    this.role = DiagramRole.owner,
    this.creator,
    this.showCloseButton = false,
    this.showBackButton = false,
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

    final topPad = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: Colors.grey[50],
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
          // ── Top bar ──
          // Back button (left) — goes back one screen.
          if (widget.showBackButton)
            Positioned(
              top: topPad + 8,
              left: 16,
              child: CloseCircleButton(
                onPressed: () => Navigator.pop(context),
                isBack: true,
              ),
            ),
          // Close button for modal screens (no back) — top left.
          if (widget.showCloseButton && !widget.showBackButton)
            Positioned(
              top: topPad + 8,
              left: 16,
              child: CloseCircleButton(
                onPressed: () => dismissToDashboard(context),
              ),
            ),
          // Close button (right) — pops all the way to dashboard.
          if (widget.showBackButton)
            Positioned(
              top: topPad + 8,
              right: 16,
              child: CloseCircleButton(
                onPressed: () => dismissToDashboard(context),
              ),
            ),
          Positioned(
            top: topPad + 12,
            left: 0,
            right: 0,
            child: Center(
              child: Text(
                widget.title ?? 'New Diagram',
                style: const TextStyle(
                    fontSize: 17, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          if (_isOwner)
            Positioned(
              top: topPad + 6,
              right: 16,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextButton(
                    onPressed: _showExportedXml,
                    child: const Text('XML'),
                  ),
                  const SizedBox(width: 4),
                  TextButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Diagram saved')),
                      );
                    },
                    style: TextButton.styleFrom(
                      backgroundColor: const Color(0xFF007AFF),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 6),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      textStyle: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                    child: const Text('Save'),
                  ),
                ],
              ),
            ),
          // ── Floating creator info (viewer only) ──
          if (!_isOwner && widget.creator != null)
            Positioned(
              left: 16,
              bottom: bottomPad + 16,
              child: _FloatingCreatorChip(creator: widget.creator!),
            ),
          if (!_isOwner && widget.creator != null)
            Positioned(
              right: 16,
              bottom: bottomPad + 16,
              child: _FloatingMessageButton(creator: widget.creator!),
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

/// Floating creator chip — avatar + name in a pill.
class _FloatingCreatorChip extends StatefulWidget {
  final SampleCreator creator;

  const _FloatingCreatorChip({required this.creator});

  @override
  State<_FloatingCreatorChip> createState() => _FloatingCreatorChipState();
}

class _FloatingCreatorChipState extends State<_FloatingCreatorChip> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        showCreatorProfile(context, widget.creator);
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedOpacity(
        opacity: _pressed ? 0.5 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          padding: const EdgeInsets.fromLTRB(4, 4, 14, 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(widget.creator.colorValue),
                ),
                child: Center(
                  child: Text(
                    widget.creator.initials,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                widget.creator.name,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Floating message button — chat icon in a pill.
class _FloatingMessageButton extends StatefulWidget {
  final SampleCreator creator;

  const _FloatingMessageButton({required this.creator});

  @override
  State<_FloatingMessageButton> createState() => _FloatingMessageButtonState();
}

class _FloatingMessageButtonState extends State<_FloatingMessageButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Messaging ${widget.creator.name} is not available yet'),
          ),
        );
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedOpacity(
        opacity: _pressed ? 0.5 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.chat_bubble_outline, size: 16),
              SizedBox(width: 6),
              Text(
                'Message',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
