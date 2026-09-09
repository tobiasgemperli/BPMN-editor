import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../diagram/edit/editor_controller.dart';
import '../../diagram/io/api_client.dart';
import '../../diagram/io/bpmn_serializer.dart';
import '../../diagram/io/diagram_storage.dart';
import '../../diagram/io/media_ref.dart';
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

class _EditorScreenState extends State<EditorScreen>
    with WidgetsBindingObserver {
  late final EditorController _controller;
  final TransformationController _transformController =
      TransformationController(Matrix4.diagonal3Values(0.55, 0.55, 1));
  final GlobalKey _canvasKey = GlobalKey();
  static const _defaultTitle = 'New Diagram';
  String? _savedId;
  late String _title;
  Timer? _autosaveTimer;
  bool _dirty = false;
  Map<String, ui.Image> _screenImages = {};
  bool _loadingImages = false;

  bool get _isOwner => widget.role == DiagramRole.owner;

  @override
  void initState() {
    super.initState();
    _savedId = widget.savedId;
    _title = widget.title ?? _defaultTitle;
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
    } else if (_isOwner) {
      // New diagram — add a start event and center the view on it.
      _controller.addNodeAtPosition(NodeType.startEvent, const Offset(200, 100));
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _centerDiagram();
      });
    }
    // Autosave: debounced 5s after any edit.
    if (_isOwner) {
      _controller.addListener(_onDiagramChanged);
      WidgetsBinding.instance.addObserver(this);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _saveIfDirty();
    }
  }

  void _onDiagramChanged() {
    _dirty = true;
    _autosaveTimer?.cancel();
    _autosaveTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) _saveIfDirty();
    });
  }

  Future<void> _saveIfDirty() async {
    if (!_dirty) return;
    await _saveDiagram();
  }

  /// Load screenshot images from node content for UI view mode.
  Future<void> _loadScreenImages() async {
    if (_loadingImages) return;
    _loadingImages = true;
    final images = <String, ui.Image>{};
    for (final node in _controller.diagram.nodes.values) {
      final content = node.content;
      if (content == null) continue;
      final path = content.imagePath;
      if (path == null) continue;
      try {
        // Resolve the image bytes from the backend (remote:), a bundled asset,
        // or a device-local file.
        Uint8List? bytes;
        if (MediaRef.isRemote(path)) {
          bytes = await ApiClient.instance.getFileBytes(MediaRef.fileId(path));
        } else if (path.startsWith('assets/')) {
          bytes = (await rootBundle.load(path)).buffer.asUint8List();
        } else {
          final file = File(path);
          if (await file.exists()) bytes = await file.readAsBytes();
        }
        if (bytes == null) continue;
        final codec = await ui.instantiateImageCodec(bytes);
        final frame = await codec.getNextFrame();
        images[node.id] = frame.image;
      } catch (_) {
        // Skip failed image loads.
      }
    }
    if (mounted) {
      setState(() {
        _screenImages = images;
        _loadingImages = false;
      });
    }
  }

  /// Open the presentation detail for a single screen (tapped in UI mode).
  void _openScreenDetail(String nodeId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PresentationScreen(
          diagram: _controller.diagram,
          role: DiagramRole.viewer,
          initialNodeId: nodeId,
        ),
      ),
    );
  }

  Future<void> _saveDiagram() async {
    final meta = await DiagramStorage.instance.save(
      _controller.diagram,
      title: _title,
      id: _savedId,
    );
    _savedId = meta.id;
    _dirty = false;
    widget.onSaved?.call();
  }

  /// Dismiss the editor. If this is a freshly created diagram that still has
  /// the default name, prompt for a name first so it isn't saved as
  /// "New Diagram".
  Future<void> _handleClose() async {
    final nav = Navigator.of(context, rootNavigator: true);
    final isFreshUnnamed = _isOwner &&
        widget.initialDiagram == null &&
        _title == _defaultTitle &&
        (_dirty || _savedId != null);
    if (isFreshUnnamed) {
      final name = await _promptSaveName();
      if (name != null && name.trim().isNotEmpty) {
        _title = name.trim();
        _dirty = true; // ensure the chosen name is persisted
      }
    }
    await _saveIfDirty();
    if (mounted) nav.pop();
  }

  /// Name prompt shown when closing an unnamed new diagram.
  Future<String?> _promptSaveName() {
    final textController = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Save Diagram'),
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
            child: const Text('Save'),
          ),
        ],
      ),
    );
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
    // Add canvas offset to convert diagram coords to widget-local coords.
    final tx = viewSize.width / 2 - (cx + 2000) * scale;
    final ty = viewSize.height / 2 - (cy + 2000) * scale;

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
    if (_isOwner) {
      _saveIfDirty();
      WidgetsBinding.instance.removeObserver(this);
    }
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
            screenImages: _controller.viewMode == ViewMode.ui
                ? _screenImages
                : null,
            onScreenTap: _openScreenDetail,
          ),
          // ── Right-side shape palette + action buttons (owner only) ──
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
                    final hasSelection =
                        _controller.selectedNodeId != null ||
                        _controller.selectedEdgeId != null;
                    final orphans = _controller.diagram.orphanedNodeIds();
                    final isOrphan = (_controller.selectedNodeId != null &&
                            orphans.contains(_controller.selectedNodeId)) ||
                        (_controller.selectedEdgeId != null &&
                            _controller.diagram.edges[_controller.selectedEdgeId] != null &&
                            (orphans.contains(_controller.diagram.edges[_controller.selectedEdgeId]!.sourceId) ||
                             orphans.contains(_controller.diagram.edges[_controller.selectedEdgeId]!.targetId)));

                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (hasSelection)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _ActionButton(
                                  icon: Icons.delete_outline,
                                  color: isOrphan ? Colors.red : const Color(0xFF1C1C1E),
                                  onPressed: isOrphan
                                      ? _controller.deleteOrphans
                                      : _controller.deleteSelected,
                                ),
                                const SizedBox(width: 6),
                                if (_controller.selectedNodeId != null)
                                  _ActionButton(
                                    icon: Icons.edit,
                                    color: const Color(0xFF1C1C1E),
                                    onPressed: () =>
                                        showPropertiesSheet(context, _controller),
                                  ),
                              ],
                            ),
                          ),
                        Container(
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
                    ),
                      ],
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
          // Close button for modal screens (no back) — top right.
          if (widget.showCloseButton && !widget.showBackButton)
            Positioned(
              top: topPad + 8,
              right: 16,
              child: CloseCircleButton(
                onPressed: _handleClose,
              ),
            ),
          // Close button (right) — dismisses the entire modal.
          if (widget.showBackButton)
            Positioned(
              top: topPad + 8,
              right: 16,
              child: CloseCircleButton(
                onPressed: _handleClose,
              ),
            ),
          if (_isOwner)
            Positioned(
              top: topPad + 12,
              left: 60,
              right: 60,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: _editTitle,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              _title,
                              style: const TextStyle(
                                  fontSize: 17, fontWeight: FontWeight.w600, color: Color(0xFF1C1C1E)),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          ListenableBuilder(
                            listenable: Listenable.merge([
                              _controller,
                              DiagramStorage.instance.syncStatusNotifier,
                            ]),
                            builder: (context, _) {
                              if (_dirty) {
                                return const Icon(Icons.cloud_outlined,
                                    size: 18, color: Color(0xFFAEAEB2));
                              }
                              if (_savedId == null) {
                                return const SizedBox.shrink();
                              }
                              final status = DiagramStorage.instance
                                  .getSyncStatus(_savedId!);
                              return _SyncIndicator(status: status);
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    _ViewModeToggle(
                      controller: _controller,
                      onModeChanged: (mode) {
                        if (mode == ViewMode.ui) {
                          _loadScreenImages();
                        }
                      },
                    ),
                  ],
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

/// Segmented control to toggle between Diagram and UI view modes.
class _ViewModeToggle extends StatelessWidget {
  final EditorController controller;
  final ValueChanged<ViewMode>? onModeChanged;

  const _ViewModeToggle({required this.controller, this.onModeChanged});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final mode = controller.viewMode;
        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF2F2F7),
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.all(2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildSegment('Diagram', ViewMode.diagram, mode),
              _buildSegment('UI', ViewMode.ui, mode),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSegment(String label, ViewMode value, ViewMode current) {
    final isActive = value == current;
    return GestureDetector(
      onTap: () {
        controller.viewMode = value;
        onModeChanged?.call(value);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
        decoration: BoxDecoration(
          color: isActive ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 3,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
            color: isActive
                ? const Color(0xFF1C1C1E)
                : const Color(0xFF8E8E93),
          ),
        ),
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

/// Small circular action button shown above the right-side toolbar.
class _ActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;

  const _ActionButton({
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Colors.grey[50],
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Icon(icon, size: 22, color: color),
        ),
      ),
    );
  }
}
