import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../../diagram/io/api_client.dart';
import '../../diagram/model/diagram_model.dart';
import '../../diagram/samples/sample_diagrams.dart';
import '../widgets/close_circle_button.dart';
import '../widgets/mini_process_map.dart';
import '../widgets/process_card.dart';
import 'editor_screen.dart';

/// Full-screen presentation mode — swipe vertically through process steps.
class PresentationScreen extends StatefulWidget {
  final DiagramModel diagram;
  final String? title;
  final DiagramRole role;
  final SampleCreator? creator;
  final SampleDiagramEntry? entry;

  /// Metadata for a backend model (drives the info card for real models).
  final ApiModelMeta? meta;
  final String? savedId;
  final VoidCallback? onSaved;

  const PresentationScreen({
    super.key,
    required this.diagram,
    this.title,
    this.role = DiagramRole.owner,
    this.creator,
    this.entry,
    this.meta,
    this.savedId,
    this.onSaved,
  });

  @override
  State<PresentationScreen> createState() => _PresentationScreenState();
}

class _PresentationScreenState extends State<PresentationScreen> {
  /// The path the user has taken — grows dynamically as they swipe.
  final List<NodeModel> _path = [];

  /// All diagram nodes, for the mini-map.
  late final List<NodeModel> _allNodes;

  late final PageController _pageController;
  int _currentPage = 0;
  bool _showSwipeHint = true;

