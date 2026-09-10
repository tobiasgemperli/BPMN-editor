import 'dart:io';
import 'package:path_provider/path_provider.dart';

/// Helpers for media (image/video/pdf) `src` paths stored in a node's content.
///
/// A path is one of:
/// - a bundled asset (`assets/…`)
/// - a device-local file (absolute path) — uploaded to the backend on save
/// - a backend file reference, encoded as `remote:<fileId>` — served from
///   `/files/file/<fileId>`
class MediaRef {
  static const _prefix = 'remote:';

  /// A backend file reference (`remote:<fileId>`).
  static bool isRemote(String path) => path.startsWith(_prefix);

  /// A bundled asset shipped in the app binary.
  static bool isAsset(String path) => path.startsWith('assets/');

  /// A device-local file that should be uploaded to the backend on save.
  static bool isLocalFile(String path) => !isRemote(path) && !isAsset(path);

  /// Encode a backend [fileId] as a content src reference.
  static String encode(String fileId) => '$_prefix$fileId';

  /// The backend file id from a `remote:<fileId>` reference.
  static String fileId(String path) => path.substring(_prefix.length);

  /// Resolve a device-local [path] to a file that actually exists on THIS
  /// install, or null if it can't be found.
  ///
  /// iOS regenerates the app-container UUID in the absolute path on every
  /// reinstall/update, so a path stored earlier
  /// (`…/Application/<old-uuid>/Documents/media/foo.mp4`) can be stale even
  /// though the file still lives under the *current* `Documents/media/`.
  /// When the stored path is missing, re-anchor it by basename there.
  static Future<String?> resolveLocalPath(String path) async {
    if (!isLocalFile(path)) return path;
    if (await File(path).exists()) return path;
    final dir = await getApplicationDocumentsDirectory();
    final repaired = '${dir.path}/media/${path.split('/').last}';
    if (await File(repaired).exists()) return repaired;
    return null;
  }
}
