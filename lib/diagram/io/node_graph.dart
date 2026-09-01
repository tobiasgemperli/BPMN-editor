import 'dart:ui';

import '../model/diagram_model.dart';
import '../edit/editor_controller.dart';

/// Builds a [DiagramModel] from the backend's legacy `Nodes` flow format,
/// used when a model has no `BpmnXml` (most of the older Guide library).
///
/// Nodes link via connection ids, not node ids: a node's output id
/// (`ConnectToId`, or one of `ConnectToIds`; `-1` means no branch) matches
/// the node whose `IdInput` equals it. `Type`: 4=start, 0=step, 1=decision,
/// 5=stop. The backend supplies no coordinates, so the final positions come
/// from the editor's auto-layout ("brush"), which lays nodes out top-to-bottom
/// like the rest of the app.
DiagramModel diagramFromNodes(List<dynamic> nodesJson) {
  final nodes = nodesJson.whereType<Map<String, dynamic>>().toList();
  final diagram = DiagramModel();
  if (nodes.isEmpty) return diagram;

  int? asInt(dynamic v) =>
      v is int ? v : (v is num ? v.toInt() : int.tryParse('${v ?? ''}'));

  // Map each input connection id -> owning node id.
  final inputToNode = <int, int>{};
  for (final n in nodes) {
    final input = asInt(n['IdInput']);
    final id = asInt(n['Id']);
    if (input != null && id != null) inputToNode[input] = id;
  }

  // Resolve edges (source node id, target node id, label).
  final edges = <({int from, int to, String label})>[];
  for (final n in nodes) {
    final id = asInt(n['Id']);
    if (id == null) continue;
    final connectToIds = (n['ConnectToIds'] as List?)?.map(asInt).toList();
    final descOutputs = (n['DescOutputs'] as List?)?.map((e) => '$e').toList();
    if (connectToIds != null && connectToIds.isNotEmpty) {
      for (var i = 0; i < connectToIds.length; i++) {
        final conn = connectToIds[i];
        if (conn == null || conn == -1) continue;
        final target = inputToNode[conn];
        if (target != null && target != id) {
          final label = (descOutputs != null && i < descOutputs.length)
              ? descOutputs[i]
              : '';
          edges.add((from: id, to: target, label: label));
        }
      }
    } else {
      final conn = asInt(n['ConnectToId']);
      if (conn != null && conn != -1) {
        final target = inputToNode[conn];
        if (target != null && target != id) {
          edges.add((from: id, to: target, label: '${n['DescOutput'] ?? ''}'));
        }
      }
    }
  }

  // Longest-path layering (cycle-safe: bounded passes, depth capped).
  final ids = nodes.map((n) => asInt(n['Id'])!).toList();
  final depth = {for (final id in ids) id: 0};
  final maxDepth = ids.length;
  for (var pass = 0; pass < ids.length; pass++) {
    var changed = false;
    for (final e in edges) {
      final cand = depth[e.from]! + 1;
      if (cand > depth[e.to]! && cand <= maxDepth) {
        depth[e.to] = cand;
        changed = true;
      }
    }
    if (!changed) break;
  }

  // Group by column, preserving order for stable rows.
  final byColumn = <int, List<int>>{};
  for (final id in ids) {
    byColumn.putIfAbsent(depth[id]!, () => []).add(id);
  }

  const colGap = 240.0, rowGap = 130.0, marginX = 120.0, marginY = 120.0;
  final nodeById = {for (final n in nodes) asInt(n['Id'])!: n};
  for (final col in byColumn.keys) {
    final colNodes = byColumn[col]!;
    final colHeight = (colNodes.length - 1) * rowGap;
    for (var row = 0; row < colNodes.length; row++) {
      final id = colNodes[row];
      final n = nodeById[id]!;
      final center = Offset(
        marginX + col * colGap,
        marginY + row * rowGap - colHeight / 2,
      );
      final type = _mapType(asInt(n['Type']) ?? 0);
      diagram.nodes['$id'] = NodeModel(
        id: '$id',
        type: type,
        name: ('${n['Text'] ?? ''}').replaceAll('\n', ' ').trim(),
        rect: NodeModel.defaultRect(type, center),
      );
    }
  }

  var seq = 0;
  for (final e in edges) {
    final id = 'flow_${seq++}';
    diagram.edges[id] = EdgeModel(
      id: id,
      sourceId: '${e.from}',
      targetId: '${e.to}',
      name: e.label,
    );
  }

  // Re-layout top-to-bottom with the editor's auto-layout ("brush"), so
  // converted models read vertically like the rest of the app instead of
  // the left-to-right layering built above.
  final ctrl = EditorController(diagram: diagram);
  ctrl.autoLayout();
  return ctrl.diagram;
}

NodeType _mapType(int serverType) {
  switch (serverType) {
    case 4:
      return NodeType.startEvent;
    case 5:
      return NodeType.endEvent;
    case 1:
      return NodeType.exclusiveGateway;
    default:
      return NodeType.task;
  }
}
