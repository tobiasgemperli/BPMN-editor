import 'dart:ui';
import '../model/diagram_model.dart';

/// Collection of sample diagrams for the editor.
class SampleDiagrams {
  static const _taskW = 140.0;
  static const _taskH = 70.0;
  static const _eventS = 48.0;
  static const _gwS = 56.0;

  static Rect _task(double x, double y) =>
      Rect.fromCenter(center: Offset(x, y), width: _taskW, height: _taskH);
  static Rect _event(double x, double y) =>
      Rect.fromCenter(center: Offset(x, y), width: _eventS, height: _eventS);
  static Rect _gw(double x, double y) =>
      Rect.fromCenter(center: Offset(x, y), width: _gwS, height: _gwS);

  /// Simple linear: Start -> A -> B -> C -> End
  static DiagramModel linear() {
    final nodes = <String, NodeModel>{
      'n1': NodeModel(id: 'n1', type: NodeType.startEvent, name: 'Start', rect: _event(100, 250)),
      'n2': NodeModel(id: 'n2', type: NodeType.task, name: 'Gather Requirements', rect: _task(300, 250)),
      'n3': NodeModel(id: 'n3', type: NodeType.task, name: 'Design Solution', rect: _task(520, 250)),
      'n4': NodeModel(id: 'n4', type: NodeType.task, name: 'Implement', rect: _task(740, 250)),
      'n5': NodeModel(id: 'n5', type: NodeType.endEvent, name: 'Done', rect: _event(940, 250)),
    };
    final edges = <String, EdgeModel>{
      'e1': EdgeModel(id: 'e1', sourceId: 'n1', targetId: 'n2'),
      'e2': EdgeModel(id: 'e2', sourceId: 'n2', targetId: 'n3'),
      'e3': EdgeModel(id: 'e3', sourceId: 'n3', targetId: 'n4'),
      'e4': EdgeModel(id: 'e4', sourceId: 'n4', targetId: 'n5'),
    };
    return DiagramModel(nodes: nodes, edges: edges);
  }

  /// Diamond: gateway splits into two paths that merge back.
  ///
  /// ```
  /// Start -> Check -> [GW] --Yes--> Approve --\
  ///                       \--No---> Reject ---+--> Notify -> End
  /// ```
  static DiagramModel diamond() {
    final nodes = <String, NodeModel>{
      'n1': NodeModel(id: 'n1', type: NodeType.startEvent, name: 'Start', rect: _event(80, 300)),
      'n2': NodeModel(id: 'n2', type: NodeType.task, name: 'Review Request', rect: _task(260, 300)),
      'n3': NodeModel(id: 'n3', type: NodeType.exclusiveGateway, name: 'Approved?', rect: _gw(450, 300)),
      'n4': NodeModel(id: 'n4', type: NodeType.task, name: 'Process Approval', rect: _task(650, 170)),
      'n5': NodeModel(id: 'n5', type: NodeType.task, name: 'Send Rejection', rect: _task(650, 430)),
      'n6': NodeModel(id: 'n6', type: NodeType.task, name: 'Notify Customer', rect: _task(900, 300)),
      'n7': NodeModel(id: 'n7', type: NodeType.endEvent, name: 'End', rect: _event(1100, 300)),
    };
    final edges = <String, EdgeModel>{
      'e1': EdgeModel(id: 'e1', sourceId: 'n1', targetId: 'n2'),
      'e2': EdgeModel(id: 'e2', sourceId: 'n2', targetId: 'n3'),
      'e3': EdgeModel(id: 'e3', sourceId: 'n3', targetId: 'n4', name: 'Yes'),
      'e4': EdgeModel(id: 'e4', sourceId: 'n3', targetId: 'n5', name: 'No'),
      'e5': EdgeModel(id: 'e5', sourceId: 'n4', targetId: 'n6'),
      'e6': EdgeModel(id: 'e6', sourceId: 'n5', targetId: 'n6'),
      'e7': EdgeModel(id: 'e7', sourceId: 'n6', targetId: 'n7'),
    };
    return DiagramModel(nodes: nodes, edges: edges);
  }