  @override
  void initState() {
    super.initState();
    _allNodes = _collectAllNodes(widget.diagram);
    final start = _findStart(widget.diagram);
    if (start != null) {
      _path.add(start);
      _extendPath(start);
    }
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  /// Find the start event node.
  NodeModel? _findStart(DiagramModel diagram) {
    for (final node in diagram.nodes.values) {
      if (node.type == NodeType.startEvent) return node;
    }
    return diagram.nodes.values.firstOrNull;
  }

  /// Collect all nodes via BFS (for the mini-map).
  List<NodeModel> _collectAllNodes(DiagramModel diagram) {
    final start = _findStart(diagram);
    if (start == null) return diagram.nodes.values.toList();

    final ordered = <NodeModel>[];
    final visited = <String>{};
    final queue = <String>[start.id];

    while (queue.isNotEmpty) {
      final id = queue.removeAt(0);
      if (visited.contains(id)) continue;
      visited.add(id);
      final node = diagram.nodes[id];
      if (node == null) continue;
      ordered.add(node);
      final outgoing = diagram.outgoingEdges(id);
      outgoing.sort((a, b) => a.name.compareTo(b.name));
      for (final edge in outgoing) {
        if (!visited.contains(edge.targetId)) {
          queue.add(edge.targetId);
        }
      }
    }
    for (final node in diagram.nodes.values) {
      if (!visited.contains(node.id)) {
        ordered.add(node);
      }
    }
    return ordered;
  }

  /// If the node has exactly one outgoing edge (non-gateway), append
  /// the target so the PageView has a next page to swipe to.
  void _extendPath(NodeModel node) {
    if (node.type == NodeType.exclusiveGateway) return;
    final outgoing = widget.diagram.outgoingEdges(node.id);
    if (outgoing.length == 1) {
      final target = widget.diagram.nodes[outgoing.first.targetId];
      if (target != null) {
        _path.add(target);
      }
    }
  }

  bool _isGatewayPage(int index) {
    if (index < 0 || index >= _path.length) return false;
    return _path[index].type == NodeType.exclusiveGateway &&
        widget.diagram.outgoingEdges(_path[index].id).isNotEmpty;
  }

  /// True if the current page is the last node in the path with no
  /// outgoing edges (end event or dead end).
  bool _isLastStep(int index) {
    if (index < 0 || index >= _path.length) return false;
    return widget.diagram.outgoingEdges(_path[index].id).isEmpty;
  }

  void _jumpToGatewayTarget(NodeModel gatewayNode, int optionIndex) {
    final outgoing = widget.diagram.outgoingEdges(gatewayNode.id);
    if (optionIndex >= outgoing.length) return;
    final target = widget.diagram.nodes[outgoing[optionIndex].targetId];
    if (target == null) return;

    final gatewayIndex = _path.indexOf(gatewayNode);
    if (gatewayIndex < 0) return;

    setState(() {
      // Trim any pages after the gateway and append the chosen target.
      _path.removeRange(gatewayIndex + 1, _path.length);
      _path.add(target);
      _extendPath(target);
    });

    // Animate to the next page (the chosen target).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pageController.animateToPage(
        gatewayIndex + 1,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    });
  }

  void _openEditor(BuildContext context) {
    // Push inside the nested navigator (right-to-left).
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EditorScreen(
          initialDiagram: widget.diagram,
          title: widget.title,
          role: widget.role,
          creator: widget.creator,
          showBackButton: true,
          savedId: widget.savedId,
          onSaved: widget.onSaved,
        ),
      ),
    );
  }

  /// Dismiss the entire modal (pop the outer navigator).
  void _dismissModal(BuildContext context) {
    // The outer navigator is above the nested one.
    final outerNav = Navigator.of(context, rootNavigator: true);
    outerNav.pop();
  }

  /// True if the user is on a gateway that hasn't been resolved yet
  /// (no pages after it in the path).
  bool _isUnresolvedGateway(int index) {
    if (!_isGatewayPage(index)) return false;
    return index == _path.length - 1;
  }

  @override
  Widget build(BuildContext context) {
    if (_path.isEmpty) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('No steps in diagram'),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Back'),
              ),
            ],
          ),
        ),
      );
    }

    final topPad = MediaQuery.of(context).padding.top;
    final bottomPad = MediaQuery.of(context).padding.bottom;
    // Clamp in case _path was trimmed after _currentPage was set.
    final safePage = _currentPage.clamp(0, _path.length - 1);
    final unresolvedGateway = _isUnresolvedGateway(safePage);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Stack(
          children: [
            // The PageView — pages are the user's path through the graph.
            // Gateway pages without a chosen option are the last page,
            // so PageView naturally prevents swiping forward.
            PageView.builder(
              controller: _pageController,
              scrollDirection: Axis.vertical,
              physics: const PageScrollPhysics(),
              itemCount: _path.length,
              onPageChanged: (i) {
                setState(() {
                  _currentPage = i;
                  if (i > 0) _showSwipeHint = false;
                  // When swiping back to a gateway, trim the path after it
                  // so the user must choose again.
                  if (_isGatewayPage(i) && i < _path.length - 1) {
                    _path.removeRange(i + 1, _path.length);
                  }
                  // When arriving at a new page, extend the path so
                  // there's always a next page to swipe to.
                  if (i == _path.length - 1) {
                    _extendPath(_path[i]);
                  }
                });
              },
              itemBuilder: (context, index) {
                final node = _path[index];
                return ProcessCard.fromNode(
                  node,
                  diagram: widget.diagram,
                  onOptionSelected: (optionIndex) {
                    _jumpToGatewayTarget(node, optionIndex);
                  },
                );
              },
            ),
            // Close button top-right — dismisses the entire modal.
            Positioned(
              top: topPad + 8,
              right: 16,
              child: CloseCircleButton(
                onPressed: () => _dismissModal(context),
              ),
            ),
            // Info button top-left.
            if (widget.entry?.entryId != null || widget.meta != null)
              Positioned(
                top: topPad + 8,
                left: 16,
                child: _InfoCircleButton(
                  onPressed: () {
                    if (widget.meta != null) {
                      _showModelInfo(context, widget.meta!, widget.diagram);
                    } else {
                      _showEntryInfo(context, widget.entry!);
                    }
                  },
                ),
              ),
            // Mini process map bottom-right — tap to open full view.
            Positioned(
              bottom: bottomPad + 16,
              right: 16,
              child: GestureDetector(
                onTap: () => _openEditor(context),
                child: MiniProcessMap(
                  steps: _allNodes,
                  diagram: widget.diagram,
                  currentNodeId: _path[safePage].id,
                ),
              ),
            ),
            // Swipe hint on first card.
            if (_showSwipeHint && _path.length > 1 && !unresolvedGateway)
              Positioned(
                bottom: bottomPad + 16,
                left: 0,
                right: 0,
                child: _SwipeHintArrow(
                  onTap: () {
                    _pageController.nextPage(
                      duration: const Duration(milliseconds: 350),
                      curve: Curves.easeInOut,
                    );
                  },
                ),
              ),
            // "Choose an option" hint on unresolved gateway pages.
            if (unresolvedGateway)
              Positioned(
                bottom: bottomPad + 32,
                left: 0,
                right: 0,
                child: const _ChooseOptionHint(),
              ),
            // // Close button on last step.
            // if (_isLastStep(safePage))
            //   Positioned(
            //     bottom: bottomPad + 32,
            //     left: 0,
            //     right: 0,
            //     child: Center(
            //       child: SizedBox(
            //         width: 140,
            //         height: 48,
            //         child: ElevatedButton(
            //           onPressed: () => _dismissModal(context),
            //           style: ElevatedButton.styleFrom(
            //             backgroundColor: Colors.black,
            //             foregroundColor: Colors.white,
            //             shape: RoundedRectangleBorder(
            //               borderRadius: BorderRadius.circular(24),
            //             ),
            //           ),
            //           child: const Text('Close',
            //               style: TextStyle(fontSize: 16)),
            //         ),
            //       ),
            //     ),
            //   ),
          ],
        ),
      ),
    );
  }
}


