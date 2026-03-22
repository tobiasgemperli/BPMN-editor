import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../diagram/model/diagram_model.dart';

/// A full-screen step in a process. No Card/shadow — clean flat design.
///
/// Not scrollable — vertical scroll is reserved for card-to-card navigation.
/// Long text and images open in scrollable modal views.
class ProcessCard extends StatelessWidget {
  final String? title;
  final String? text;
  final String? imagePath;
  final String? videoPath;
  final String? linkUrl;
  final String? linkLabel;
  final bool isEvent;
  final bool isGateway;
  final List<String> gatewayOptions;
  final ValueChanged<int>? onOptionSelected;
  final String nodeName;

  /// If true, use a bundled asset path instead of a File path for the image.
  final bool imageIsAsset;

  const ProcessCard({
    super.key,
    this.title,
    this.text,
    this.imagePath,
    this.videoPath,
    this.linkUrl,
    this.linkLabel,
    this.isEvent = false,
    this.isGateway = false,
    this.gatewayOptions = const [],
    this.gatewayTargetIds = const [],
    this.onOptionSelected,
    this.nodeName = '',
    this.imageIsAsset = false,
  });

  /// The outgoing edge target IDs, parallel to [gatewayOptions].
  final List<String> gatewayTargetIds;

  factory ProcessCard.fromNode(
    NodeModel node, {
    DiagramModel? diagram,
    ValueChanged<int>? onOptionSelected,
  }) {
    final content = node.content;
    List<String> options = [];
    List<String> targetIds = [];
    if (node.type == NodeType.exclusiveGateway && diagram != null) {
      final outgoing = diagram.outgoingEdges(node.id);
      options =
          outgoing.map((e) => e.name.isNotEmpty ? e.name : 'Option').toList();
      targetIds = outgoing.map((e) => e.targetId).toList();
    }
    return ProcessCard(
      title: content?.title,
      text: content?.text,
      imagePath: content?.imagePath,
      videoPath: content?.videoPath,
      linkUrl: content?.linkUrl,
      linkLabel: content?.linkLabel,
      isEvent: node.type == NodeType.startEvent ||
          node.type == NodeType.endEvent,
      isGateway: node.type == NodeType.exclusiveGateway,
      gatewayOptions: options,
      gatewayTargetIds: targetIds,
      onOptionSelected: onOptionSelected,
      nodeName: node.name,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isEvent) return _buildEvent(context);
    if (isGateway) return _buildGateway(context);
    // Video-only → TikTok full-screen.
    if (videoPath != null && title == null && (text == null || text!.isEmpty)) {
      return _buildVideoFull(context);
    }
    // Video + title → TikTok with title overlay.
    if (videoPath != null) {
      return _buildVideoWithTitle(context);
    }
    return _buildContent(context);
  }

  // ── Event ───────────────────────────────────────────────────

