import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../model/diagram_model.dart';
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
    } catch (e) {
      debugPrint('DiagramStorage: server sync failed: $e');
      _setSyncStatus(meta.id, SyncStatus.failed);
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
}
