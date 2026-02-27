import '../model/diagram_model.dart';
import 'commands.dart';

/// Undo/redo command stack.
class CommandStack {
  final List<Command> _undoStack = [];
  final List<Command> _redoStack = [];

  bool get canUndo => _undoStack.isNotEmpty;
  bool get canRedo => _redoStack.isNotEmpty;

  void execute(Command command, DiagramModel model) {
    command.execute(model);
    _undoStack.add(command);
    _redoStack.clear();
  }

  void undo(DiagramModel model) {
    if (!canUndo) return;
    final cmd = _undoStack.removeLast();
    cmd.undo(model);
    _redoStack.add(cmd);
  }

  void redo(DiagramModel model) {
    if (!canRedo) return;
    final cmd = _redoStack.removeLast();
    cmd.execute(model);
    _undoStack.add(cmd);
  }

  void clear() {
    _undoStack.clear();
    _redoStack.clear();
  }
}