  /// Three parallel paths converge onto a single task (3 merge inputs).
  ///
  /// ```
  /// Start -> [GW] --> Research  --\
  ///              \--> Prototype --+--> Evaluate -> End
  ///              \--> Survey    --/
  /// ```
  static DiagramModel threeWayMerge() {
    final nodes = <String, NodeModel>{
      'n1': NodeModel(id: 'n1', type: NodeType.startEvent, name: 'Start', rect: _event(80, 300)),
      'n2': NodeModel(id: 'n2', type: NodeType.exclusiveGateway, name: 'Split', rect: _gw(240, 300)),
      'n3': NodeModel(id: 'n3', type: NodeType.task, name: 'Research', rect: _task(460, 120)),
      'n4': NodeModel(id: 'n4', type: NodeType.task, name: 'Prototype', rect: _task(460, 300)),
      'n5': NodeModel(id: 'n5', type: NodeType.task, name: 'Survey Users', rect: _task(460, 480)),
      'n6': NodeModel(id: 'n6', type: NodeType.task, name: 'Evaluate Results', rect: _task(740, 300)),
      'n7': NodeModel(id: 'n7', type: NodeType.endEvent, name: 'End', rect: _event(960, 300)),
    };
    final edges = <String, EdgeModel>{
      'e1': EdgeModel(id: 'e1', sourceId: 'n1', targetId: 'n2'),
      'e2': EdgeModel(id: 'e2', sourceId: 'n2', targetId: 'n3'),
      'e3': EdgeModel(id: 'e3', sourceId: 'n2', targetId: 'n4'),
      'e4': EdgeModel(id: 'e4', sourceId: 'n2', targetId: 'n5'),
      'e5': EdgeModel(id: 'e5', sourceId: 'n3', targetId: 'n6'),
      'e6': EdgeModel(id: 'e6', sourceId: 'n4', targetId: 'n6'),
      'e7': EdgeModel(id: 'e7', sourceId: 'n5', targetId: 'n6'),
      'e8': EdgeModel(id: 'e8', sourceId: 'n6', targetId: 'n7'),
    };
    return DiagramModel(nodes: nodes, edges: edges);
  }

  /// Multiple merge points: two diamonds chained.
  ///
  /// ```
  /// Start -> [GW1] -> A --\        /-- D --\
  ///                -> B --+->[GW2]-+-- E --+--> Final -> End
  ///                                        /
  /// ```
  static DiagramModel doubleDiamond() {
    final nodes = <String, NodeModel>{
      'n1': NodeModel(id: 'n1', type: NodeType.startEvent, name: 'Start', rect: _event(60, 300)),
      'n2': NodeModel(id: 'n2', type: NodeType.exclusiveGateway, name: 'Phase?', rect: _gw(200, 300)),
      'n3': NodeModel(id: 'n3', type: NodeType.task, name: 'Plan A', rect: _task(400, 170)),
      'n4': NodeModel(id: 'n4', type: NodeType.task, name: 'Plan B', rect: _task(400, 430)),
      'n5': NodeModel(id: 'n5', type: NodeType.exclusiveGateway, name: 'Route?', rect: _gw(620, 300)),
      'n6': NodeModel(id: 'n6', type: NodeType.task, name: 'Execute Fast', rect: _task(820, 170)),
      'n7': NodeModel(id: 'n7', type: NodeType.task, name: 'Execute Safe', rect: _task(820, 430)),
      'n8': NodeModel(id: 'n8', type: NodeType.task, name: 'Ship Release', rect: _task(1060, 300)),
      'n9': NodeModel(id: 'n9', type: NodeType.endEvent, name: 'End', rect: _event(1260, 300)),
    };
    final edges = <String, EdgeModel>{
      'e1': EdgeModel(id: 'e1', sourceId: 'n1', targetId: 'n2'),
      'e2': EdgeModel(id: 'e2', sourceId: 'n2', targetId: 'n3', name: 'A'),
      'e3': EdgeModel(id: 'e3', sourceId: 'n2', targetId: 'n4', name: 'B'),
      'e4': EdgeModel(id: 'e4', sourceId: 'n3', targetId: 'n5'),
      'e5': EdgeModel(id: 'e5', sourceId: 'n4', targetId: 'n5'),
      'e6': EdgeModel(id: 'e6', sourceId: 'n5', targetId: 'n6', name: 'Fast'),
      'e7': EdgeModel(id: 'e7', sourceId: 'n5', targetId: 'n7', name: 'Safe'),
      'e8': EdgeModel(id: 'e8', sourceId: 'n6', targetId: 'n8'),
      'e9': EdgeModel(id: 'e9', sourceId: 'n7', targetId: 'n8'),
      'e10': EdgeModel(id: 'e10', sourceId: 'n8', targetId: 'n9'),
    };
    return DiagramModel(nodes: nodes, edges: edges);
  }

