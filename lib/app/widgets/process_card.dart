import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:open_filex/open_filex.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';
import '../../diagram/io/api_client.dart';
import '../../diagram/io/media_ref.dart';
import '../../diagram/model/diagram_model.dart';
import 'close_circle_button.dart';

void _openUrl(String url) async {
  final uri = Uri.tryParse(url);
  if (uri != null && await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

void _openFile(String path) async {
  await OpenFilex.open(path);
}

/// A full-screen step in a process. No Card/shadow — clean flat design.
///
/// Not scrollable — vertical scroll is reserved for card-to-card navigation.
/// Long text and images open in scrollable modal views.
class ProcessCard extends StatelessWidget {
  final String? text;
  final List<String> imagePaths;
  final String? videoPath;
  final List<String> pdfPaths;
  final String? linkUrl;
  final String? linkLabel;
  final bool isEvent;
  final bool isGateway;
  final List<String> gatewayOptions;
  final ValueChanged<int>? onOptionSelected;
  final String nodeName;
  final ContentDisplayMode displayMode;

  /// If true, use a bundled asset path instead of a File path for the image.
  final bool imageIsAsset;

  final List<DocLink> _links;

  const ProcessCard({
    super.key,
    this.text,
    this.imagePaths = const [],
    this.videoPath,
    this.pdfPaths = const [],
    this.linkUrl,
    this.linkLabel,
    this.isEvent = false,
    this.isGateway = false,
    this.gatewayOptions = const [],
    this.gatewayTargetIds = const [],
    this.onOptionSelected,
    this.nodeName = '',
    this.displayMode = ContentDisplayMode.mixed,
    this.imageIsAsset = false,
    List<DocLink> links = const [],
  }) : _links = links;

  /// The outgoing edge target IDs, parallel to [gatewayOptions].
  final List<String> gatewayTargetIds;

  /// Convenience: first image path.
  String? get imagePath => imagePaths.isNotEmpty ? imagePaths.first : null;

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
    final imgPaths = content?.imagePaths ?? [];
    final firstImg = imgPaths.isNotEmpty ? imgPaths.first : null;
    return ProcessCard(
      text: content?.text,
      imagePaths: imgPaths,
      videoPath: content?.videoPath,
      pdfPaths: content?.pdfPaths ?? const [],
      linkUrl: content?.linkUrl,
      linkLabel: content?.linkLabel,
      isEvent: node.type == NodeType.startEvent ||
          node.type == NodeType.endEvent,
      isGateway: node.type == NodeType.exclusiveGateway,
      gatewayOptions: options,
      gatewayTargetIds: targetIds,
      onOptionSelected: onOptionSelected,
      nodeName: node.name,
      displayMode: content?.displayMode ?? ContentDisplayMode.mixed,
      imageIsAsset: firstImg != null && firstImg.startsWith('assets/'),
      links: content?.links ?? const [],
    );
  }

  @override
  Widget build(BuildContext context) {
    // Events with content are rendered like tasks.
    if (isEvent && !_hasContent) return _buildEvent(context);
    if (isGateway) return _buildGateway(context);
    // Mixed mode always uses content layout (title, text, thumbnails, links).
    if (displayMode == ContentDisplayMode.mixed) {
      return _buildContent(context);
    }
    // Video mode → fullscreen video.
    if (displayMode == ContentDisplayMode.video && videoPath != null) {
      if (text != null && text!.isNotEmpty) {
        return _buildVideoWithTitle(context);
      }
      return _buildVideoFull(context);
    }
    // Image mode → fullscreen image.
    if (displayMode == ContentDisplayMode.image && imagePath != null) {
      return _buildImageFull(context);
    }
    return _buildContent(context);
  }

  /// Whether this event has any content to display beyond the name.
  bool get _hasContent {
    return text != null || imagePaths.isNotEmpty || videoPath != null ||
        pdfPaths.isNotEmpty || linkUrl != null || _links.isNotEmpty;
  }

  /// Whether there are link/PDF attachments to overlay.
  bool get _hasOverlayItems =>
      linkUrl != null || pdfPaths.isNotEmpty || _links.isNotEmpty;

  // ── Fullscreen image with gradient title ────────────────────

  Widget _buildImageFull(BuildContext context) {
    final displayTitle = nodeName;
    final topPad = MediaQuery.of(context).padding.top;
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return _PinchToZoomView(
      content: _buildImage(imagePath!, BoxFit.contain),
      overlays: [
        // Title at top with gradient.
        if (displayTitle.isNotEmpty)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.5),
                    Colors.transparent,
                  ],
                ),
              ),
              padding: EdgeInsets.fromLTRB(24, topPad + 12, 24, 24),
              child: Text(
                displayTitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        // Link/PDF at bottom with gradient.
        if (_hasOverlayItems)
          _BottomOverlay(
            bottomPad: bottomPad,
            linkUrl: linkUrl,
            linkLabel: linkLabel,
            pdfPaths: pdfPaths,
            links: _links,
          ),
      ],
    );
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
                color: const Color(0xFF1C1C1E),
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
                    color: const Color(0xFF1C1C1E),
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
                          color: const Color(0xFF1C1C1E),
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

  // ── Video full ──────────────────────────────────────────────

  Widget _buildVideoFull(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    final bottomPad = MediaQuery.of(context).padding.bottom;
    final displayTitle = nodeName;
    final hasBottom = _hasOverlayItems;

    return _PinchToZoomView(
      content: _AssetVideoPlayer(
        videoPath: videoPath!,
        child: Stack(
          children: [
            if (hasBottom)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withValues(alpha: 0.3),
                ),
              ),
          ],
        ),
      ),
      overlays: [
        // Title at top with gradient.
        if (displayTitle.isNotEmpty)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.6),
                    Colors.transparent,
                  ],
                ),
              ),
              padding: EdgeInsets.fromLTRB(24, topPad + 12, 24, 24),
              child: Text(
                displayTitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        // Link/PDF at bottom with gradient.
        if (hasBottom)
          _BottomOverlay(
            bottomPad: bottomPad,
            linkUrl: linkUrl,
            linkLabel: linkLabel,
            pdfPaths: pdfPaths,
            links: _links,
          ),
      ],
    );
  }

  // ── Video + text ───────────────────────────────────────────

  Widget _buildVideoWithTitle(BuildContext context) {
    final displayTitle = nodeName;
    final topPad = MediaQuery.of(context).padding.top;
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return _PinchToZoomView(
      content: _AssetVideoPlayer(
        videoPath: videoPath!,
        child: Positioned.fill(
          child: Container(
            color: Colors.black.withValues(alpha: 0.3),
          ),
        ),
      ),
      overlays: [
        // Title at top with gradient.
        if (displayTitle.isNotEmpty)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.6),
                    Colors.transparent,
                  ],
                ),
              ),
              padding: EdgeInsets.fromLTRB(24, topPad + 12, 24, 24),
              child: Text(
                displayTitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        // Text + link/PDF at bottom with gradient.
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.8),
                  Colors.transparent,
                ],
              ),
            ),
            padding: EdgeInsets.fromLTRB(24, 32, 24, bottomPad + 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (text != null)
                  GestureDetector(
                    onTap: () =>
                        _showTextModal(context, displayTitle, text!),
                    child: Text(
                      text!,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 14,
                        height: 1.4,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                if (_hasOverlayItems) ...[
                  if (text != null) const SizedBox(height: 12),
                  _OverlayAttachmentList(
                    linkUrl: linkUrl,
                    linkLabel: linkLabel,
                    pdfPaths: pdfPaths,
                    links: _links,
                    light: true,
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Content card (title, text, image) ───────────────────────

  Widget _buildContent(BuildContext context) {
    final displayTitle = nodeName;
    final hasImage = imagePaths.isNotEmpty;
    final hasVideo = videoPath != null;
    final hasLongText = text != null && text!.length > 200;
    final hasLink = linkUrl != null;
    final hasPdf = pdfPaths.isNotEmpty;

    // Heavy content (media, link, PDF) → top-aligned, fills screen.
    if (hasImage || hasVideo || hasLink || hasPdf || _links.isNotEmpty) {
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
                          color: const Color(0xFF1C1C1E),
                        )
                    : Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF1C1C1E),
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
                      color: const Color(0xFF3A3A3C),
                    ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Top-aligned layout for mixed content: title, text, media thumbnails, links.
  Widget _buildTopAligned(BuildContext context, String displayTitle,
      bool hasImage, bool hasLongText) {
    final hasVideo = videoPath != null;
    final topPad = MediaQuery.of(context).padding.top;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: topPad + 12),

          if (displayTitle.isNotEmpty)
            SizedBox(
              width: double.infinity,
              child: Text(
                displayTitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1C1C1E),
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),

          if (text != null) ...[
            const SizedBox(height: 16),
            Flexible(
              child: GestureDetector(
                onTap: hasLongText
                    ? () => _showTextModal(context, displayTitle, text!)
                    : null,
                child: Text(
                  text!,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        height: 1.6,
                        color: const Color(0xFF3A3A3C),
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
                    color: const Color(0xFF1C1C1E),
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ],

          // Push images, links, PDFs to bottom.
          const Spacer(flex: 100),

          // Image thumbnails.
          if (hasImage) ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (int i = 0; i < imagePaths.length; i++)
                  GestureDetector(
                    onTap: () => _showImageDetail(
                      context,
                      imagePaths[i],
                      imagePaths[i].startsWith('assets/'),
                    ),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 150),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: _buildImageFromPath(
                            imagePaths[i], BoxFit.scaleDown),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
          ],

          // Video thumbnails row.
          if (hasVideo) ...[
            SizedBox(
              height: 100,
              child: Row(
                children: [
                  for (int i = 0; i < (videoPath != null ? 1 : 0); i++) ...[
                    Expanded(
                      child: GestureDetector(
                        onTap: () =>
                            _showMediaModal(context, isVideo: true),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.grey[900],
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: Colors.grey[300]!, width: 1),
                          ),
                          child: const Center(
                            child: Icon(Icons.play_circle_outline,
                                size: 40, color: Colors.white70),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Link.
          if (linkUrl != null) ...[
            _DocLinkRow(
              label: linkLabel ?? linkUrl!,
              onTap: () => _openUrl(linkUrl!),
            ),
            const SizedBox(height: 8),
          ],

          // Multiple document links.
          if (_links.isNotEmpty) ...[
            for (final link in _links)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _DocLinkRow(
                  label: link.label,
                  subtitle: link.subtitle,
                  onTap: () => _openUrl(link.url),
                ),
              ),
          ],

          // PDF attachments.
          if (pdfPaths.isNotEmpty) ...[
            for (final path in pdfPaths)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _DocLinkRow(
                  icon: Icons.picture_as_pdf,
                  label: path.split('/').last,
                  onTap: () => _openFile(path),
                ),
              ),
          ],

          SizedBox(height: MediaQuery.of(context).padding.bottom + 24),
        ],
      ),
    );
  }

  // ── Text detail view (fullscreen overlay) ───────────────────

  void _showTextModal(BuildContext context, String modalTitle, String fullText) {
    Navigator.of(context).push(PageRouteBuilder(
      opaque: false,
      pageBuilder: (context, animation, secondaryAnimation) {
        final topPad = MediaQuery.of(context).padding.top;
        return FadeTransition(
          opacity: animation,
          child: Scaffold(
            backgroundColor: Colors.white,
            body: Stack(
              children: [
                ListView(
                  padding: EdgeInsets.fromLTRB(24, topPad + 56, 24, 40),
                  children: [
                    if (modalTitle.isNotEmpty)
                      Text(
                        modalTitle,
                        style: Theme.of(context)
                            .textTheme
                            .headlineMedium
                            ?.copyWith(fontWeight: FontWeight.w600, color: const Color(0xFF1C1C1E)),
                      ),
                    const SizedBox(height: 20),
                    Text(
                      fullText,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            height: 1.6,
                            color: const Color(0xFF3A3A3C),
                          ),
                    ),
                  ],
                ),
                // Close button top-right.
                Positioned(
                  top: topPad + 8,
                  right: 16,
                  child: CloseCircleButton(
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ));
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
                // Close button top-right.
                Positioned(
                  top: topPad + 8,
                  right: 16,
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

  Widget _buildImage(String path, BoxFit fit) => _buildImageFromPath(path, fit);

  Widget _buildImageFromPath(String path, BoxFit fit) {
    if (MediaRef.isRemote(path)) {
      return _RemoteImage(fileId: MediaRef.fileId(path), fit: fit);
    }
    if (path.startsWith('assets/')) {
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
        child: Icon(Icons.image_outlined, size: 48, color: Colors.grey[600]),
      ),
    );
  }
}

/// Loads an image from the backend file store (`remote:<fileId>`), cached by
/// [ApiClient]. Shows a spinner while loading and a placeholder on failure.
class _RemoteImage extends StatelessWidget {
  final String fileId;
  final BoxFit fit;

  const _RemoteImage({required this.fileId, required this.fit});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: ApiClient.instance.getFileBytes(fileId),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return Container(
            color: Colors.grey[200],
            child: const Center(
                child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2))),
          );
        }
        final data = snap.data;
        if (data == null) {
          return Container(
            color: Colors.grey[200],
            child: Center(
                child: Icon(Icons.broken_image_outlined,
                    size: 40, color: Colors.grey[600])),
          );
        }
        return Image.memory(data, fit: fit);
      },
    );
  }
}

/// Plays a video in a loop, filling its parent.
/// Supports bundled assets, local file paths, and backend `remote:<fileId>`.
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
    final path = widget.videoPath;
    if (MediaRef.isRemote(path)) {
      _vController = VideoPlayerController.networkUrl(
        Uri.parse(ApiClient.instance.mediaUrl(MediaRef.fileId(path))),
        httpHeaders: ApiClient.instance.mediaHeaders,
      );
    } else if (path.startsWith('/')) {
      _vController = VideoPlayerController.file(File(path));
    } else {
      _vController = VideoPlayerController.asset(path);
    }
    _vController
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
              fit: _vController.value.size.height > _vController.value.size.width
                  ? BoxFit.cover
                  : BoxFit.contain,
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
        Positioned.fill(child: widget.child),
      ],
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
    final Widget imageWidget = MediaRef.isRemote(imagePath)
        ? _RemoteImage(fileId: MediaRef.fileId(imagePath), fit: BoxFit.contain)
        : isAsset
            ? Image.asset(imagePath, fit: BoxFit.contain,
                errorBuilder: (_, _, _) => const SizedBox.shrink())
            : (File(imagePath).existsSync()
                ? Image.file(File(imagePath), fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => const SizedBox.shrink())
                : const SizedBox.shrink());

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          InteractiveViewer(
            minScale: 1.0,
            maxScale: 5.0,
            child: Center(
              child: imageWidget,
            ),
          ),
          // Close button top-left.
          Positioned(
            top: topPad + 8,
            right: 16,
            child: CloseCircleButton(
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
    );
  }
}

/// Pinch-to-zoom image with snap-back. Hides overlays while zoomed.
class _PinchToZoomView extends StatefulWidget {
  final Widget content;
  final List<Widget> overlays;

  const _PinchToZoomView({
    required this.content,
    this.overlays = const [],
  });

  @override
  State<_PinchToZoomView> createState() => _PinchToZoomViewState();
}

class _PinchToZoomViewState extends State<_PinchToZoomView>
    with SingleTickerProviderStateMixin {
  final _controller = TransformationController();
  late final AnimationController _animController;
  Animation<Matrix4>? _snapBackAnimation;
  bool _isZoomed = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _animController.addListener(() {
      if (_snapBackAnimation != null) {
        _controller.value = _snapBackAnimation!.value;
      }
    });
    _animController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() => _isZoomed = false);
      }
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onInteractionStart(ScaleStartDetails details) {
    if (_animController.isAnimating) {
      _animController.stop();
    }
  }

  void _onInteractionEnd(ScaleEndDetails details) {
    // Snap back to identity.
    _snapBackAnimation = Matrix4Tween(
      begin: _controller.value,
      end: Matrix4.identity(),
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    ));
    _animController.forward(from: 0);
  }

  void _onInteractionUpdate(ScaleUpdateDetails details) {
    final scale = _controller.value.getMaxScaleOnAxis();
    final zoomed = scale > 1.05;
    if (zoomed != _isZoomed) {
      setState(() => _isZoomed = zoomed);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Container(
          color: Colors.black,
          child: InteractiveViewer(
            transformationController: _controller,
            onInteractionStart: _onInteractionStart,
            onInteractionUpdate: _onInteractionUpdate,
            onInteractionEnd: _onInteractionEnd,
            minScale: 1.0,
            maxScale: 5.0,
            child: SizedBox.expand(child: widget.content),
          ),
        ),
        // Hide overlays while zoomed.
        if (!_isZoomed) ...widget.overlays,
      ],
    );
  }
}

/// Dark gradient overlay at the bottom with link/PDF attachments.
/// Used on fullscreen image cards.
class _BottomOverlay extends StatelessWidget {
  final double bottomPad;
  final String? linkUrl;
  final String? linkLabel;
  final List<String> pdfPaths;
  final List<DocLink> links;

  const _BottomOverlay({
    required this.bottomPad,
    this.linkUrl,
    this.linkLabel,
    this.pdfPaths = const [],
    this.links = const [],
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [
              Colors.black.withValues(alpha: 0.7),
              Colors.transparent,
            ],
          ),
        ),
        padding: EdgeInsets.fromLTRB(24, 32, 24, bottomPad + 16),
        child: _OverlayAttachmentList(
          linkUrl: linkUrl,
          linkLabel: linkLabel,
          pdfPaths: pdfPaths,
          links: links,
          light: true,
        ),
      ),
    );
  }
}

