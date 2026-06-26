import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../model/diagram_model.dart';
import 'bpmn_parser.dart';
import 'bpmn_serializer.dart';

/// Metadata for a saved diagram.
class SavedDiagramMeta {
  final String id;
  String title;
  final DateTime createdAt;
  DateTime updatedAt;

  SavedDiagramMeta({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory SavedDiagramMeta.fromJson(Map<String, dynamic> json) =>
      SavedDiagramMeta(
        id: json['id'] as String,
        title: json['title'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
      );
}

/// Persists diagrams as BPMN XML files in the app documents directory.
class DiagramStorage {
  static DiagramStorage? _instance;
  static DiagramStorage get instance => _instance ??= DiagramStorage._();
  DiagramStorage._();

  Directory? _dir;
  List<SavedDiagramMeta>? _index;

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

  /// Save a diagram. If [id] is provided, overwrites that entry.
  /// Returns the saved metadata.
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

    final xml = BpmnSerializer().serialize(diagram);
    await _diagramFile(dir, meta.id).writeAsString(xml);
    await _saveIndex();
    return meta;
  }

  /// Load a diagram by ID.
  Future<DiagramModel?> load(String id) async {
    final dir = await _getDir();
    final file = _diagramFile(dir, id);
    if (!await file.exists()) return null;
    final xml = await file.readAsString();
    return BpmnParser().parse(xml);
  }

  /// Delete a diagram by ID.
  Future<void> delete(String id) async {
    final dir = await _getDir();
    final index = await list();
    index.removeWhere((e) => e.id == id);
    final file = _diagramFile(dir, id);
    if (await file.exists()) await file.delete();
    await _saveIndex();
  }
}