/// Pulsating chevron hint — tappable to go to next page.
class _SwipeHintArrow extends StatefulWidget {
  final VoidCallback onTap;

  const _SwipeHintArrow({required this.onTap});

  @override
  State<_SwipeHintArrow> createState() => _SwipeHintArrowState();
}

class _SwipeHintArrowState extends State<_SwipeHintArrow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _opacity = Tween(begin: 0.2, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Opacity(
            opacity: _opacity.value,
            child: Center(
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.9),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(Icons.keyboard_arrow_down,
                    size: 24, color: Colors.black54),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Hint shown when user tries to swipe on a gateway card.
/// Arrow points up toward the option buttons.
class _ChooseOptionHint extends StatefulWidget {
  const _ChooseOptionHint();

  @override
  State<_ChooseOptionHint> createState() => _ChooseOptionHintState();
}

class _ChooseOptionHintState extends State<_ChooseOptionHint>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<double> _offset;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    _opacity = Tween(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _offset = Tween(begin: 0.0, end: -6.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _offset.value),
          child: Opacity(
            opacity: _opacity.value,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.keyboard_arrow_up,
                    size: 28, color: Colors.black54),
                const SizedBox(height: 2),
                const Text(
                  'Please choose an option',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.black54,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── Info circle button ─────────────────────────────────────────

class _InfoCircleButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _InfoCircleButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.black.withValues(alpha: 0.5),
        ),
        child: const Icon(Icons.info_outline, size: 22, color: Colors.white),
      ),
    );
  }
}

// ── Entry info sheet ───────────────────────────────────────────

void _showEntryInfo(BuildContext context, SampleDiagramEntry entry) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _EntryInfoSheet(entry: entry),
  );
}

class _EntryInfoSheet extends StatelessWidget {
  final SampleDiagramEntry entry;

