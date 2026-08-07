import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../diagram/edit/editor_controller.dart';
import '../../diagram/io/bpmn_serializer.dart';
import '../../diagram/io/diagram_storage.dart';
import '../../diagram/model/diagram_model.dart';
import '../../diagram/samples/sample_diagrams.dart';
import '../widgets/close_circle_button.dart';
import '../widgets/diagram_canvas.dart';
import '../widgets/toolbar.dart';
import '../widgets/properties_sheet.dart';
import '../widgets/chat_sheet.dart';
import 'discover_screen.dart' show showCreatorProfile;
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
  final String? savedId;
  final VoidCallback? onSaved;

  const EditorScreen({
    super.key,
    this.initialDiagram,
    this.title,
    this.role = DiagramRole.owner,
    this.creator,
    this.showCloseButton = false,
    this.showBackButton = false,
    this.savedId,
    this.onSaved,
  });

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  late final EditorController _controller;
  final TransformationController _transformController =
      TransformationController(Matrix4.diagonal3Values(0.55, 0.55, 1));
  final GlobalKey _canvasKey = GlobalKey();
  String? _savedId;
  late String _title;
  Timer? _autosaveTimer;

  bool get _isOwner => widget.role == DiagramRole.owner;

  @override
  void initState() {
    super.initState();
    _savedId = widget.savedId;
    _title = widget.title ?? 'New Diagram';
    _controller = EditorController();
    _controller.onLimitReached = (msg) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg)),
        );
      }
    };
    if (widget.initialDiagram != null) {
      _controller.loadDiagram(widget.initialDiagram!);
      // Center the diagram in the viewport after the first frame.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _centerDiagram();
      });
    }
    // Autosave: debounced 5s after any edit.
    if (_isOwner) {
      _controller.addListener(_onDiagramChanged);
    }
  }

  void _onDiagramChanged() {
    if (_savedId == null) return; // Only autosave already-saved diagrams.
    _autosaveTimer?.cancel();
    _autosaveTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) _saveDiagram(silent: true);
    });
  }

  Future<void> _saveDiagram({bool silent = false}) async {
    final meta = await DiagramStorage.instance.save(
      _controller.diagram,
      title: _title,
      id: _savedId,
    );
    _savedId = meta.id;
    widget.onSaved?.call();
    if (mounted && !silent) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Diagram saved')),
      );
    }
  }

  void _editTitle() {
    final textController = TextEditingController(text: _title);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename Diagram'),
        content: TextField(
          controller: textController,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Diagram name'),
          onSubmitted: (_) => Navigator.pop(context, textController.text),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, textController.text),
            child: const Text('OK'),
          ),
        ],
      ),
    ).then((value) {
      if (value != null && value.trim().isNotEmpty) {
        setState(() => _title = value.trim());
      }
    });
  }

  void _centerDiagram() {
    final diagram = _controller.diagram;
    if (diagram.nodes.isEmpty) return;

    final canvasBox =
        _canvasKey.currentContext?.findRenderObject() as RenderBox?;
    if (canvasBox == null) return;
    final viewSize = canvasBox.size;

    // Compute bounding box.
    double minX = double.infinity, minY = double.infinity;
    double maxX = -double.infinity, maxY = -double.infinity;
    for (final node in diagram.nodes.values) {
      if (node.rect.left < minX) minX = node.rect.left;
      if (node.rect.top < minY) minY = node.rect.top;
      if (node.rect.right > maxX) maxX = node.rect.right;
      if (node.rect.bottom > maxY) maxY = node.rect.bottom;
    }

    const padding = 120.0;
    final dw = maxX - minX + padding * 2;
    final dh = maxY - minY + padding * 2;
    final scale = (viewSize.width / dw).clamp(0.15, 1.0) <
            (viewSize.height / dh).clamp(0.15, 1.0)
        ? (viewSize.width / dw).clamp(0.15, 1.0)
        : (viewSize.height / dh).clamp(0.15, 1.0);

    final cx = (minX + maxX) / 2;
    final cy = (minY + maxY) / 2;
    final tx = viewSize.width / 2 - cx * scale;
    final ty = viewSize.height / 2 - cy * scale;

    final m = Matrix4.identity();
    m.setEntry(0, 3, tx);
    m.setEntry(1, 3, ty);
    m.setEntry(0, 0, scale);
    m.setEntry(1, 1, scale);
    _transformController.value = m;
  }


  @override
  void dispose() {
    _autosaveTimer?.cancel();
    _controller.removeListener(_onDiagramChanged);
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
      resizeToAvoidBottomInset: false,
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
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    EditorToolbar(
                      controller: _controller,
                      transformationController: _transformController,
                      canvasKey: _canvasKey,
                      vertical: true,
                    ),
                  ],
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
                            icon: Icon(Icons.undo, size: 22,
                                color: _controller.canUndo ? const Color(0xFF1C1C1E) : Colors.grey[400]),
                            onPressed: _controller.canUndo
                                ? _controller.undo
                                : null,
                            tooltip: 'Undo',
                          ),
                          IconButton(
                            icon: Icon(Icons.redo, size: 22,
                                color: _controller.canRedo ? const Color(0xFF1C1C1E) : Colors.grey[400]),
                            onPressed: _controller.canRedo
                                ? _controller.redo
                                : null,
                            tooltip: 'Redo',
                          ),
                          if (_controller.selectedNodeId != null ||
                              _controller.selectedEdgeId != null)
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 22, color: Color(0xFF1C1C1E)),
                              onPressed: _controller.deleteSelected,
                              tooltip: 'Delete',
                            ),
                          if (_controller.selectedNodeId != null)
                            IconButton(
                              icon: const Icon(Icons.edit, size: 22, color: Color(0xFF1C1C1E)),
                              onPressed: () =>
                                  showPropertiesSheet(context, _controller),
                              tooltip: 'Properties',
                            ),
                          IconButton(
                            icon: const Icon(Icons.cleaning_services, size: 22, color: Color(0xFF1C1C1E)),
                            onPressed: () {
                              _controller.autoLayout();
                              _centerDiagram();
                            },
                            tooltip: 'Clean up',
                          ),
                          IconButton(
                            icon: const Icon(Icons.auto_awesome, size: 22, color: Color(0xFF1C1C1E)),
                            onPressed: () => showChatSheet(context, _controller),
                            tooltip: 'AI Builder',
                          ),
                          IconButton(
                            icon: const Icon(Icons.play_arrow, size: 22, color: Color(0xFF1C1C1E)),
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
                            icon: const Icon(Icons.copy, size: 22, color: Color(0xFF1C1C1E)),
                            onPressed: () {
                              final xml = BpmnSerializer().serialize(_controller.diagram);
                              Clipboard.setData(ClipboardData(text: xml));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('BPMN XML copied to clipboard')),
                              );
                            },
                            tooltip: 'Copy BPMN',
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
                onPressed: () =>
                    Navigator.of(context, rootNavigator: true).pop(),
              ),
            ),
          // Close button (right) — dismisses the entire modal.
          if (widget.showBackButton)
            Positioned(
              top: topPad + 8,
              right: 16,
              child: CloseCircleButton(
                onPressed: () =>
                    Navigator.of(context, rootNavigator: true).pop(),
              ),
            ),
          if (_isOwner)
            Positioned(
              top: topPad + 12,
              left: 60,
              right: 60,
              child: Center(
                child: GestureDetector(
                  onTap: _editTitle,
                  child: Text(
                    _title,
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w600, color: Color(0xFF1C1C1E)),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ),
          if (!_isOwner)
            Positioned(
              top: topPad + 12,
              left: 60,
              right: 60,
              child: Center(
                child: Text(
                  _title,
                  style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w600, color: Color(0xFF1C1C1E)),
                  overflow: TextOverflow.ellipsis,
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
                  if (_savedId != null)
                    ListenableBuilder(
                      listenable: DiagramStorage.instance.syncStatusNotifier,
                      builder: (context, _) {
                        final status = DiagramStorage.instance
                            .getSyncStatus(_savedId!);
                        return _SyncIndicator(status: status);
                      },
                    ),
                  const SizedBox(width: 6),
                  TextButton(
                    onPressed: _saveDiagram,
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
                child: widget.creator.avatarUrl != null
                    ? ClipOval(
                        child: Image.network(
                          widget.creator.avatarUrl!,
                          width: 30,
                          height: 30,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Center(
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
                      )
                    : Center(
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
                  color: Color(0xFF1C1C1E),
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
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1C1C1E)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Small sync status indicator shown next to the Save button.
class _SyncIndicator extends StatelessWidget {
  final SyncStatus status;

  const _SyncIndicator({required this.status});

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case SyncStatus.syncing:
        return const SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Color(0xFF007AFF),
          ),
        );
      case SyncStatus.synced:
        return const Icon(Icons.cloud_done_outlined,
            size: 20, color: Color(0xFF34C759));
      case SyncStatus.failed:
        return const Tooltip(
          message: 'Sync failed — tap Save to retry',
          child: Icon(Icons.cloud_off_outlined,
              size: 20, color: Color(0xFFFF3B30)),
        );
    }
  }
}
