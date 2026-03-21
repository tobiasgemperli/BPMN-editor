import 'dart:ui';
import '../edit/hit_test.dart';

/// The types of BPMN nodes we support.
enum NodeType { startEvent, endEvent, task, exclusiveGateway }

/// Content attached to a Task node.
class TaskContent {
  String? title;
  String? text;        // plain text → <bpmn:documentation>
  String? imagePath;   // local file path (later: URL)
  String? videoPath;   // local file path (later: URL)
  String? linkUrl;
  String? linkLabel;

  TaskContent({
    this.title,
    this.text,
    this.imagePath,
    this.videoPath,
    this.linkUrl,
    this.linkLabel,
  });

  bool get hasMedia => imagePath != null || videoPath != null;
  bool get isEmpty =>
      title == null && text == null && !hasMedia && linkUrl == null;

  TaskContent copy() => TaskContent(
        title: title,
        text: text,
        imagePath: imagePath,
        videoPath: videoPath,
        linkUrl: linkUrl,
        linkLabel: linkLabel,
      );
}

/// A single BPMN node with position and size.
class NodeModel {
  String id;
  NodeType type;
  String name;
  Rect rect;
  TaskContent? content; // only meaningful for NodeType.task

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
}