/// Compact list of link/PDF attachment rows for overlays.
/// When [light] is true, uses white text on dark backgrounds.
class _OverlayAttachmentList extends StatelessWidget {
  final String? linkUrl;
  final String? linkLabel;
  final List<String> pdfPaths;
  final List<DocLink> links;
  final bool light;

  const _OverlayAttachmentList({
    this.linkUrl,
    this.linkLabel,
    this.pdfPaths = const [],
    this.links = const [],
    this.light = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (linkUrl != null)
          _OverlayAttachmentRow(
            icon: Icons.link,
            label: linkLabel ?? linkUrl!,
            light: light,
            onTap: () => _openUrl(linkUrl!),
          ),
        for (final link in links)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: _OverlayAttachmentRow(
              icon: Icons.link,
              label: link.label,
              light: light,
              onTap: () => _openUrl(link.url),
            ),
          ),
        for (final path in pdfPaths)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: _OverlayAttachmentRow(
              icon: Icons.picture_as_pdf,
              label: path.split('/').last,
              light: light,
              onTap: () => _openFile(path),
            ),
          ),
      ],
    );
  }
}

/// Plain text attachment row with icon before text — no box.
class _OverlayAttachmentRow extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool light;
  final VoidCallback onTap;

  const _OverlayAttachmentRow({
    required this.icon,
    required this.label,
    required this.light,
    required this.onTap,
  });

  @override
  State<_OverlayAttachmentRow> createState() => _OverlayAttachmentRowState();
}

class _OverlayAttachmentRowState extends State<_OverlayAttachmentRow> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final textColor = widget.light ? Colors.white : const Color(0xFF1C1C1E);
    final iconColor = widget.light ? Colors.white : const Color(0xFF1C1C1E);

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedOpacity(
        opacity: _pressed ? 0.5 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon, size: 18, color: iconColor),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  widget.label,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: textColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Plain text link row — icon before label, no box.
class _DocLinkRow extends StatefulWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback onTap;

  const _DocLinkRow({
    this.icon = Icons.link,
    required this.label,
    this.subtitle,
    required this.onTap,
  });

  @override
  State<_DocLinkRow> createState() => _DocLinkRowState();
}

class _DocLinkRowState extends State<_DocLinkRow> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedOpacity(
        opacity: _pressed ? 0.5 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon, size: 18, color: const Color(0xFF1C1C1E)),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  widget.label,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF1C1C1E),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
