import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import '../../diagram/model/diagram_model.dart';
import 'close_circle_button.dart';

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
    final imgPath = content?.imagePath;
    return ProcessCard(
      title: content?.title,
      text: content?.text,
      imagePath: imgPath,
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
      imageIsAsset: imgPath != null && imgPath.startsWith('assets/'),
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
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Text(
          nodeName.isNotEmpty ? nodeName : 'Event',
          style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                fontWeight: FontWeight.w300,
                fontSize: 32,
              ),
          textAlign: TextAlign.center,
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
            Text(
              question,
              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    fontWeight: FontWeight.w300,
                    fontSize: 32,
                  ),
              textAlign: TextAlign.center,
            ),
            if (hasInline) ...[
              const SizedBox(height: 36),
              ...gatewayOptions.asMap().entries.map(
                    (entry) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _OptionCard(
                        label: entry.value,
                        onTap: onOptionSelected != null
                            ? () => onOptionSelected!(entry.key)
                            : null,
                      ),
                    ),
                  ),
            ],
            if (hasModal) ...[
              const SizedBox(height: 36),
              _OptionCard(
                label: 'Choose from ${gatewayOptions.length} options',
                onTap: () => _showOptionsModal(context),
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
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
                  child: Text(
                    nodeName.isNotEmpty ? nodeName : 'Choose',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                    textAlign: TextAlign.center,
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    itemCount: gatewayOptions.length,
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _OptionCard(
                          label: gatewayOptions[index],
                          onTap: () {
                            Navigator.pop(context);
                            onOptionSelected?.call(index);
                          },
                        ),
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
    return _AssetVideoPlayer(
      videoPath: videoPath!,
      child: const SizedBox.expand(),
    );
  }

  // ── Video + title (TikTok with overlay) ─────────────────────

  Widget _buildVideoWithTitle(BuildContext context) {
    final displayTitle = title ?? nodeName;
    return _AssetVideoPlayer(
      videoPath: videoPath!,
      child: Positioned(
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
    );
  }

  // ── Content card (title, text, image) ───────────────────────

  /// Fixed top padding so the title always starts at the same position.
  static const _titleTopPadding = 100.0;

  Widget _buildContent(BuildContext context) {
    final displayTitle = title ?? nodeName;
    final hasImage = imagePath != null;
    final hasLongText = text != null && text!.length > 200;
    final hasLink = linkUrl != null;

    // Heavy content (image, link, long text) → top-aligned, fills screen.
    if (hasImage || hasLink) {
      return _buildTopAligned(context, displayTitle, hasImage, hasLongText);
    }

    // Light content (title only, title+text) → vertically centered.
    return _buildCentered(context, displayTitle, hasLongText);
  }

  /// Vertically centered, always left-aligned.
  /// Used for title-only and title+text cards.
  Widget _buildCentered(
      BuildContext context, String displayTitle, bool hasLongText) {
    final titleOnly = text == null || text!.isEmpty;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 60),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment:
              titleOnly ? CrossAxisAlignment.center : CrossAxisAlignment.start,
          children: [
            if (displayTitle.isNotEmpty)
              Text(
                displayTitle,
                style: titleOnly
                    ? Theme.of(context).textTheme.headlineLarge?.copyWith(
                          fontWeight: FontWeight.w300,
                          fontSize: 32,
                        )
                    : Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                textAlign: titleOnly ? TextAlign.center : TextAlign.start,
                maxLines: 5,
                overflow: TextOverflow.ellipsis,
              ),
            if (text != null && text!.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text(
                text!,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      height: 1.6,
                      color: Colors.grey[700],
                    ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Top-aligned layout for cards with image, link, or heavy content.
  Widget _buildTopAligned(BuildContext context, String displayTitle,
      bool hasImage, bool hasLongText) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: _titleTopPadding),

          if (displayTitle.isNotEmpty)
            Text(
              displayTitle,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),

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
                        color: Colors.grey[700],
                      ),
                  overflow: TextOverflow.fade,
                ),
              ),
            ),
            if (hasLongText) ...[
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () => _showTextModal(context, displayTitle, text!),
                child: Text(
                  'Tap to read more',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ],

          if (hasImage) ...[
            const SizedBox(height: 20),
            Expanded(
              flex: text != null ? 3 : 5,
              child: GestureDetector(
                onTap: () => _showMediaModal(context, isVideo: false),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Stack(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: _buildImage(imagePath!, BoxFit.cover),
                      ),
                      Positioned(
                        right: 10,
                        bottom: 10,
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.fullscreen, size: 20, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],

          if (linkUrl != null) ...[
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Opening ${linkUrl!}')),
                );
              },
              child: Row(
                children: [
                  Icon(Icons.link, size: 16, color: Colors.grey[500]),
                  const SizedBox(width: 6),
                  Text(
                    linkLabel ?? linkUrl!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ],

          SizedBox(height: hasImage ? 24 : 80),
        ],
      ),
    );
  }

  // ── Text detail view (fullscreen overlay) ───────────────────

  void _showTextModal(BuildContext context, String modalTitle, String fullText) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) {
          return _TextDetailView(title: modalTitle, text: fullText);
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  // ── Image detail view (scrollable fullscreen) ──────────────

  void _showImageDetail(BuildContext context, String path, bool isAsset) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) {
          return _ImageDetailView(imagePath: path, isAsset: isAsset);
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  // ── Media modal (video) ────────────────────────────────────

  void _showMediaModal(BuildContext context, {required bool isVideo}) {
    if (!isVideo && imagePath != null) {
      _showImageDetail(context, imagePath!, imageIsAsset);
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) {
          final topPad = MediaQuery.of(context).padding.top;
          return Scaffold(
            backgroundColor: Colors.black,
            body: Stack(
              children: [
                _AssetVideoPlayer(
                  videoPath: videoPath!,
                  child: const SizedBox.expand(),
                ),
                Positioned(
                  top: topPad + 8,
                  left: 16,
                  child: CloseCircleButton(
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ],
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

/// Plays a bundled asset video in a loop, filling its parent.
class _AssetVideoPlayer extends StatefulWidget {
  final String videoPath;
  final Widget child;

  const _AssetVideoPlayer({required this.videoPath, required this.child});

  @override
  State<_AssetVideoPlayer> createState() => _AssetVideoPlayerState();
}

class _AssetVideoPlayerState extends State<_AssetVideoPlayer> {
  late VideoPlayerController _vController;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _vController = VideoPlayerController.asset(widget.videoPath)
      ..setLooping(true)
      ..setVolume(0)
      ..initialize().then((_) {
        if (mounted) {
          setState(() => _initialized = true);
          _vController.play();
        }
      });
  }

  @override
  void dispose() {
    _vController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Container(color: Colors.black),
        if (_initialized)
          SizedBox.expand(
            child: FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: _vController.value.size.width,
                height: _vController.value.size.height,
                child: VideoPlayer(_vController),
              ),
            ),
          )
        else
          const Center(
            child: CircularProgressIndicator(color: Colors.white54),
          ),
        widget.child,
      ],
    );
  }
}

/// Fullscreen text detail view with close button.
class _TextDetailView extends StatelessWidget {
  final String title;
  final String text;

  const _TextDetailView({required this.title, required this.text});

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          ListView(
            padding: EdgeInsets.fromLTRB(24, topPad + 56, 24, 40),
            children: [
              if (title.isNotEmpty)
                Text(
                  title,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              const SizedBox(height: 20),
              Text(
                text,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      height: 1.6,
                      color: Colors.grey[700],
                    ),
              ),
            ],
          ),
          Positioned(
            top: topPad + 8,
            left: 16,
            child: CloseCircleButton(
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
    );
  }
}

/// Flat option pill — dark grey bg, white text, no shadow.
class _OptionCard extends StatefulWidget {
  final String label;
  final VoidCallback? onTap;

  const _OptionCard({required this.label, this.onTap});

  @override
  State<_OptionCard> createState() => _OptionCardState();
}

class _OptionCardState extends State<_OptionCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap?.call();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedOpacity(
        opacity: _pressed ? 0.5 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.grey[300],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            widget.label,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}

/// Fullscreen scrollable image detail view with close button.
class _ImageDetailView extends StatelessWidget {
  final String imagePath;
  final bool isAsset;

  const _ImageDetailView({required this.imagePath, required this.isAsset});

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    final imageWidget = isAsset
        ? Image.asset(imagePath, fit: BoxFit.fitWidth,
            errorBuilder: (_, _, _) => const SizedBox.shrink())
        : (File(imagePath).existsSync()
            ? Image.file(File(imagePath), fit: BoxFit.fitWidth,
                errorBuilder: (_, _, _) => const SizedBox.shrink())
            : const SizedBox.shrink());

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          InteractiveViewer(
            minScale: 1.0,
            maxScale: 4.0,
            child: SingleChildScrollView(
              padding: EdgeInsets.only(top: topPad + 56, bottom: 40),
              child: SizedBox(
                width: double.infinity,
                child: imageWidget,
              ),
            ),
          ),
          Positioned(
            top: topPad + 8,
            left: 16,
            child: CloseCircleButton(
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
    );
  }
}