  /// Four parallel paths converge on one node (4 merge inputs).
  ///
  /// ```
  /// Start -> [GW] --> Analyze Data --\
  ///              \--> Build Model  --+--> Consolidate -> End
  ///              \--> Run Tests    --/
  ///              \--> Write Docs   -/
  /// ```
  static DiagramModel fourWayMerge() {
    final nodes = <String, NodeModel>{
      'n1': NodeModel(id: 'n1', type: NodeType.startEvent, name: 'Start', rect: _event(80, 360)),
      'n2': NodeModel(id: 'n2', type: NodeType.exclusiveGateway, name: 'Split', rect: _gw(220, 360)),
      'n3': NodeModel(id: 'n3', type: NodeType.task, name: 'Analyze Data', rect: _task(440, 120)),
      'n4': NodeModel(id: 'n4', type: NodeType.task, name: 'Build Model', rect: _task(440, 280)),
      'n5': NodeModel(id: 'n5', type: NodeType.task, name: 'Run Tests', rect: _task(440, 440)),
      'n6': NodeModel(id: 'n6', type: NodeType.task, name: 'Write Docs', rect: _task(440, 600)),
      'n7': NodeModel(id: 'n7', type: NodeType.task, name: 'Consolidate', rect: _task(720, 360)),
      'n8': NodeModel(id: 'n8', type: NodeType.endEvent, name: 'Done', rect: _event(940, 360)),
    };
    final edges = <String, EdgeModel>{
      'e1': EdgeModel(id: 'e1', sourceId: 'n1', targetId: 'n2'),
      'e2': EdgeModel(id: 'e2', sourceId: 'n2', targetId: 'n3'),
      'e3': EdgeModel(id: 'e3', sourceId: 'n2', targetId: 'n4'),
      'e4': EdgeModel(id: 'e4', sourceId: 'n2', targetId: 'n5'),
      'e5': EdgeModel(id: 'e5', sourceId: 'n2', targetId: 'n6'),
      'e6': EdgeModel(id: 'e6', sourceId: 'n3', targetId: 'n7'),
      'e7': EdgeModel(id: 'e7', sourceId: 'n4', targetId: 'n7'),
      'e8': EdgeModel(id: 'e8', sourceId: 'n5', targetId: 'n7'),
      'e9': EdgeModel(id: 'e9', sourceId: 'n6', targetId: 'n7'),
      'e10': EdgeModel(id: 'e10', sourceId: 'n7', targetId: 'n8'),
    };
    return DiagramModel(nodes: nodes, edges: edges);
  }