  const _EntryInfoSheet({required this.entry});

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar.
          Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 6),
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Title.
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    entry.name,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1C1C1E),
                    ),
                  ),
                ),
                if (entry.userRating != null)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.star, size: 18, color: Color(0xFFFFCC00)),
                      const SizedBox(width: 4),
                      Text(
                        entry.userRating!.toStringAsFixed(1),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1C1C1E),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          // Scrollable metadata.
          Flexible(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(20, 0, 20, bottomPad + 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (entry.entryId != null)
                    _MetaRow(label: 'ID', value: entry.entryId!),
                  _MetaRow(label: 'Author', value: entry.creator.name),
                  if (entry.sources != null)
                    _MetaRow(label: 'Sources', value: entry.sources!),
                  if (entry.stepsCount != null)
                    _MetaRow(label: 'Steps', value: '${entry.stepsCount}'),
                  if (entry.createdDate != null)
                    _MetaRow(label: 'Created', value: entry.createdDate!),
                  if (entry.version != null)
                    _MetaRow(label: 'Version', value: entry.version!),
                  _MetaRow(
                    label: 'Visibility',
                    value: entry.isPublic ? 'Public' : 'Private',
                  ),
                  _MetaRow(
                    label: 'Access',
                    value: entry.isPaid ? 'Paid' : 'Free',
                  ),
                  if (entry.maturityRating != null)
                    _MetaRow(label: 'Maturity', value: entry.maturityRating!),
                  if (entry.boardRating != null)
                    _MetaRow(label: 'Board Rating', value: entry.boardRating!),
                  if (entry.languages.isNotEmpty)
                    _MetaRow(
                      label: 'Languages',
                      value: entry.languages.map((l) => l.toUpperCase()).join(', '),
                    ),
                  if (entry.categories.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _MetaSectionTitle(label: 'Categories'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: entry.categories
                          .map((c) => _MetaChip(label: c))
                          .toList(),
                    ),
                  ],
                  if (entry.references.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _MetaSectionTitle(label: 'References'),
                    const SizedBox(height: 8),
                    ...entry.references.map((r) => Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Icon(Icons.circle,
                                    size: 6, color: Colors.grey[400]),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  r,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Color(0xFF3A3A3C),
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Backend model info sheet ───────────────────────────────────

void _showModelInfo(
    BuildContext context, ApiModelMeta meta, DiagramModel diagram) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _ModelInfoSheet(meta: meta, diagram: diagram),
  );
}

class _ModelInfoSheet extends StatefulWidget {
  final ApiModelMeta meta;
  final DiagramModel diagram;

  const _ModelInfoSheet({required this.meta, required this.diagram});

  @override
  State<_ModelInfoSheet> createState() => _ModelInfoSheetState();
}

class _ModelInfoSheetState extends State<_ModelInfoSheet> {
  late ApiModelMeta _meta = widget.meta;
  bool _canEdit = false;

  @override
  void initState() {
    super.initState();
    _checkOwnership();
  }

  Future<void> _checkOwnership() async {
    try {
      final myId = await ApiClient.instance.currentUserId();
      if (mounted) setState(() => _canEdit = myId.toString() == _meta.ownerId);
    } catch (_) {}
  }

  Future<void> _edit() async {
    final updated = await showModalBottomSheet<ApiModelMeta>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _MetaEditSheet(meta: _meta),
    );
    if (updated != null && mounted) setState(() => _meta = updated);
  }

  @override
  Widget build(BuildContext context) {
    final meta = _meta;
    final diagram = widget.diagram;
    final bottomPad = MediaQuery.of(context).padding.bottom;
    final stepCount = diagram.nodes.length;
    final decisionCount = diagram.nodes.values
        .where((n) => n.type == NodeType.exclusiveGateway)
        .length;
    final d = meta.createdAt;
    final created =
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 6),
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    meta.name,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1C1C1E),
                    ),
                  ),
                ),
                if (_canEdit)
                  IconButton(
                    onPressed: _edit,
                    icon: const Icon(Icons.edit_outlined,
                        size: 22, color: Color(0xFF007AFF)),
                    tooltip: 'Edit details',
                  ),
              ],
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(20, 0, 20, bottomPad + 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _MetaRow(
                      label: 'Author',
                      value: meta.ownerName.isNotEmpty ? meta.ownerName : '—'),
                  if (meta.sources.isNotEmpty)
                    _SourcesRow(value: meta.sources.join(', ')),
                  _MetaRow(label: 'Steps', value: '$stepCount'),
                  _MetaRow(label: 'Decision points', value: '$decisionCount'),
                  _MetaRow(label: 'Created', value: created),
                  _MetaRow(label: 'Version', value: 'v${meta.version}'),
                  if (meta.description.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _MetaSectionTitle(label: 'Description'),
                    const SizedBox(height: 8),
                    Text(
                      meta.description,
                      style: TextStyle(
                          fontSize: 14, height: 1.4, color: Colors.grey[800]),
                    ),
                  ],
                  if (meta.categories.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _MetaSectionTitle(label: 'Relations'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: meta.categories
                          .map((c) => _MetaChip(label: c))
                          .toList(),
                    ),
                  ],
                  if (meta.keywords.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _MetaSectionTitle(label: 'Keywords'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: meta.keywords
                          .map((k) => _MetaChip(label: k))
                          .toList(),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Edit sheet for the model metadata fields that persist server-side
/// (Name, Description, Keywords, Sources, Categories/Relations).
class _MetaEditSheet extends StatefulWidget {
  final ApiModelMeta meta;

  const _MetaEditSheet({required this.meta});

  @override
  State<_MetaEditSheet> createState() => _MetaEditSheetState();
}

class _MetaEditSheetState extends State<_MetaEditSheet> {
  late final _name = TextEditingController(text: widget.meta.name);
  late final _description =
      TextEditingController(text: widget.meta.description);
  late final _keywords =
      TextEditingController(text: widget.meta.keywords.join(', '));
  late final _sources =
      TextEditingController(text: widget.meta.sources.join(', '));
  late final _relations =
      TextEditingController(text: widget.meta.categories.join(', '));
  bool _saving = false;

  final _picker = ImagePicker();
  // Current thumbnail file id (null = none). Starts from the model, updates
  // after a custom upload.
  late String? _thumbnailFileId =
      widget.meta.thumbnailFileId.isEmpty ? null : widget.meta.thumbnailFileId;
  // Locally-picked bytes shown as an immediate preview before/after upload.
  Uint8List? _thumbPreview;
  bool _thumbBusy = false;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _keywords.dispose();
    _sources.dispose();
    _relations.dispose();
    super.dispose();
  }

  List<String> _parseList(String s) =>
      s.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

  /// Pick a custom image from the gallery and upload it as this model's
  /// thumbnail. Shows a local preview immediately; the id is persisted on Save.
  Future<void> _pickThumbnail() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      imageQuality: 85,
    );
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    if (!mounted) return;
    setState(() {
      _thumbPreview = bytes;
      _thumbBusy = true;
    });
    try {
      final mime = picked.mimeType ??
          (picked.name.toLowerCase().endsWith('.png')
              ? 'image/png'
              : 'image/jpeg');
      final fileId = await ApiClient.instance
          .uploadFile(bytes, filename: picked.name, mime: mime);
      if (!mounted) return;
      setState(() {
        _thumbnailFileId = fileId;
        _thumbBusy = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _thumbBusy = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Thumbnail upload failed: $e')));
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final updated = await ApiClient.instance.updateModel(
        widget.meta.id,
        name: _name.text.trim(),
        description: _description.text.trim(),
        keywords: _parseList(_keywords.text),
        sources: _parseList(_sources.text),
        categories: _parseList(_relations.text),
        // '' explicitly clears a removed thumbnail; a real id sets it.
        thumbnailFileId: _thumbnailFileId ?? '',
      );
      if (mounted) Navigator.pop(context, updated);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Save failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
      child: Container(
        // Cap to the space above the keyboard so the Save/Cancel header stays
        // visible when the keyboard is open.
        constraints: BoxConstraints(
          maxHeight: (mq.size.height - mq.viewInsets.bottom) * 0.92,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 10, bottom: 6),
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
              child: Row(
                children: [
                  TextButton(
                    onPressed: _saving ? null : () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const Spacer(),
                  const Text('Edit details',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1C1C1E))),
                  const Spacer(),
                  TextButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Save',
                            style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _thumbnailSection(),
                    _field('Name', _name),
                    _field('Description', _description, maxLines: 4),
                    _field('Keywords', _keywords, hint: 'comma-separated'),
                    _field('Additional Sources', _sources,
                        hint: 'comma-separated'),
                    _field('Relations', _relations, hint: 'comma-separated'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _thumbnailSection() {
    Widget preview;
    if (_thumbPreview != null) {
      preview = Image.memory(_thumbPreview!, fit: BoxFit.cover);
    } else if (_thumbnailFileId != null) {
      preview = FutureBuilder<Uint8List?>(
        future: ApiClient.instance.getFileBytes(_thumbnailFileId!),
        builder: (context, snap) => snap.data != null
            ? Image.memory(snap.data!, fit: BoxFit.cover)
            : const ColoredBox(color: Color(0xFFF2F4F7)),
      );
    } else {
      preview = const ColoredBox(
        color: Color(0xFFF2F4F7),
        child: Icon(Icons.image_outlined, color: Colors.black26),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Thumbnail',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[600])),
          const SizedBox(height: 6),
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 96,
                  height: 72,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      preview,
                      if (_thumbBusy)
                        const ColoredBox(
                          color: Color(0x66000000),
                          child: Center(
                            child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _thumbBusy ? null : _pickThumbnail,
                      icon: const Icon(Icons.upload, size: 18),
                      label: Text(_thumbnailFileId == null
                          ? 'Upload custom image'
                          : 'Replace image'),
                    ),
                    if (_thumbnailFileId != null && !_thumbBusy)
                      TextButton(
                        onPressed: () => setState(() {
                          _thumbnailFileId = null;
                          _thumbPreview = null;
                        }),
                        child: const Text('Remove'),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Leave empty to auto-generate from the diagram on save.',
            style: TextStyle(fontSize: 11, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _field(String label, TextEditingController c,
      {int maxLines = 1, String? hint}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[600])),
          const SizedBox(height: 6),
          TextField(
            controller: c,
            maxLines: maxLines,
            decoration: InputDecoration(
              hintText: hint,
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }
}

/// "Additional Sources" row with a tooltip explaining what a source is.
class _SourcesRow extends StatelessWidget {
  final String value;

  const _SourcesRow({required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    'Additional Sources',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[500],
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Tooltip(
                  triggerMode: TooltipTriggerMode.tap,
                  showDuration: const Duration(seconds: 6),
                  message:
                      'A source is the institution or author of a larger work '
                      'this guide is based on — e.g. an author who wrote an '
                      'interpretation of an ISO standard.',
                  child: Icon(Icons.info_outline,
                      size: 14, color: Colors.grey[400]),
                ),
              ],
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF1C1C1E),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  final String label;
  final String value;

  const _MetaRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Colors.grey[500],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF1C1C1E),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaSectionTitle extends StatelessWidget {
  final String label;

  const _MetaSectionTitle({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: Colors.grey[500],
        letterSpacing: 0.8,
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final String label;

  const _MetaChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF007AFF).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: Color(0xFF007AFF),
        ),
      ),
    );
  }
}
