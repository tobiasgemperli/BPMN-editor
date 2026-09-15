import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';
import '../../diagram/io/api_client.dart';
import '../../diagram/io/media_ref.dart';

/// Real image loader for a content `src` (backend `remote:<id>`, bundled asset,
/// or local file). Used by the skin system's media block view so skins render
/// actual media, not placeholders. Mirrors ProcessCard's loading.
class StepImage extends StatelessWidget {
  final String src;
  final BoxFit fit;
  const StepImage(this.src, {super.key, this.fit = BoxFit.cover});

  @override
  Widget build(BuildContext context) {
    if (MediaRef.isRemote(src)) {
      return FutureBuilder<Uint8List?>(
        future: ApiClient.instance.getFileBytes(MediaRef.fileId(src)),
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return _loading();
          final data = snap.data;
          if (data == null) return _broken();
          return Image.memory(data, fit: fit);
        },
      );
    }
    if (MediaRef.isAsset(src)) {
      return Image.asset(src, fit: fit, errorBuilder: (_, _, _) => _broken());
    }
    return FutureBuilder<String?>(
      future: MediaRef.resolveLocalPath(src),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) return _loading();
        final path = snap.data;
        if (path == null) return _broken();
        return Image.file(File(path), fit: fit, errorBuilder: (_, _, _) => _broken());
      },
    );
  }

  Widget _loading() => Container(
        color: const Color(0xFFEDEDEF),
        child: const Center(
            child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2))),
      );

  Widget _broken() => Container(
        color: const Color(0xFFEDEDEF),
        child: Center(
            child: Icon(Icons.broken_image_outlined, size: 40, color: Colors.grey[600])),
      );
}

/// Real looping, muted video for a content `src`. Fills its parent.
class StepVideo extends StatefulWidget {
  final String src;
  const StepVideo(this.src, {super.key});
  @override
  State<StepVideo> createState() => _StepVideoState();
}

class _StepVideoState extends State<StepVideo> {
  VideoPlayerController? _c;
  bool _ready = false;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final src = widget.src;
    VideoPlayerController controller;
    if (MediaRef.isRemote(src)) {
      // AVPlayer doesn't reliably send auth headers, and the file store is
      // auth-gated — so download the (cached) bytes to a temp file and play that.
      final id = MediaRef.fileId(src);
      final bytes = await ApiClient.instance.getFileBytes(id);
      if (bytes == null) {
        if (mounted) setState(() => _error = true);
        return;
      }
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/vid_$id.mp4');
      if (!await file.exists() || await file.length() != bytes.length) {
        await file.writeAsBytes(bytes, flush: true);
      }
      controller = VideoPlayerController.file(file);
    } else if (MediaRef.isAsset(src)) {
      controller = VideoPlayerController.asset(src);
    } else {
      final local = await MediaRef.resolveLocalPath(src);
      if (local == null) {
        if (mounted) setState(() => _error = true);
        return;
      }
      controller = VideoPlayerController.file(File(local));
    }
    _c = controller
      ..setLooping(true)
      ..setVolume(0);
    try {
      await controller.initialize();
      if (!mounted) return;
      setState(() => _ready = true);
      controller.play();
    } catch (_) {
      if (mounted) setState(() => _error = true);
    }
  }

  @override
  void dispose() {
    _c?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _c;
    return Stack(
      fit: StackFit.expand,
      children: [
        Container(color: Colors.black),
        if (_ready && c != null)
          FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: c.value.size.width,
              height: c.value.size.height,
              child: VideoPlayer(c),
            ),
          )
        else if (!_error)
          const Center(
              child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white54))),
      ],
    );
  }
}