  /// Agile sprint cycle: concept, decision, 3 sprints, user tests,
  /// optional improvement sprint.
  ///
  /// ```
  /// Start -> Sprint 1 -> [Proceed?] --No-> End
  ///                           |Yes
  ///                S2 -> S3 -> S4 -> [User Tests]
  ///                                   /        \
  ///                              Good        Needs Improvement
  ///                               |                |
  ///                        Product Launch    S5 -> Product Launch
  /// ```
  static DiagramModel sprintCycle() {
    final nodes = <String, NodeModel>{
      'n1':  NodeModel(id: 'n1',  type: NodeType.startEvent,       name: 'Start',           rect: _event(80, 300)),
      'n2':  NodeModel(id: 'n2',  type: NodeType.task,             name: 'Sprint 1',        rect: _task(280, 300),
        content: TaskContent(
          title: 'Discovery & Planning',
          text: 'Define the product vision and identify key user stories. '
              'Set up the development environment and establish coding standards. '
              'Create the initial backlog with prioritized features.',
        )),
      'n3':  NodeModel(id: 'n3',  type: NodeType.exclusiveGateway, name: 'Proceed?',        rect: _gw(470, 300)),
      'n4':  NodeModel(id: 'n4',  type: NodeType.endEvent,         name: 'End',             rect: _event(470, 480)),
      'n5':  NodeModel(id: 'n5',  type: NodeType.task,             name: 'Sprint 2',        rect: _task(650, 300),
        content: TaskContent(
          title: 'Core Feature Development',
          text: 'Implement the primary user-facing features identified in Sprint 1. '
              'Focus on building a working MVP that can be demonstrated to stakeholders.',
        )),
      'n6':  NodeModel(id: 'n6',  type: NodeType.task,             name: 'Sprint 3',        rect: _task(850, 300),
        content: TaskContent(
          title: 'Integration & Polish',
          text: 'Connect all components and ensure end-to-end flows work correctly. '
              'Address UI/UX feedback and fix critical bugs found during development.',
        )),
      'n7':  NodeModel(id: 'n7',  type: NodeType.task,             name: 'Sprint 4',        rect: _task(1050, 300),
        content: TaskContent(
          title: 'Testing & Stabilization',
          text: 'Run comprehensive test suites including integration and performance tests. '
              'Prepare release documentation and deployment scripts.',
        )),
      'n8':  NodeModel(id: 'n8',  type: NodeType.exclusiveGateway, name: 'User Tests',      rect: _gw(1240, 300)),
      'n9':  NodeModel(id: 'n9',  type: NodeType.endEvent,         name: 'Product Launch',  rect: _event(1440, 300)),
      'n10': NodeModel(id: 'n10', type: NodeType.task,             name: 'Sprint 5',        rect: _task(1240, 500),
        content: TaskContent(
          title: 'Improvement Sprint',
          text: 'Address issues found during user testing. '
              'Implement high-priority improvements and re-validate with users.',
        )),
      'n11': NodeModel(id: 'n11', type: NodeType.endEvent,         name: 'Product Launch',  rect: _event(1440, 500)),
    };
    final edges = <String, EdgeModel>{
      'e1':  EdgeModel(id: 'e1',  sourceId: 'n1',  targetId: 'n2'),
      'e2':  EdgeModel(id: 'e2',  sourceId: 'n2',  targetId: 'n3'),
      'e3':  EdgeModel(id: 'e3',  sourceId: 'n3',  targetId: 'n4',  name: 'No'),
      'e4':  EdgeModel(id: 'e4',  sourceId: 'n3',  targetId: 'n5',  name: 'Yes'),
      'e5':  EdgeModel(id: 'e5',  sourceId: 'n5',  targetId: 'n6'),
      'e6':  EdgeModel(id: 'e6',  sourceId: 'n6',  targetId: 'n7'),
      'e7':  EdgeModel(id: 'e7',  sourceId: 'n7',  targetId: 'n8'),
      'e8':  EdgeModel(id: 'e8',  sourceId: 'n8',  targetId: 'n9',  name: 'Good'),
      'e9':  EdgeModel(id: 'e9',  sourceId: 'n8',  targetId: 'n10', name: 'Needs Improvement'),
      'e10': EdgeModel(id: 'e10', sourceId: 'n10', targetId: 'n11'),
    };
    return DiagramModel(nodes: nodes, edges: edges);
  }

  /// All sample diagrams with display names.
  static final List<({String name, DiagramModel Function() builder})> all = [
    (name: 'Sprint Cycle', builder: sprintCycle),
    (name: 'Linear Flow', builder: linear),
    (name: 'Diamond (2 merge)', builder: diamond),
    (name: 'Three-Way Merge', builder: threeWayMerge),
    (name: 'Double Diamond (2x2 merge)', builder: doubleDiamond),
    (name: 'Four-Way Merge', builder: fourWayMerge),
  ];
}
