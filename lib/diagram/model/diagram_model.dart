import 'dart:ui';
import '../edit/hit_test.dart';

/// The types of BPMN nodes we support.
enum NodeType { startEvent, endEvent, task, exclusiveGateway }

/// Content attached to a Task node.
/// A single document link.
class DocLink {
  final String url;
  final String label;
  final String? subtitle;

  const DocLink({required this.url, required this.label, this.subtitle});
}

/// Display mode for a node in presentation.
enum ContentDisplayMode { mixed, image, video, textOnly }

/// Content attached to a node (task, start event, or end event).
class TaskContent {
  String? text;            // plain text → <bpmn:documentation>
  List<String> imagePaths; // local file paths / URLs (up to 3)
  List<String> videoPaths; // local file paths (up to 3)
  List<String> pdfPaths;   // local file paths (up to 3)
  String? linkUrl;
  String? linkLabel;
  List<DocLink> links;
  ContentDisplayMode displayMode;

  TaskContent({
    this.text,
    String? imagePath,
    List<String>? imagePaths,
    String? videoPath,
    List<String>? videoPaths,
    String? pdfPath,
    List<String>? pdfPaths,
    this.linkUrl,
    this.linkLabel,
    this.links = const [],
    this.displayMode = ContentDisplayMode.mixed,
  })  : imagePaths = imagePaths ?? (imagePath != null ? [imagePath] : []),
        videoPaths = videoPaths ?? (videoPath != null ? [videoPath] : []),
        pdfPaths = pdfPaths ?? (pdfPath != null ? [pdfPath] : []);

  /// First image path (convenience getter).
  String? get imagePath => imagePaths.isNotEmpty ? imagePaths.first : null;

  /// First video path (convenience getter).
  String? get videoPath => videoPaths.isNotEmpty ? videoPaths.first : null;

  /// First PDF path (convenience getter).
  String? get pdfPath => pdfPaths.isNotEmpty ? pdfPaths.first : null;

  bool get hasMedia =>
      imagePaths.isNotEmpty || videoPaths.isNotEmpty || pdfPaths.isNotEmpty;
  bool get isEmpty =>
      text == null && !hasMedia && linkUrl == null && links.isEmpty;

  TaskContent copy() => TaskContent(
        text: text,
        imagePaths: List.of(imagePaths),
        videoPaths: List.of(videoPaths),
        pdfPaths: List.of(pdfPaths),
        linkUrl: linkUrl,
        linkLabel: linkLabel,
        links: links,
        displayMode: displayMode,
      );
}

/// A single BPMN node with position and size.
class NodeModel {
  String id;
  NodeType type;
  String name;
  Rect rect;
  TaskContent? content; // meaningful for task, startEvent, endEvent

  NodeModel({
    required this.id,
    required this.type,
    this.name = '',
    required this.rect,
    this.content,
  });

  NodeModel copy() => NodeModel(
        id: id,
        type: type,
        name: name,
        rect: rect,
        content: content?.copy(),
      );

  Offset get center => rect.center;

  /// Default sizes for each node type.
  static Rect defaultRect(NodeType type, Offset position) {
    switch (type) {
      case NodeType.startEvent:
      case NodeType.endEvent:
        return Rect.fromCenter(center: position, width: 48, height: 48);
      case NodeType.task:
        return Rect.fromCenter(center: position, width: 140, height: 70);
      case NodeType.exclusiveGateway:
        return Rect.fromCenter(center: position, width: 56, height: 56);
    }
  }
}

/// A sequence flow between two nodes.
class EdgeModel {
  String id;
  String sourceId;
  String targetId;
  List<Offset> waypoints;
  String name;
  ConnectorSide? sourceSide;
  ConnectorSide? targetSide;

  EdgeModel({
    required this.id,
    required this.sourceId,
    required this.targetId,
    List<Offset>? waypoints,
    this.name = '',
    this.sourceSide,
    this.targetSide,
  }) : waypoints = waypoints ?? [];

  EdgeModel copy() => EdgeModel(
        id: id,
        sourceId: sourceId,
        targetId: targetId,
        waypoints: List.of(waypoints),
        name: name,
        sourceSide: sourceSide,
        targetSide: targetSide,
      );
}

/// The complete diagram model.
class DiagramModel {
  final Map<String, NodeModel> nodes;
  final Map<String, EdgeModel> edges;

  /// Optional metadata from the original BPMN file.
  String? processId;
  String? definitionsId;

  DiagramModel({
    Map<String, NodeModel>? nodes,
    Map<String, EdgeModel>? edges,
    this.processId,
    this.definitionsId,
  })  : nodes = nodes ?? {},
        edges = edges ?? {};

  DiagramModel copy() {
    return DiagramModel(
      nodes: {for (final e in nodes.entries) e.key: e.value.copy()},
      edges: {for (final e in edges.entries) e.key: e.value.copy()},
      processId: processId,
      definitionsId: definitionsId,
    );
  }

  /// Get all edges connected to a node.
  List<EdgeModel> edgesForNode(String nodeId) {
    return edges.values
        .where((e) => e.sourceId == nodeId || e.targetId == nodeId)
        .toList();
  }

  /// Get outgoing edges from a node.
  List<EdgeModel> outgoingEdges(String nodeId) {
    return edges.values.where((e) => e.sourceId == nodeId).toList();
  }

  /// Get incoming edges to a node.
  List<EdgeModel> incomingEdges(String nodeId) {
    return edges.values.where((e) => e.targetId == nodeId).toList();
  }

  /// Returns the set of node IDs not reachable from any start event.
  /// These are "orphaned" nodes — disconnected from the main flow.
  Set<String> orphanedNodeIds() {
    // BFS from all start events.
    final reachable = <String>{};
    final queue = <String>[];
    for (final node in nodes.values) {
      if (node.type == NodeType.startEvent) {
        reachable.add(node.id);
        queue.add(node.id);
      }
    }
    while (queue.isNotEmpty) {
      final current = queue.removeLast();
      for (final edge in edges.values) {
        if (edge.sourceId == current && reachable.add(edge.targetId)) {
          queue.add(edge.targetId);
        }
      }
    }
    return nodes.keys.where((id) => !reachable.contains(id)).toSet();
  }
}
