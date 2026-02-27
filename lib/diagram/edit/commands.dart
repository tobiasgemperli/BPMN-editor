import 'dart:ui';
import '../model/diagram_model.dart';

/// Base class for undoable commands.
abstract class Command {
  void execute(DiagramModel model);
  void undo(DiagramModel model);
  String get description;
}

/// Adds a node to the diagram.
class AddNodeCommand extends Command {
  final NodeModel node;

  AddNodeCommand(this.node);

  @override
  void execute(DiagramModel model) {
    model.nodes[node.id] = node;
  }

  @override
  void undo(DiagramModel model) {
    model.nodes.remove(node.id);
  }

  @override
  String get description => 'Add ${node.type.name}';
}

/// Removes a node and all connected edges.
class DeleteNodeCommand extends Command {
  final String nodeId;
  NodeModel? _removedNode;
  final List<EdgeModel> _removedEdges = [];

  DeleteNodeCommand(this.nodeId);

  @override
  void execute(DiagramModel model) {
    _removedNode = model.nodes.remove(nodeId);
    final toRemove =
        model.edges.values.where((e) => e.sourceId == nodeId || e.targetId == nodeId).toList();
    for (final e in toRemove) {
      _removedEdges.add(e);
      model.edges.remove(e.id);
    }
  }

  @override
  void undo(DiagramModel model) {
    if (_removedNode != null) {
      model.nodes[nodeId] = _removedNode!;
    }
    for (final e in _removedEdges) {
      model.edges[e.id] = e;
    }
  }

  @override
  String get description => 'Delete node';
}

/// Moves a node by a delta.
class MoveNodeCommand extends Command {
  final String nodeId;
  final Offset delta;

  MoveNodeCommand(this.nodeId, this.delta);

  @override
  void execute(DiagramModel model) {
    final node = model.nodes[nodeId];
    if (node != null) {
      node.rect = node.rect.shift(delta);
    }
  }

  @override
  void undo(DiagramModel model) {
    final node = model.nodes[nodeId];
    if (node != null) {
      node.rect = node.rect.shift(-delta);
    }
  }

  @override
  String get description => 'Move node';
}

/// Adds a sequence flow edge.
class AddEdgeCommand extends Command {
  final EdgeModel edge;

  AddEdgeCommand(this.edge);

  @override
  void execute(DiagramModel model) {
    model.edges[edge.id] = edge;
  }

  @override
  void undo(DiagramModel model) {
    model.edges.remove(edge.id);
  }

  @override
  String get description => 'Connect nodes';
}

/// Removes an edge.
class DeleteEdgeCommand extends Command {
  final String edgeId;
  EdgeModel? _removed;

  DeleteEdgeCommand(this.edgeId);

  @override
  void execute(DiagramModel model) {
    _removed = model.edges.remove(edgeId);
  }

  @override
  void undo(DiagramModel model) {
    if (_removed != null) {
      model.edges[edgeId] = _removed!;
    }
  }

  @override
  String get description => 'Delete edge';
}

/// A composite command that executes multiple commands as one undo unit.
class CompositeCommand extends Command {
  final List<Command> commands;
  final String _description;

  CompositeCommand(this.commands, {String description = 'Composite'})
      : _description = description;

  @override
  void execute(DiagramModel model) {
    for (final cmd in commands) {
      cmd.execute(model);
    }
  }

  @override
  void undo(DiagramModel model) {
    for (final cmd in commands.reversed) {
      cmd.undo(model);
    }
  }

  @override
  String get description => _description;
}

/// Renames a node.
class RenameNodeCommand extends Command {
  final String nodeId;
  final String newName;
  String _oldName = '';

  RenameNodeCommand(this.nodeId, this.newName);

  @override
  void execute(DiagramModel model) {
    final node = model.nodes[nodeId];
    if (node != null) {
      _oldName = node.name;
      node.name = newName;
    }
  }

  @override
  void undo(DiagramModel model) {
    final node = model.nodes[nodeId];
    if (node != null) {
      node.name = _oldName;
    }
  }

  @override
  String get description => 'Rename node';
}
