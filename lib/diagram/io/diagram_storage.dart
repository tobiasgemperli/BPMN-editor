import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../model/diagram_model.dart';
import '../render/diagram_rasterizer.dart';
import 'api_client.dart';
import 'bpmn_parser.dart';
import 'bpmn_serializer.dart';

/// Sync status for a diagram.
enum SyncStatus { synced, syncing, failed }

/// Metadata for a saved diagram.
class SavedDiagramMeta {
  final String id;
  String title;
  final DateTime createdAt;
  DateTime updatedAt;
  /// Server-side model ID, null for local-only diagrams.
  String? remoteId;

  SavedDiagramMeta({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    this.remoteId,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        if (remoteId != null) 'remoteId': remoteId,
      };

  factory SavedDiagramMeta.fromJson(Map<String, dynamic> json) =>
      SavedDiagramMeta(
        id: json['id'] as String,
        title: json['title'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
        remoteId: json['remoteId'] as String?,
      );
}

/// Persists diagrams locally and syncs with the Guide API.
class DiagramStorage {
  static DiagramStorage? _instance;
  static DiagramStorage get instance => _instance ??= DiagramStorage._();
  DiagramStorage._();

  final _api = ApiClient.instance;

  Directory? _dir;
  List<SavedDiagramMeta>? _index;

  /// Per-diagram sync status, keyed by local diagram ID.
  final Map<String, SyncStatus> _syncStatus = {};

  /// Notifier that fires whenever any sync status changes.
  final syncStatusNotifier = ChangeNotifier();

  /// Get the current sync status for a diagram.
  SyncStatus getSyncStatus(String id) => _syncStatus[id] ?? SyncStatus.synced;

  void _setSyncStatus(String id, SyncStatus status) {
    _syncStatus[id] = status;
    // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
    syncStatusNotifier.notifyListeners();
  }

  Future<Directory> _getDir() async {
    if (_dir != null) return _dir!;
    final docs = await getApplicationDocumentsDirectory();
    _dir = Directory('${docs.path}/diagrams');
    if (!await _dir!.exists()) {
      await _dir!.create(recursive: true);
    }
    return _dir!;
  }

  File _indexFile(Directory dir) => File('${dir.path}/_index.json');
  File _diagramFile(Directory dir, String id) => File('${dir.path}/$id.bpmn');

  Future<List<SavedDiagramMeta>> list() async {
    if (_index != null) return _index!;
    final dir = await _getDir();
    final file = _indexFile(dir);
    if (!await file.exists()) {
      _index = [];
      return _index!;
    }
    final json = jsonDecode(await file.readAsString()) as List;
    _index = json
        .map((e) => SavedDiagramMeta.fromJson(e as Map<String, dynamic>))
        .toList();
    // Most recently updated first.
    _index!.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return _index!;
  }

  Future<void> _saveIndex() async {
    final dir = await _getDir();
    final file = _indexFile(dir);
    await file.writeAsString(jsonEncode(_index!.map((e) => e.toJson()).toList()));
  }

  /// Save a diagram locally and sync to the server.
  /// If [id] is provided, overwrites that entry.
  Future<SavedDiagramMeta> save(
    DiagramModel diagram, {
    required String title,
    String? id,
  }) async {
    final dir = await _getDir();
    final index = await list();

    final now = DateTime.now();
    SavedDiagramMeta meta;

    if (id != null) {
      // Update existing.
      meta = index.firstWhere((e) => e.id == id);
      meta.title = title;
      meta.updatedAt = now;
    } else {
      // Create new.
      meta = SavedDiagramMeta(
        id: 'diagram_${now.millisecondsSinceEpoch}',
        title: title,
        createdAt: now,
        updatedAt: now,
      );
      index.insert(0, meta);
    }

    // Save locally.
    final xml = BpmnSerializer().serialize(diagram);
    await _diagramFile(dir, meta.id).writeAsString(xml);
    await _saveIndex();

    // Sync to server in the background.
    unawaited(_syncToServer(meta, diagram));

    return meta;
  }

  /// Push a diagram to the server. Fire-and-forget — failures are logged.
  Future<void> _syncToServer(SavedDiagramMeta meta, DiagramModel diagram) async {
    _setSyncStatus(meta.id, SyncStatus.syncing);
    try {
      if (meta.remoteId != null) {
        await _api.updateModel(
          meta.remoteId!,
          name: meta.title,
          diagram: diagram,
        );
      } else {
        final remote = await _api.saveModel(
          name: meta.title,
          diagram: diagram,
        );
        meta.remoteId = remote.id;
        await _saveIndex();
      }
      _setSyncStatus(meta.id, SyncStatus.synced);
      // Refresh the stored thumbnail so cards don't have to re-render the
      // diagram. Best-effort: a thumbnail failure must not fail the save.
      await _syncThumbnail(meta.remoteId!, diagram);
    } catch (e) {
      debugPrint('DiagramStorage: server sync failed: $e');
      _setSyncStatus(meta.id, SyncStatus.failed);
    }
  }

  /// Rasterize [diagram], upload it, and set it as the model's thumbnail.
  /// Swallows all errors — this is a non-critical enhancement to the save.
  Future<void> _syncThumbnail(String remoteId, DiagramModel diagram) async {
    try {
      // Never overwrite a user-set custom thumbnail with an auto-render.
      if (await isCustomThumbnail(remoteId)) return;
      final png = await rasterizeDiagramPng(diagram);
      if (png == null) return;
      final fileId = await _api.uploadFile(png);
      await _api.updateModel(remoteId, thumbnailFileId: fileId);
    } catch (e) {
      debugPrint('DiagramStorage: thumbnail sync failed: $e');
    }
  }

  // ── Custom thumbnails ──────────────────────────────────────────
  // Remote model ids whose thumbnail was set by the user (a custom image),
  // persisted so auto-generation on save never overwrites them.
  Set<String>? _customThumbs;

  File _customThumbsFile(Directory dir) =>
      File('${dir.path}/_custom_thumbs.json');

  Future<Set<String>> _loadCustomThumbs() async {
    if (_customThumbs != null) return _customThumbs!;
    try {
      final file = _customThumbsFile(await _getDir());
      if (await file.exists()) {
        final list = jsonDecode(await file.readAsString()) as List;
        return _customThumbs = list.map((e) => e.toString()).toSet();
      }
    } catch (_) {
      // Corrupt/missing file — start fresh.
    }
    return _customThumbs = <String>{};
  }

  /// Whether [remoteId]'s thumbnail was set by the user (a custom image).
  Future<bool> isCustomThumbnail(String remoteId) async =>
      (await _loadCustomThumbs()).contains(remoteId);

  /// Record whether [remoteId] has a user-set custom thumbnail. When true,
  /// auto-generation on save will skip it.
  Future<void> setCustomThumbnail(String remoteId, bool custom) async {
    final set = await _loadCustomThumbs();
    final changed = custom ? set.add(remoteId) : set.remove(remoteId);
    if (changed) {
      await _customThumbsFile(await _getDir())
          .writeAsString(jsonEncode(set.toList()));
    }
  }

  /// Load a diagram by ID. Tries local first, falls back to server.
  Future<DiagramModel?> load(String id) async {
    final dir = await _getDir();
    final file = _diagramFile(dir, id);
    if (await file.exists()) {
      final xml = await file.readAsString();
      return BpmnParser().parse(xml);
    }
    // Try loading from server if the id looks like a remote ID.
    try {
      final apiModel = await _api.getModel(id);
      return apiModel.diagram;
    } catch (_) {
      return null;
    }
  }

  /// Load a diagram from the server by remote model ID.
  Future<ApiModel> loadRemote(String remoteId) async {
    return _api.getModel(remoteId);
  }

  /// Delete a diagram locally and on the server.
  Future<void> delete(String id) async {
    final dir = await _getDir();
    final index = await list();
    final meta = index.cast<SavedDiagramMeta?>().firstWhere(
        (e) => e!.id == id,
        orElse: () => null);
    final remoteId = meta?.remoteId;
    index.removeWhere((e) => e.id == id);
    final file = _diagramFile(dir, id);
    if (await file.exists()) await file.delete();
    await _saveIndex();

    // Delete on server.
    if (remoteId != null) {
      try {
        await _api.deleteModel(remoteId);
      } catch (e) {
        debugPrint('DiagramStorage: server delete failed: $e');
      }
    }
  }

  /// Fetch all models from the server (for the Discover screen).
  Future<List<ApiModelMeta>> listRemote() async {
    return _api.listModels();
  }

  /// Fetch the authenticated user's own models, with diagrams parsed inline
  /// (for the "My Flowcharts" section).
  Future<List<ApiModel>> listMyModels() async {
    return _api.listMyModels();
  }

  /// Fetch the models owned by [ownerId] (for the creator profile screen).
  Future<List<ApiModel>> listModelsByOwner(int ownerId) async {
    return _api.listModelsByOwner(ownerId);
  }

  /// Local diagram id used to cache a given server model. Deterministic so
  /// re-opening the same remote model reuses one local entry.
  String _localIdForRemote(String remoteId) => 'remote_$remoteId';

  /// Cache a server model into local storage (keyed by its remote id) so it can
  /// be opened in the owned editor and saved back to the server. Returns the
  /// local diagram id to hand to the editor.
  Future<String> importRemote(
      String remoteId, String title, DiagramModel diagram) async {
    final dir = await _getDir();
    final index = await list();
    final localId = _localIdForRemote(remoteId);
    await _diagramFile(dir, localId)
        .writeAsString(BpmnSerializer().serialize(diagram));
    final existing = index
        .cast<SavedDiagramMeta?>()
        .firstWhere((e) => e!.id == localId, orElse: () => null);
    if (existing != null) {
      existing.title = title;
      existing.updatedAt = DateTime.now();
    } else {
      index.insert(
        0,
        SavedDiagramMeta(
          id: localId,
          title: title,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          remoteId: remoteId,
        ),
      );
    }
    await _saveIndex();
    _setSyncStatus(localId, SyncStatus.synced);
    return localId;
  }

  /// Delete one of the user's own models from the server (and any local cache).
  Future<void> deleteMyModel(String remoteId) async {
    final localId = _localIdForRemote(remoteId);
    final index = await list();
    if (index.any((e) => e.id == localId)) {
      // delete() removes the local file/index entry and the server model.
      await delete(localId);
    } else {
      await _api.deleteModel(remoteId);
    }
  }
}