  Widget _buildEvent(BuildContext context) {
    return Center(
      child: Text(
        nodeName.isNotEmpty ? nodeName : 'Event',
        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: Colors.white54,
              fontWeight: FontWeight.w300,
            ),
      ),
    );
  }

  // ── Gateway ─────────────────────────────────────────────────

  Widget _buildGateway(BuildContext context) {
    final question = nodeName.isNotEmpty ? nodeName : 'Decision';
    final hasInline = gatewayOptions.isNotEmpty && gatewayOptions.length <= 3;
    final hasModal = gatewayOptions.length > 3;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.call_split, size: 32, color: Colors.amber[300]),
            const SizedBox(height: 20),
            Text(
              question,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
              textAlign: TextAlign.center,
            ),
            if (hasInline) ...[
              const SizedBox(height: 32),
              ...gatewayOptions.asMap().entries.map(
                    (entry) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: onOptionSelected != null
                              ? () => onOptionSelected!(entry.key)
                              : null,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Colors.white38),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Text(entry.value,
                              style: const TextStyle(fontSize: 16)),
                        ),
                      ),
                    ),
                  ),
            ],
            if (hasModal) ...[
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => _showOptionsModal(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white38),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text('Choose (${gatewayOptions.length} options)',
                      style: const TextStyle(fontSize: 16)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showOptionsModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.5,
          minChildSize: 0.3,
          maxChildSize: 0.8,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    nodeName.isNotEmpty ? nodeName : 'Choose',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: gatewayOptions.length,
                    itemBuilder: (context, index) {
                      return ListTile(
                        title: Text(gatewayOptions[index]),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          Navigator.pop(context);
                          onOptionSelected?.call(index);
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ── Video full (TikTok) ─────────────────────────────────────

  Widget _buildVideoFull(BuildContext context) {
    return GestureDetector(
      onTap: () => _showMediaModal(context, isVideo: true),
      child: Container(
        color: Colors.black,
        child: const Center(
          child:
              Icon(Icons.play_circle_outline, size: 80, color: Colors.white70),
        ),
      ),
    );
  }

  // ── Video + title (TikTok with overlay) ─────────────────────

  Widget _buildVideoWithTitle(BuildContext context) {
    final displayTitle = title ?? nodeName;
    return GestureDetector(
      onTap: () => _showMediaModal(context, isVideo: true),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Container(
            color: Colors.black,
            child: const Center(
              child: Icon(Icons.play_circle_outline,
                  size: 80, color: Colors.white70),
            ),
          ),
          // Title + text overlay at bottom.
          Positioned(
            left: 24,
            right: 24,
            bottom: 48,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (displayTitle.isNotEmpty)
                  Text(
                    displayTitle,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                if (text != null) ...[
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () => _showTextModal(context, displayTitle, text!),
                    child: Text(
                      text!,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 14,
                        height: 1.4,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Content card (title, text, image) ───────────────────────

  /// Fixed top padding so the title always starts at the same position.
  static const _titleTopPadding = 100.0;

  Widget _buildContent(BuildContext context) {
    final displayTitle = title ?? nodeName;
    final hasImage = imagePath != null;
    final hasLongText = text != null && text!.length > 200;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: _titleTopPadding),

          // Title.
          if (displayTitle.isNotEmpty)
            Text(
              displayTitle,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),

          // Text — tappable for modal if long.
          if (text != null) ...[
            const SizedBox(height: 16),
            Flexible(
              flex: hasImage ? 2 : 3,
              child: GestureDetector(
                onTap: hasLongText
                    ? () => _showTextModal(context, displayTitle, text!)
                    : null,
                child: Text(
                  text!,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        height: 1.6,
                        color: Colors.white70,
                      ),
                  overflow: TextOverflow.fade,
                ),
              ),
            ),
            if (hasLongText) ...[
              const SizedBox(height: 8),
              Text(
                'Tap to read more',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 13,
                ),
              ),
            ],
          ],

          // Image thumbnail — tall, uses remaining space.
          if (hasImage) ...[
            const SizedBox(height: 20),
            Expanded(
              flex: text != null ? 3 : 5,
              child: GestureDetector(
                onTap: () => _showMediaModal(context, isVideo: false),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    width: double.infinity,
                    child: _buildImage(imagePath!, BoxFit.cover),
                  ),
                ),
              ),
            ),
          ],

          // Link.
          if (linkUrl != null) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(Icons.link, size: 16, color: Colors.white38),
                const SizedBox(width: 6),
                Text(
                  linkLabel ?? linkUrl!,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ],

          // Bottom spacing — less when image fills the space.
          SizedBox(height: hasImage ? 24 : 80),
        ],
      ),
    );
  }

  // ── Text modal (scrollable) ─────────────────────────────────

  void _showTextModal(BuildContext context, String modalTitle, String fullText) {
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
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: ListView(
                controller: scrollController,
                children: [
                  const SizedBox(height: 20),
                  if (modalTitle.isNotEmpty)
                    Text(
                      modalTitle,
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                    ),
                  const SizedBox(height: 16),
                  Text(
                    fullText,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          height: 1.6,
                        ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ── Media modal ─────────────────────────────────────────────

  void _showMediaModal(BuildContext context, {required bool isVideo}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) {
          return Scaffold(
            backgroundColor: Colors.black,
            extendBodyBehindAppBar: true,
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              foregroundColor: Colors.white,
              elevation: 0,
              systemOverlayStyle: SystemUiOverlayStyle.light,
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            body: isVideo
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.play_circle_outline,
                            size: 96, color: Colors.white54),
                        SizedBox(height: 16),
                        Text('Video player',
                            style: TextStyle(color: Colors.white54)),
                      ],
                    ),
                  )
                : InteractiveViewer(
                    child: Center(
                      child: _buildImage(imagePath!, BoxFit.contain),
                    ),
                  ),
          );
        },
      ),
    );
  }

  // ── Image helpers ───────────────────────────────────────────

  Widget _buildImage(String path, BoxFit fit) {
    if (imageIsAsset) {
      return Image.asset(path, fit: fit,
          errorBuilder: (_, _, _) => _placeholder());
    }
    final file = File(path);
    if (file.existsSync()) {
      return Image.file(file, fit: fit,
          errorBuilder: (_, _, _) => _placeholder());
    }
    return _placeholder();
  }

  static Widget _placeholder() {
    return Container(
      color: Colors.grey[200],
      child: Center(
        child: Icon(Icons.image_outlined, size: 48, color: Colors.grey[400]),
      ),
    );
  }
}
