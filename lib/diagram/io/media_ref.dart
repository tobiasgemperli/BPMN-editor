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
}
