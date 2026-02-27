/// Generates stable unique IDs for BPMN elements.
class IdGenerator {
  int _counter = 0;

  /// Resets the counter, optionally scanning existing IDs to avoid collisions.
  void seedFrom(Iterable<String> existingIds) {
    for (final id in existingIds) {
      final match = RegExp(r'_(\d+)$').firstMatch(id);
      if (match != null) {
        final n = int.parse(match.group(1)!);
        if (n >= _counter) _counter = n + 1;
      }
    }
  }

  String next(String prefix) {
    final id = '${prefix}_$_counter';
    _counter++;
    return id;
  }
}
