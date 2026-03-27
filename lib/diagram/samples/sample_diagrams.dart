import 'dart:ui';
import '../model/diagram_model.dart';

/// Collection of sample diagrams for the editor.
/// All layouts are top-down, optimized for portrait mode.
class SampleDiagrams {
  static const _taskW = 140.0;
  static const _taskH = 70.0;
  static const _eventS = 48.0;
  static const _gwS = 56.0;

  // Center column for portrait layout.
  static const _cx = 200.0;
  // Vertical spacing between rows.
  static const _rowH = 130.0;
  // Horizontal offset for branches.
  static const _branchX = 170.0;

  static Rect _task(double x, double y) =>
      Rect.fromCenter(center: Offset(x, y), width: _taskW, height: _taskH);
  static Rect _event(double x, double y) =>
      Rect.fromCenter(center: Offset(x, y), width: _eventS, height: _eventS);
  static Rect _gw(double x, double y) =>
      Rect.fromCenter(center: Offset(x, y), width: _gwS, height: _gwS);

  static double _row(int r) => 80.0 + r * _rowH;

  /// L-shaped waypoints: go horizontal first, then vertical.
  static List<Offset> _hv(double x1, double y1, double x2, double y2) =>
      [Offset(x1, y1), Offset(x2, y1), Offset(x2, y2)];

  /// L-shaped waypoints: go vertical first, then horizontal.
  static List<Offset> _vh(double x1, double y1, double x2, double y2) =>
      [Offset(x1, y1), Offset(x1, y2), Offset(x2, y2)];

  /// Simple linear: Start -> A -> B -> C -> End
  static DiagramModel linear() {
    final nodes = <String, NodeModel>{
      'n1': NodeModel(id: 'n1', type: NodeType.startEvent, name: 'Start', rect: _event(_cx, _row(0))),
      'n2': NodeModel(id: 'n2', type: NodeType.task, name: 'Gather Requirements', rect: _task(_cx, _row(1))),
      'n3': NodeModel(id: 'n3', type: NodeType.task, name: 'Design Solution', rect: _task(_cx, _row(2))),
      'n4': NodeModel(id: 'n4', type: NodeType.task, name: 'Implement', rect: _task(_cx, _row(3))),
      'n5': NodeModel(id: 'n5', type: NodeType.endEvent, name: 'Done', rect: _event(_cx, _row(4))),
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
  static DiagramModel diamond() {
    final left = _cx - _branchX;
    final right = _cx + _branchX;
    final nodes = <String, NodeModel>{
      'n1': NodeModel(id: 'n1', type: NodeType.startEvent, name: 'Start', rect: _event(_cx, _row(0))),
      'n2': NodeModel(id: 'n2', type: NodeType.task, name: 'Review Request', rect: _task(_cx, _row(1))),
      'n3': NodeModel(id: 'n3', type: NodeType.exclusiveGateway, name: 'Approved?', rect: _gw(_cx, _row(2))),
      'n4': NodeModel(id: 'n4', type: NodeType.task, name: 'Process Approval', rect: _task(left, _row(3))),
      'n5': NodeModel(id: 'n5', type: NodeType.task, name: 'Send Rejection', rect: _task(right, _row(3))),
      'n6': NodeModel(id: 'n6', type: NodeType.task, name: 'Notify Customer', rect: _task(_cx, _row(4))),
      'n7': NodeModel(id: 'n7', type: NodeType.endEvent, name: 'End', rect: _event(_cx, _row(5))),
    };
    final edges = <String, EdgeModel>{
      'e1': EdgeModel(id: 'e1', sourceId: 'n1', targetId: 'n2'),
      'e2': EdgeModel(id: 'e2', sourceId: 'n2', targetId: 'n3'),
      'e3': EdgeModel(id: 'e3', sourceId: 'n3', targetId: 'n4', name: 'Yes',
        waypoints: _hv(_cx, _row(2), left, _row(3))),
      'e4': EdgeModel(id: 'e4', sourceId: 'n3', targetId: 'n5', name: 'No',
        waypoints: _hv(_cx, _row(2), right, _row(3))),
      'e5': EdgeModel(id: 'e5', sourceId: 'n4', targetId: 'n6',
        waypoints: _vh(left, _row(3), _cx, _row(4))),
      'e6': EdgeModel(id: 'e6', sourceId: 'n5', targetId: 'n6',
        waypoints: _vh(right, _row(3), _cx, _row(4))),
      'e7': EdgeModel(id: 'e7', sourceId: 'n6', targetId: 'n7'),
    };
    return DiagramModel(nodes: nodes, edges: edges);
  }

  /// Three parallel paths converge onto a single task.
  static DiagramModel threeWayMerge() {
    final left = _cx - _branchX;
    final right = _cx + _branchX;
    final nodes = <String, NodeModel>{
      'n1': NodeModel(id: 'n1', type: NodeType.startEvent, name: 'Start', rect: _event(_cx, _row(0))),
      'n2': NodeModel(id: 'n2', type: NodeType.exclusiveGateway, name: 'Split', rect: _gw(_cx, _row(1))),
      'n3': NodeModel(id: 'n3', type: NodeType.task, name: 'Research', rect: _task(left, _row(2))),
      'n4': NodeModel(id: 'n4', type: NodeType.task, name: 'Prototype', rect: _task(_cx, _row(2))),
      'n5': NodeModel(id: 'n5', type: NodeType.task, name: 'Survey Users', rect: _task(right, _row(2))),
      'n6': NodeModel(id: 'n6', type: NodeType.task, name: 'Evaluate Results', rect: _task(_cx, _row(3))),
      'n7': NodeModel(id: 'n7', type: NodeType.endEvent, name: 'End', rect: _event(_cx, _row(4))),
    };
    final edges = <String, EdgeModel>{
      'e1': EdgeModel(id: 'e1', sourceId: 'n1', targetId: 'n2'),
      'e2': EdgeModel(id: 'e2', sourceId: 'n2', targetId: 'n3',
        waypoints: _hv(_cx, _row(1), left, _row(2))),
      'e3': EdgeModel(id: 'e3', sourceId: 'n2', targetId: 'n4'),
      'e4': EdgeModel(id: 'e4', sourceId: 'n2', targetId: 'n5',
        waypoints: _hv(_cx, _row(1), right, _row(2))),
      'e5': EdgeModel(id: 'e5', sourceId: 'n3', targetId: 'n6',
        waypoints: _vh(left, _row(2), _cx, _row(3))),
      'e6': EdgeModel(id: 'e6', sourceId: 'n4', targetId: 'n6'),
      'e7': EdgeModel(id: 'e7', sourceId: 'n5', targetId: 'n6',
        waypoints: _vh(right, _row(2), _cx, _row(3))),
      'e8': EdgeModel(id: 'e8', sourceId: 'n6', targetId: 'n7'),
    };
    return DiagramModel(nodes: nodes, edges: edges);
  }

  /// Multiple merge points: two diamonds chained.
  static DiagramModel doubleDiamond() {
    final left = _cx - _branchX;
    final right = _cx + _branchX;
    final nodes = <String, NodeModel>{
      'n1': NodeModel(id: 'n1', type: NodeType.startEvent, name: 'Start', rect: _event(_cx, _row(0))),
      'n2': NodeModel(id: 'n2', type: NodeType.exclusiveGateway, name: 'Phase?', rect: _gw(_cx, _row(1))),
      'n3': NodeModel(id: 'n3', type: NodeType.task, name: 'Plan A', rect: _task(left, _row(2))),
      'n4': NodeModel(id: 'n4', type: NodeType.task, name: 'Plan B', rect: _task(right, _row(2))),
      'n5': NodeModel(id: 'n5', type: NodeType.exclusiveGateway, name: 'Route?', rect: _gw(_cx, _row(3))),
      'n6': NodeModel(id: 'n6', type: NodeType.task, name: 'Execute Fast', rect: _task(left, _row(4))),
      'n7': NodeModel(id: 'n7', type: NodeType.task, name: 'Execute Safe', rect: _task(right, _row(4))),
      'n8': NodeModel(id: 'n8', type: NodeType.task, name: 'Ship Release', rect: _task(_cx, _row(5))),
      'n9': NodeModel(id: 'n9', type: NodeType.endEvent, name: 'End', rect: _event(_cx, _row(6))),
    };
    final edges = <String, EdgeModel>{
      'e1': EdgeModel(id: 'e1', sourceId: 'n1', targetId: 'n2'),
      'e2': EdgeModel(id: 'e2', sourceId: 'n2', targetId: 'n3', name: 'A',
        waypoints: _hv(_cx, _row(1), left, _row(2))),
      'e3': EdgeModel(id: 'e3', sourceId: 'n2', targetId: 'n4', name: 'B',
        waypoints: _hv(_cx, _row(1), right, _row(2))),
      'e4': EdgeModel(id: 'e4', sourceId: 'n3', targetId: 'n5',
        waypoints: _vh(left, _row(2), _cx, _row(3))),
      'e5': EdgeModel(id: 'e5', sourceId: 'n4', targetId: 'n5',
        waypoints: _vh(right, _row(2), _cx, _row(3))),
      'e6': EdgeModel(id: 'e6', sourceId: 'n5', targetId: 'n6', name: 'Fast',
        waypoints: _hv(_cx, _row(3), left, _row(4))),
      'e7': EdgeModel(id: 'e7', sourceId: 'n5', targetId: 'n7', name: 'Safe',
        waypoints: _hv(_cx, _row(3), right, _row(4))),
      'e8': EdgeModel(id: 'e8', sourceId: 'n6', targetId: 'n8',
        waypoints: _vh(left, _row(4), _cx, _row(5))),
      'e9': EdgeModel(id: 'e9', sourceId: 'n7', targetId: 'n8',
        waypoints: _vh(right, _row(4), _cx, _row(5))),
      'e10': EdgeModel(id: 'e10', sourceId: 'n8', targetId: 'n9'),
    };
    return DiagramModel(nodes: nodes, edges: edges);
  }

  /// Four parallel paths converge on one node.
  static DiagramModel fourWayMerge() {
    const x1 = 30.0;
    const x2 = x1 + _branchX * 2 / 3;
    const x3 = x2 + _branchX * 2 / 3;
    const x4 = x3 + _branchX * 2 / 3;
    final nodes = <String, NodeModel>{
      'n1': NodeModel(id: 'n1', type: NodeType.startEvent, name: 'Start', rect: _event(_cx, _row(0))),
      'n2': NodeModel(id: 'n2', type: NodeType.exclusiveGateway, name: 'Split', rect: _gw(_cx, _row(1))),
      'n3': NodeModel(id: 'n3', type: NodeType.task, name: 'Analyze Data', rect: _task(x1, _row(2))),
      'n4': NodeModel(id: 'n4', type: NodeType.task, name: 'Build Model', rect: _task(x2, _row(2))),
      'n5': NodeModel(id: 'n5', type: NodeType.task, name: 'Run Tests', rect: _task(x3, _row(2))),
      'n6': NodeModel(id: 'n6', type: NodeType.task, name: 'Write Docs', rect: _task(x4, _row(2))),
      'n7': NodeModel(id: 'n7', type: NodeType.task, name: 'Consolidate', rect: _task(_cx, _row(3))),
      'n8': NodeModel(id: 'n8', type: NodeType.endEvent, name: 'Done', rect: _event(_cx, _row(4))),
    };
    final edges = <String, EdgeModel>{
      'e1': EdgeModel(id: 'e1', sourceId: 'n1', targetId: 'n2'),
      'e2': EdgeModel(id: 'e2', sourceId: 'n2', targetId: 'n3',
        waypoints: _hv(_cx, _row(1), x1, _row(2))),
      'e3': EdgeModel(id: 'e3', sourceId: 'n2', targetId: 'n4',
        waypoints: _hv(_cx, _row(1), x2, _row(2))),
      'e4': EdgeModel(id: 'e4', sourceId: 'n2', targetId: 'n5',
        waypoints: _hv(_cx, _row(1), x3, _row(2))),
      'e5': EdgeModel(id: 'e5', sourceId: 'n2', targetId: 'n6',
        waypoints: _hv(_cx, _row(1), x4, _row(2))),
      'e6': EdgeModel(id: 'e6', sourceId: 'n3', targetId: 'n7',
        waypoints: _vh(x1, _row(2), _cx, _row(3))),
      'e7': EdgeModel(id: 'e7', sourceId: 'n4', targetId: 'n7',
        waypoints: _vh(x2, _row(2), _cx, _row(3))),
      'e8': EdgeModel(id: 'e8', sourceId: 'n5', targetId: 'n7',
        waypoints: _vh(x3, _row(2), _cx, _row(3))),
      'e9': EdgeModel(id: 'e9', sourceId: 'n6', targetId: 'n7',
        waypoints: _vh(x4, _row(2), _cx, _row(3))),
      'e10': EdgeModel(id: 'e10', sourceId: 'n7', targetId: 'n8'),
    };
    return DiagramModel(nodes: nodes, edges: edges);
  }

  /// Agile sprint cycle.
  static DiagramModel sprintCycle() {
    final left = _cx - _branchX;
    final right = _cx + _branchX;
    final nodes = <String, NodeModel>{
      'n1':  NodeModel(id: 'n1',  type: NodeType.startEvent,       name: 'Start',           rect: _event(_cx, _row(0))),
      'n2':  NodeModel(id: 'n2',  type: NodeType.task,             name: 'Sprint 1',        rect: _task(_cx, _row(1)),
        content: TaskContent(
          title: 'Discovery & Planning',
          text: 'Define the product vision and identify key user stories. '
              'Set up the development environment and establish coding standards. '
              'Create the initial backlog with prioritized features.',
        )),
      'n3':  NodeModel(id: 'n3',  type: NodeType.exclusiveGateway, name: 'Proceed?',        rect: _gw(_cx, _row(2))),
      'n4':  NodeModel(id: 'n4',  type: NodeType.endEvent,         name: 'End',             rect: _event(right, _row(2))),
      'n5':  NodeModel(id: 'n5',  type: NodeType.task,             name: 'Sprint 2',        rect: _task(_cx, _row(3)),
        content: TaskContent(
          title: 'Core Feature Development',
          text: 'Implement the primary user-facing features identified in Sprint 1. '
              'Focus on building a working MVP that can be demonstrated to stakeholders.',
        )),
      'n6':  NodeModel(id: 'n6',  type: NodeType.task,             name: 'Sprint 3',        rect: _task(_cx, _row(4)),
        content: TaskContent(
          title: 'Integration & Polish',
          text: 'Connect all components and ensure end-to-end flows work correctly. '
              'Address UI/UX feedback and fix critical bugs found during development.',
        )),
      'n7':  NodeModel(id: 'n7',  type: NodeType.task,             name: 'Sprint 4',        rect: _task(_cx, _row(5)),
        content: TaskContent(
          title: 'Testing & Stabilization',
          text: 'Run comprehensive test suites including integration and performance tests. '
              'Prepare release documentation and deployment scripts.',
        )),
      'n8':  NodeModel(id: 'n8',  type: NodeType.exclusiveGateway, name: 'User Tests',      rect: _gw(_cx, _row(6))),
      'n9':  NodeModel(id: 'n9',  type: NodeType.endEvent,         name: 'Product Launch',  rect: _event(left, _row(7))),
      'n10': NodeModel(id: 'n10', type: NodeType.task,             name: 'Sprint 5',        rect: _task(right, _row(7)),
        content: TaskContent(
          title: 'Improvement Sprint',
          text: 'Address issues found during user testing. '
              'Implement high-priority improvements and re-validate with users.',
        )),
      'n11': NodeModel(id: 'n11', type: NodeType.endEvent,         name: 'Product Launch',  rect: _event(right, _row(8))),
    };
    final edges = <String, EdgeModel>{
      'e1':  EdgeModel(id: 'e1',  sourceId: 'n1',  targetId: 'n2'),
      'e2':  EdgeModel(id: 'e2',  sourceId: 'n2',  targetId: 'n3'),
      'e3':  EdgeModel(id: 'e3',  sourceId: 'n3',  targetId: 'n4',  name: 'No',
        waypoints: _hv(_cx, _row(2), right, _row(2))),
      'e4':  EdgeModel(id: 'e4',  sourceId: 'n3',  targetId: 'n5',  name: 'Yes'),
      'e5':  EdgeModel(id: 'e5',  sourceId: 'n5',  targetId: 'n6'),
      'e6':  EdgeModel(id: 'e6',  sourceId: 'n6',  targetId: 'n7'),
      'e7':  EdgeModel(id: 'e7',  sourceId: 'n7',  targetId: 'n8'),
      'e8':  EdgeModel(id: 'e8',  sourceId: 'n8',  targetId: 'n9',  name: 'Good',
        waypoints: _hv(_cx, _row(6), left, _row(7))),
      'e9':  EdgeModel(id: 'e9',  sourceId: 'n8',  targetId: 'n10', name: 'Needs Improvement',
        waypoints: _hv(_cx, _row(6), right, _row(7))),
      'e10': EdgeModel(id: 'e10', sourceId: 'n10', targetId: 'n11'),
    };
    return DiagramModel(nodes: nodes, edges: edges);
  }

  /// Technical debugging: API returning 500 errors.
  static DiagramModel technicalDebugging() {
    final left = _cx - _branchX;
    final right = _cx + _branchX;
    final nodes = <String, NodeModel>{
      'n1': NodeModel(id: 'n1', type: NodeType.startEvent, name: 'Bug Report', rect: _event(_cx, _row(0))),
      'n2': NodeModel(id: 'n2', type: NodeType.task, name: 'Reproduce', rect: _task(_cx, _row(1)),
        content: TaskContent(
          title: 'Reproduce the Issue',
          text: 'Open the API endpoint in question using the exact parameters from the bug report. '
              'Confirm the 500 error is reproducible. Note the exact request payload, headers, '
              'and timestamp. Check if the issue is environment-specific (staging vs production). '
              'Try with different user accounts to determine if it is user-specific.',
        )),
      'n3': NodeModel(id: 'n3', type: NodeType.task, name: 'Check Logs', rect: _task(_cx, _row(2)),
        content: TaskContent(
          title: 'Analyze Server Logs',
          text: 'SSH into the production server or open the logging dashboard. '
              'Filter logs by the timestamp and request ID from the reproduction step. '
              'Look for stack traces, error messages, and any preceding warnings. '
              'Check application logs, web server logs (nginx/Apache), and system logs. '
              'Note the exact exception type and the line number where it occurs.',
        )),
      'n4': NodeModel(id: 'n4', type: NodeType.exclusiveGateway, name: 'Error Type?', rect: _gw(_cx, _row(3))),
      // DB path
      'n5': NodeModel(id: 'n5', type: NodeType.task, name: 'Check DB', rect: _task(left, _row(4)),
        content: TaskContent(
          title: 'Inspect Database State',
          text: 'Connect to the database and run the failing query manually. '
              'Check for missing indices, locked rows, or corrupted data. '
              'Verify that recent migrations have been applied correctly. '
              'Look at the slow query log for performance issues.',
        )),
      'n6': NodeModel(id: 'n6', type: NodeType.task, name: 'Fix Query', rect: _task(left, _row(5)),
        content: TaskContent(
          title: 'Apply Database Fix',
          text: 'Fix the query, add the missing index, or repair the data. '
              'If a migration is needed, write it and test on staging first. '
              'Document the root cause in the ticket.',
        )),
      // Auth path
      'n7': NodeModel(id: 'n7', type: NodeType.task, name: 'Check Tokens', rect: _task(_cx, _row(4)),
        content: TaskContent(
          title: 'Validate Authentication',
          text: 'Decode the JWT token and check expiry, issuer, and audience claims. '
              'Verify the signing key matches between auth server and API. '
              'Check if the user\'s session exists in the session store (Redis/DB). '
              'Look for clock skew between servers.',
        )),
      'n8': NodeModel(id: 'n8', type: NodeType.task, name: 'Fix Auth', rect: _task(_cx, _row(5)),
        content: TaskContent(
          title: 'Refresh Auth Configuration',
          text: 'Rotate the signing keys if compromised. Update the token expiry settings. '
              'Clear stale sessions from the session store. '
              'Deploy the auth fix and monitor for recurring failures.',
        )),
      // Timeout path
      'n9': NodeModel(id: 'n9', type: NodeType.task, name: 'Check Load', rect: _task(right, _row(4)),
        content: TaskContent(
          title: 'Analyze System Resources',
          text: 'Check CPU, memory, and disk usage on the affected server. '
              'Review the connection pool utilization and open file descriptors. '
              'Check if any background jobs or cron tasks are consuming excessive resources. '
              'Look at the request queue depth and average response times.',
        )),
      'n10': NodeModel(id: 'n10', type: NodeType.task, name: 'Optimize', rect: _task(right, _row(5)),
        content: TaskContent(
          title: 'Scale or Optimize',
          text: 'Add caching for expensive queries. Increase connection pool size. '
              'Scale horizontally by adding more instances behind the load balancer. '
              'Set appropriate timeouts on upstream service calls.',
        )),
      // Merge
      'n11': NodeModel(id: 'n11', type: NodeType.task, name: 'Verify Fix', rect: _task(_cx, _row(6)),
        content: TaskContent(
          title: 'Verify the Fix',
          text: 'Re-run the exact reproduction steps from step 1. '
              'Confirm the 500 error no longer occurs. Run the full API test suite. '
              'Monitor production logs for 30 minutes after deployment. '
              'Update the bug ticket with the root cause and resolution.',
        )),
      'n12': NodeModel(id: 'n12', type: NodeType.endEvent, name: 'Resolved', rect: _event(_cx, _row(7))),
    };
    final edges = <String, EdgeModel>{
      'e1':  EdgeModel(id: 'e1',  sourceId: 'n1',  targetId: 'n2'),
      'e2':  EdgeModel(id: 'e2',  sourceId: 'n2',  targetId: 'n3'),
      'e3':  EdgeModel(id: 'e3',  sourceId: 'n3',  targetId: 'n4'),
      'e4':  EdgeModel(id: 'e4',  sourceId: 'n4',  targetId: 'n5',  name: 'Database',
        waypoints: _hv(_cx, _row(3), left, _row(4))),
      'e5':  EdgeModel(id: 'e5',  sourceId: 'n4',  targetId: 'n7',  name: 'Auth'),
      'e6':  EdgeModel(id: 'e6',  sourceId: 'n4',  targetId: 'n9',  name: 'Timeout',
        waypoints: _hv(_cx, _row(3), right, _row(4))),
      'e7':  EdgeModel(id: 'e7',  sourceId: 'n5',  targetId: 'n6'),
      'e8':  EdgeModel(id: 'e8',  sourceId: 'n7',  targetId: 'n8'),
      'e9':  EdgeModel(id: 'e9',  sourceId: 'n9',  targetId: 'n10'),
      'e10': EdgeModel(id: 'e10', sourceId: 'n6',  targetId: 'n11',
        waypoints: _vh(left, _row(5), _cx, _row(6))),
      'e11': EdgeModel(id: 'e11', sourceId: 'n8',  targetId: 'n11'),
      'e12': EdgeModel(id: 'e12', sourceId: 'n10', targetId: 'n11',
        waypoints: _vh(right, _row(5), _cx, _row(6))),
      'e13': EdgeModel(id: 'e13', sourceId: 'n11', targetId: 'n12'),
    };
    return DiagramModel(nodes: nodes, edges: edges);
  }

  /// Emergency procedure: building fire evacuation.
  static DiagramModel emergencyProcedure() {
    final left = _cx - _branchX;
    final right = _cx + _branchX;
    final nodes = <String, NodeModel>{
      'n1': NodeModel(id: 'n1', type: NodeType.startEvent, name: 'Fire Alarm', rect: _event(_cx, _row(0))),
      'n2': NodeModel(id: 'n2', type: NodeType.task, name: 'Alert Others', rect: _task(_cx, _row(1)),
        content: TaskContent(
          title: 'Alert Nearby Personnel',
          text: 'Immediately shout "FIRE" to alert people in the vicinity. '
              'Activate the nearest manual fire alarm pull station. '
              'Do NOT use elevators. Do NOT attempt to collect personal belongings. '
              'If safe to do so, close doors and windows behind you to slow fire spread.',
        )),
      'n3': NodeModel(id: 'n3', type: NodeType.exclusiveGateway, name: 'Fire Size?', rect: _gw(_cx, _row(2))),
      // Small fire path
      'n4': NodeModel(id: 'n4', type: NodeType.task, name: 'Extinguisher', rect: _task(left, _row(3)),
        content: TaskContent(
          title: 'Use Fire Extinguisher',
          text: 'Only attempt this if the fire is small (wastebasket size or smaller) '
              'and you have a clear escape route behind you.\n\n'
              'Remember PASS:\n'
              '- Pull the pin\n'
              '- Aim at the base of the fire\n'
              '- Squeeze the handle\n'
              '- Sweep side to side\n\n'
              'Stay low to avoid smoke inhalation. If the fire does not go out within '
              '30 seconds, abandon the attempt and evacuate immediately.',
        )),
      'n5': NodeModel(id: 'n5', type: NodeType.exclusiveGateway, name: 'Fire Out?', rect: _gw(left, _row(4))),
      'n6': NodeModel(id: 'n6', type: NodeType.task, name: 'Report', rect: _task(left - _branchX * 0.6, _row(5)),
        content: TaskContent(
          title: 'File Incident Report',
          text: 'Call the fire department to report the extinguished fire — they must still inspect. '
              'Notify building management and your supervisor. '
              'Document the location, time, cause (if known), and actions taken. '
              'The affected area must not be re-entered until cleared by the fire department.',
        )),
      'n7': NodeModel(id: 'n7', type: NodeType.endEvent, name: 'Safe', rect: _event(left - _branchX * 0.6, _row(6))),
      // Large fire / extinguisher failed path
      'n8': NodeModel(id: 'n8', type: NodeType.task, name: 'Evacuate', rect: _task(right, _row(3)),
        content: TaskContent(
          title: 'Evacuate the Building',
          text: 'Follow the marked evacuation routes — green EXIT signs. '
              'Use stairwells, never elevators. Stay low if there is smoke. '
              'If a door is hot to the touch, do NOT open it — find an alternate route. '
              'Help anyone with mobility impairments. '
              'Move quickly but do not run or push.',
        )),
      'n9': NodeModel(id: 'n9', type: NodeType.task, name: 'Assembly Point', rect: _task(right, _row(4)),
        content: TaskContent(
          title: 'Go to Assembly Point',
          text: 'Proceed to the designated assembly point (parking lot B, north side). '
              'Stay at least 150 meters from the building. '
              'Do not re-enter the building for any reason. '
              'Keep access roads clear for emergency vehicles.',
        )),
      'n10': NodeModel(id: 'n10', type: NodeType.task, name: 'Headcount', rect: _task(right, _row(5)),
        content: TaskContent(
          title: 'Conduct Headcount',
          text: 'Floor wardens: use the emergency roster to verify all personnel are accounted for. '
              'Check with each department lead. '
              'Identify anyone who was known to be in the building. '
              'Report results to the incident commander within 10 minutes.',
        )),
      'n11': NodeModel(id: 'n11', type: NodeType.exclusiveGateway, name: 'All Accounted?', rect: _gw(right, _row(6))),
      'n12': NodeModel(id: 'n12', type: NodeType.task, name: 'Wait for FD', rect: _task(right - _branchX * 0.6, _row(7)),
        content: TaskContent(
          title: 'Await Fire Department',
          text: 'Remain at the assembly point until the fire department gives the all-clear. '
              'Provide the incident commander with building access information. '
              'Do not re-enter until officially authorized.',
        )),
      'n13': NodeModel(id: 'n13', type: NodeType.task, name: 'Inform FD', rect: _task(right + _branchX * 0.6, _row(7)),
        content: TaskContent(
          title: 'Report Missing Persons',
          text: 'Immediately inform the fire department incident commander of unaccounted personnel. '
              'Provide names, last known locations, and any mobility impairments. '
              'Do NOT attempt to re-enter the building to search for them.',
        )),
      'n14': NodeModel(id: 'n14', type: NodeType.endEvent, name: 'Complete', rect: _event(right, _row(8))),
    };
    final edges = <String, EdgeModel>{
      'e1':  EdgeModel(id: 'e1',  sourceId: 'n1',  targetId: 'n2'),
      'e2':  EdgeModel(id: 'e2',  sourceId: 'n2',  targetId: 'n3'),
      'e3':  EdgeModel(id: 'e3',  sourceId: 'n3',  targetId: 'n4',  name: 'Small',
        waypoints: _hv(_cx, _row(2), left, _row(3))),
      'e4':  EdgeModel(id: 'e4',  sourceId: 'n3',  targetId: 'n8',  name: 'Large',
        waypoints: _hv(_cx, _row(2), right, _row(3))),
      'e5':  EdgeModel(id: 'e5',  sourceId: 'n4',  targetId: 'n5'),
      'e6':  EdgeModel(id: 'e6',  sourceId: 'n5',  targetId: 'n6',  name: 'Yes',
        waypoints: _hv(left, _row(4), left - _branchX * 0.6, _row(5))),
      'e7':  EdgeModel(id: 'e7',  sourceId: 'n5',  targetId: 'n8',  name: 'No',
        waypoints: _hv(left, _row(4), right, _row(3))),
      'e8':  EdgeModel(id: 'e8',  sourceId: 'n6',  targetId: 'n7'),
      'e9':  EdgeModel(id: 'e9',  sourceId: 'n8',  targetId: 'n9'),
      'e10': EdgeModel(id: 'e10', sourceId: 'n9',  targetId: 'n10'),
      'e11': EdgeModel(id: 'e11', sourceId: 'n10', targetId: 'n11'),
      'e12': EdgeModel(id: 'e12', sourceId: 'n11', targetId: 'n12', name: 'Yes',
        waypoints: _hv(right, _row(6), right - _branchX * 0.6, _row(7))),
      'e13': EdgeModel(id: 'e13', sourceId: 'n11', targetId: 'n13', name: 'No',
        waypoints: _hv(right, _row(6), right + _branchX * 0.6, _row(7))),
      'e14': EdgeModel(id: 'e14', sourceId: 'n12', targetId: 'n14',
        waypoints: _vh(right - _branchX * 0.6, _row(7), right, _row(8))),
      'e15': EdgeModel(id: 'e15', sourceId: 'n13', targetId: 'n14',
        waypoints: _vh(right + _branchX * 0.6, _row(7), right, _row(8))),
    };
    return DiagramModel(nodes: nodes, edges: edges);
  }

  /// IKEA shelf assembly (KALLAX 2x2).
  static DiagramModel ikeaAssembly() {
    final nodes = <String, NodeModel>{
      'n1': NodeModel(id: 'n1', type: NodeType.startEvent, name: 'Start', rect: _event(_cx, _row(0))),
      'n2': NodeModel(id: 'n2', type: NodeType.task, name: 'Unpack', rect: _task(_cx, _row(1)),
        content: TaskContent(
          title: 'Unpack All Parts',
          text: 'Open the box and carefully remove all components. '
              'Lay them out on a clean, flat surface — ideally on the cardboard packaging to protect your floor. '
              'Do not use a knife to cut deep into the box as you may scratch the panels. '
              'Remove all plastic wrapping and styrofoam inserts.',
        )),
      'n3': NodeModel(id: 'n3', type: NodeType.task, name: 'Check Parts', rect: _task(_cx, _row(2)),
        content: TaskContent(
          title: 'Verify Parts List',
          text: 'Locate the assembly instructions sheet and find the parts list (usually page 2). '
              'Lay out all hardware (screws, dowels, cam locks) and count them against the list.\n\n'
              'You should have:\n'
              '- 4 large panels (sides, top, bottom)\n'
              '- 1 divider panel (horizontal)\n'
              '- 1 divider panel (vertical)\n'
              '- 1 back panel (thin fibreboard)\n'
              '- 8 wooden dowels\n'
              '- 8 cam lock screws\n'
              '- 8 cam lock nuts\n'
              '- 14 nails for back panel\n'
              '- 2 wall anchors + screws\n'
              '- 1 hex key (Allen wrench)',
          imagePath: 'assets/sample_image_2.jpg',
        )),
      'n4': NodeModel(id: 'n4', type: NodeType.exclusiveGateway, name: 'All Parts?', rect: _gw(_cx, _row(3))),
      // Missing parts — branch right
      'n5': NodeModel(id: 'n5', type: NodeType.task, name: 'Contact IKEA', rect: _task(_cx + _branchX, _row(4)),
        content: TaskContent(
          title: 'Order Missing Parts',
          text: 'Go to IKEA.com/replace or call customer service. '
              'You will need the product article number (on the label inside the box) '
              'and the part numbers from the instruction sheet. '
              'IKEA will ship replacement parts for free.',
        )),
      'n6': NodeModel(id: 'n6', type: NodeType.endEvent, name: 'Wait', rect: _event(_cx + _branchX, _row(5))),
      // Assembly path — continues down center
      'n7': NodeModel(id: 'n7', type: NodeType.task, name: 'Frame', rect: _task(_cx, _row(4)),
        content: TaskContent(
          title: 'Assemble the Outer Frame',
          text: 'Insert wooden dowels into the pre-drilled holes of the bottom panel. '
              'Do NOT use glue — the fit should be snug enough without it.\n\n'
              'Screw the cam lock bolts into the side panels (turn clockwise until tight). '
              'Attach both side panels to the bottom panel by sliding onto the dowels '
              'and turning the cam locks with the hex key (clockwise quarter turn).\n\n'
              'Repeat for the top panel. The frame should now stand as an open rectangle. '
              'Check that all corners are square by measuring diagonals — they should be equal.',
        )),
      'n8': NodeModel(id: 'n8', type: NodeType.task, name: 'Dividers', rect: _task(_cx, _row(5)),
        content: TaskContent(
          title: 'Insert Shelf Dividers',
          text: 'Slide the horizontal divider into position first — insert dowels, then lock with cams. '
              'Next, insert the vertical divider. It should slot into the notch on the horizontal divider, '
              'creating four equal compartments.\n\n'
              'Ensure all cam locks are firmly turned. Gently wiggle the unit — '
              'if it racks (leans to one side), a cam lock is not fully engaged.',
        )),
      'n9': NodeModel(id: 'n9', type: NodeType.task, name: 'Back Panel', rect: _task(_cx, _row(6)),
        content: TaskContent(
          title: 'Attach the Back Panel',
          text: 'Lay the unit face-down on the floor. '
              'Place the thin fibreboard back panel on top, aligning it with the edges. '
              'The smooth side faces outward (toward the wall).\n\n'
              'Nail it in place using the small nails provided. '
              'Start with the four corners, then add nails every 10-15 cm along each edge and along the dividers. '
              'The back panel is critical for structural rigidity — do not skip nails.',
        )),
      'n10': NodeModel(id: 'n10', type: NodeType.task, name: 'Wall Mount', rect: _task(_cx, _row(7)),
        content: TaskContent(
          title: 'Secure to the Wall',
          text: 'IMPORTANT: KALLAX units MUST be anchored to the wall to prevent tipping.\n\n'
              'Stand the unit upright in its final position. '
              'Use the included L-bracket: attach one side to the top-back of the unit with the provided screw, '
              'then mark the wall position through the other hole.\n\n'
              'Drill into the wall using the appropriate anchor for your wall type '
              '(drywall anchor included — use masonry anchors for concrete). '
              'Secure the bracket to the wall. Test by gently pulling the unit forward — it should not move.',
        )),
      'n11': NodeModel(id: 'n11', type: NodeType.endEvent, name: 'Done', rect: _event(_cx, _row(8))),
    };
    final edges = <String, EdgeModel>{
      'e1': EdgeModel(id: 'e1', sourceId: 'n1',  targetId: 'n2'),
      'e2': EdgeModel(id: 'e2', sourceId: 'n2',  targetId: 'n3'),
      'e3': EdgeModel(id: 'e3', sourceId: 'n3',  targetId: 'n4'),
      'e4': EdgeModel(id: 'e4', sourceId: 'n4',  targetId: 'n5',  name: 'No',
        waypoints: [
          Offset(_cx, _row(3)),                        // gateway center
          Offset(_cx, _row(3) + _rowH * 0.35),        // down from gateway
          Offset(_cx + _branchX, _row(3) + _rowH * 0.35), // right
          Offset(_cx + _branchX, _row(4)),             // down to task
        ]),
      'e5': EdgeModel(id: 'e5', sourceId: 'n4',  targetId: 'n7',  name: 'Yes'),
      'e6': EdgeModel(id: 'e6', sourceId: 'n5',  targetId: 'n6'),
      'e7': EdgeModel(id: 'e7', sourceId: 'n7',  targetId: 'n8'),
      'e8': EdgeModel(id: 'e8', sourceId: 'n8',  targetId: 'n9'),
      'e9': EdgeModel(id: 'e9', sourceId: 'n9',  targetId: 'n10'),
      'e10': EdgeModel(id: 'e10', sourceId: 'n10', targetId: 'n11'),
    };
    return DiagramModel(nodes: nodes, edges: edges);
  }

  /// Content showcase: every card variation in one flow.
  static DiagramModel contentShowcase() {
    const img = 'assets/sample_image.jpg';
    const video = 'assets/sample_video_3.mp4';

    const longText =
        'This is a detailed description that exceeds 200 characters to trigger '
        'the "tap to read more" behaviour in the presentation view. '
        'It contains multiple paragraphs worth of content so we can verify '
        'the scrollable text modal works correctly when tapped.\n\n'
        'The second paragraph continues with additional details about the task, '
        'ensuring the text is long enough to overflow the card.';

    final farLeft = _cx - _branchX * 2;
    final left = _cx - _branchX;
    final right = _cx + _branchX;
    final farRight = _cx + _branchX * 2;

    final nodes = <String, NodeModel>{
      // Row 0: Start
      'n1': NodeModel(id: 'n1', type: NodeType.startEvent,
          name: 'Start', rect: _event(_cx, _row(0))),

      // Row 1: Title only
      'n2': NodeModel(id: 'n2', type: NodeType.task,
          name: 'Title Only', rect: _task(_cx, _row(1)),
          content: TaskContent(title: 'Welcome to the Training')),

      // Row 2: Title + short text
      'n3': NodeModel(id: 'n3', type: NodeType.task,
          name: 'Title + Text', rect: _task(_cx, _row(2)),
          content: TaskContent(
            title: 'Safety Briefing',
            text: 'Review the safety guidelines before proceeding. '
                'Ensure all protective equipment is available.',
          )),

      // Row 3: Gateway — "What format?"
      'n4': NodeModel(id: 'n4', type: NodeType.exclusiveGateway,
          name: 'What format?', rect: _gw(_cx, _row(3))),

      // Row 4: Three branches
      'n5': NodeModel(id: 'n5', type: NodeType.task,
          name: 'Read Instructions', rect: _task(left, _row(4)),
          content: TaskContent(
            title: 'Detailed Written Guide',
            text: longText,
          )),
      'n6': NodeModel(id: 'n6', type: NodeType.task,
          name: 'View Photo', rect: _task(_cx, _row(4)),
          content: TaskContent(
            title: 'Visual Reference',
            text: 'Check the image below for correct positioning.',
            imagePath: img,
          )),
      'n7': NodeModel(id: 'n7', type: NodeType.task,
          name: 'Watch Video', rect: _task(right, _row(4)),
          content: TaskContent(
            title: 'Video Demonstration',
            text: 'Watch the full procedure before attempting it yourself.',
            videoPath: video,
          )),
      'n7a': NodeModel(id: 'n7a', type: NodeType.task,
          name: 'Safety Overview', rect: _task(right, _row(5)),
          content: TaskContent(
            title: 'Safety Overview',
            videoPath: 'assets/sample_video_1.mp4',
          )),
      'n7b': NodeModel(id: 'n7b', type: NodeType.task,
          name: 'Assembly Steps', rect: _task(right, _row(6)),
          content: TaskContent(
            title: 'Step-by-Step Assembly',
            videoPath: 'assets/sample_video_2.mp4',
          )),
      'n7c': NodeModel(id: 'n7c', type: NodeType.task,
          name: 'Final Inspection', rect: _task(right, _row(7)),
          content: TaskContent(
            title: 'Final Inspection',
            text: 'Verify all connections are secure.',
            videoPath: 'assets/sample_video_3.mp4',
          )),

      // Image gallery branch
      'n13': NodeModel(id: 'n13', type: NodeType.task,
          name: 'Machine Overview', rect: _task(farLeft, _row(4)),
          content: TaskContent(
            title: 'Machine Overview',
            imagePath: 'assets/machine_1.jpg',
          )),
      'n13a': NodeModel(id: 'n13a', type: NodeType.task,
          name: 'Compressor Detail', rect: _task(farLeft, _row(5)),
          content: TaskContent(
            title: 'Compressor Detail',
            imagePath: 'assets/machine_2.png',
          )),
      'n13b': NodeModel(id: 'n13b', type: NodeType.task,
          name: 'Parts Diagram', rect: _task(farLeft, _row(6)),
          content: TaskContent(
            title: 'Parts Diagram',
            imagePath: 'assets/machine_3.png',
          )),

      // Text + PDF links branch
      'n14': NodeModel(id: 'n14', type: NodeType.task,
          name: 'Documentation', rect: _task(farRight, _row(4)),
          content: TaskContent(
            title: 'Technical Documentation',
            text: 'Download the relevant manuals and specification sheets '
                'for your equipment model.',
            links: const [
              DocLink(url: 'manual.pdf', label: 'Installation Manual',
                  subtitle: 'PDF · 2.4 MB'),
              DocLink(url: 'specs.pdf', label: 'Technical Specifications',
                  subtitle: 'PDF · 1.1 MB'),
              DocLink(url: 'quickstart.pdf', label: 'Quick Start Guide',
                  subtitle: 'PDF · 680 KB'),
            ],
          )),
      'n14a': NodeModel(id: 'n14a', type: NodeType.task,
          name: 'Safety Sheets', rect: _task(farRight, _row(5)),
          content: TaskContent(
            title: 'Safety Data Sheets',
            text: 'Review the safety data sheets for all chemicals and '
                'materials used in the manufacturing process.',
            links: const [
              DocLink(url: 'sds-coolant.pdf', label: 'SDS — Coolant Fluid',
                  subtitle: 'PDF · 340 KB'),
              DocLink(url: 'sds-lubricant.pdf', label: 'SDS — Lubricant Oil',
                  subtitle: 'PDF · 290 KB'),
              DocLink(url: 'sds-cleaning.pdf', label: 'SDS — Cleaning Agent',
                  subtitle: 'PDF · 310 KB'),
              DocLink(url: 'risk-assessment.pdf', label: 'Risk Assessment Report',
                  subtitle: 'PDF · 1.8 MB'),
            ],
          )),
      'n14b': NodeModel(id: 'n14b', type: NodeType.task,
          name: 'Compliance Docs', rect: _task(farRight, _row(6)),
          content: TaskContent(
            title: 'Compliance Documents',
            text: 'Ensure all regulatory compliance documents are signed '
                'and filed before proceeding with the installation.',
            links: const [
              DocLink(url: 'ce-declaration.pdf', label: 'CE Declaration of Conformity',
                  subtitle: 'PDF · 520 KB'),
              DocLink(url: 'iso-cert.pdf', label: 'ISO 9001 Certificate',
                  subtitle: 'PDF · 180 KB'),
              DocLink(url: 'warranty.pdf', label: 'Warranty Terms',
                  subtitle: 'PDF · 95 KB'),
            ],
          )),

      // Row 9: Merge task (extra gap to avoid lines crossing branch nodes)
      'n8': NodeModel(id: 'n8', type: NodeType.task,
          name: 'Confirm Understanding', rect: _task(_cx, _row(9)),
          content: TaskContent(
            title: 'Knowledge Check',
            imagePath: img,
          )),

      // Row 10: Gateway — "Need more info?"
      'n9': NodeModel(id: 'n9', type: NodeType.exclusiveGateway,
          name: 'Need more info?', rect: _gw(_cx, _row(10))),

      // Row 11: Two branches
      'n10': NodeModel(id: 'n10', type: NodeType.task,
          name: 'Open Manual', rect: _task(left, _row(11)),
          content: TaskContent(
            title: 'Reference Manual',
            text: 'Full documentation with diagrams and specifications.',
            imagePath: img,
            linkUrl: 'https://example.com/manual',
            linkLabel: 'Open Manual PDF',
          )),
      'n11': NodeModel(id: 'n11', type: NodeType.task,
          name: 'Proceed', rect: _task(right, _row(11)),
          content: TaskContent(
            title: 'All Clear',
            text: 'You have completed the training module successfully.',
          )),

      // Row 12: End
      'n12': NodeModel(id: 'n12', type: NodeType.endEvent,
          name: 'Complete', rect: _event(_cx, _row(12))),
    };

    final edges = <String, EdgeModel>{
      'e1':  EdgeModel(id: 'e1',  sourceId: 'n1',  targetId: 'n2'),
      'e2':  EdgeModel(id: 'e2',  sourceId: 'n2',  targetId: 'n3'),
      'e3':  EdgeModel(id: 'e3',  sourceId: 'n3',  targetId: 'n4'),
      // 5-way split from gateway
      'e4':  EdgeModel(id: 'e4',  sourceId: 'n4',  targetId: 'n13', name: 'Gallery',
          waypoints: _hv(_cx, _row(3), farLeft, _row(4))),
      'e4b': EdgeModel(id: 'e4b', sourceId: 'n4',  targetId: 'n5',  name: 'Text',
          waypoints: _hv(_cx, _row(3), left, _row(4))),
      'e5':  EdgeModel(id: 'e5',  sourceId: 'n4',  targetId: 'n6',  name: 'Image'),
      'e6':  EdgeModel(id: 'e6',  sourceId: 'n4',  targetId: 'n7',  name: 'Video',
          waypoints: _hv(_cx, _row(3), right, _row(4))),
      'e4c': EdgeModel(id: 'e4c', sourceId: 'n4',  targetId: 'n14', name: 'PDFs',
          waypoints: _hv(_cx, _row(3), farRight, _row(4))),
      // Image gallery chain: n13 → n13a → n13b
      'e13a': EdgeModel(id: 'e13a', sourceId: 'n13',  targetId: 'n13a'),
      'e13b': EdgeModel(id: 'e13b', sourceId: 'n13a', targetId: 'n13b'),
      // Video branch chain: n7 → n7a → n7b → n7c
      'e6a': EdgeModel(id: 'e6a', sourceId: 'n7',  targetId: 'n7a'),
      'e6b': EdgeModel(id: 'e6b', sourceId: 'n7a', targetId: 'n7b'),
      'e6c': EdgeModel(id: 'e6c', sourceId: 'n7b', targetId: 'n7c'),
      // PDF branch chain: n14 → n14a → n14b
      'e14a': EdgeModel(id: 'e14a', sourceId: 'n14',  targetId: 'n14a'),
      'e14b': EdgeModel(id: 'e14b', sourceId: 'n14a', targetId: 'n14b'),
      // 5-way merge
      'e7':  EdgeModel(id: 'e7',  sourceId: 'n13b', targetId: 'n8',
          waypoints: _vh(farLeft, _row(6), _cx, _row(9))),
      'e7b': EdgeModel(id: 'e7b', sourceId: 'n5',   targetId: 'n8',
          waypoints: _vh(left, _row(4), _cx, _row(9))),
      'e8':  EdgeModel(id: 'e8',  sourceId: 'n6',   targetId: 'n8',
          waypoints: _vh(_cx, _row(4), _cx, _row(9))),
      'e9':  EdgeModel(id: 'e9',  sourceId: 'n7c',  targetId: 'n8',
          waypoints: _vh(right, _row(7), _cx, _row(9))),
      'e9b': EdgeModel(id: 'e9b', sourceId: 'n14b', targetId: 'n8',
          waypoints: _vh(farRight, _row(6), _cx, _row(9))),
      // Second gateway
      'e10': EdgeModel(id: 'e10', sourceId: 'n8',  targetId: 'n9'),
      'e11': EdgeModel(id: 'e11', sourceId: 'n9',  targetId: 'n10', name: 'Yes',
          waypoints: _hv(_cx, _row(10), left, _row(11))),
      'e12': EdgeModel(id: 'e12', sourceId: 'n9',  targetId: 'n11', name: 'No',
          waypoints: _hv(_cx, _row(10), right, _row(11))),
      // Both paths to end
      'e13': EdgeModel(id: 'e13', sourceId: 'n10', targetId: 'n12',
          waypoints: _hv(left, _row(11), _cx, _row(12))),
      'e14': EdgeModel(id: 'e14', sourceId: 'n11', targetId: 'n12',
          waypoints: _hv(right, _row(11), _cx, _row(12))),
    };

    return DiagramModel(nodes: nodes, edges: edges);
  }

  // ── Additional tutorial samples ──────────────────────────────

  /// Coffee Brewing Guide: Start -> Boil Water -> Grind Beans -> Brew -> Serve -> End
  static DiagramModel coffeeBrewing() {
    final nodes = <String, NodeModel>{
      'n1': NodeModel(id: 'n1', type: NodeType.startEvent, name: 'Start', rect: _event(_cx, _row(0))),
      'n2': NodeModel(id: 'n2', type: NodeType.task, name: 'Boil Water', rect: _task(_cx, _row(1)),
          content: TaskContent(title: 'Boil Water', text: 'Heat filtered water to 96°C (205°F). Avoid boiling.',
              videoPath: 'assets/sample_video_1.mp4')),
      'n3': NodeModel(id: 'n3', type: NodeType.task, name: 'Grind Beans', rect: _task(_cx, _row(2)),
          content: TaskContent(title: 'Grind Beans', text: 'Use medium-coarse grind. 15g per 250ml water.',
              imagePath: 'assets/sample_image.jpg')),
      'n4': NodeModel(id: 'n4', type: NodeType.task, name: 'Brew', rect: _task(_cx, _row(3)),
          content: TaskContent(title: 'Brew Coffee', text: 'Pour water over grounds in circular motion. Wait 4 minutes.',
              videoPath: 'assets/sample_video_2.mp4')),
      'n5': NodeModel(id: 'n5', type: NodeType.task, name: 'Serve', rect: _task(_cx, _row(4)),
          content: TaskContent(title: 'Serve', text: 'Pour into pre-warmed mug. Add milk or sugar to taste.')),
      'n6': NodeModel(id: 'n6', type: NodeType.endEvent, name: 'Enjoy', rect: _event(_cx, _row(5))),
    };
    final edges = <String, EdgeModel>{
      'e1': EdgeModel(id: 'e1', sourceId: 'n1', targetId: 'n2'),
      'e2': EdgeModel(id: 'e2', sourceId: 'n2', targetId: 'n3'),
      'e3': EdgeModel(id: 'e3', sourceId: 'n3', targetId: 'n4'),
      'e4': EdgeModel(id: 'e4', sourceId: 'n4', targetId: 'n5'),
      'e5': EdgeModel(id: 'e5', sourceId: 'n5', targetId: 'n6'),
    };
    return DiagramModel(nodes: nodes, edges: edges);
  }

  /// Flat Tire Repair: linear with a decision branch
  static DiagramModel flatTireRepair() {
    const left = _cx - _branchX;
    const right = _cx + _branchX;
    final nodes = <String, NodeModel>{
      'n1': NodeModel(id: 'n1', type: NodeType.startEvent, name: 'Flat Tire', rect: _event(_cx, _row(0))),
      'n2': NodeModel(id: 'n2', type: NodeType.task, name: 'Pull Over Safely', rect: _task(_cx, _row(1)),
          content: TaskContent(title: 'Pull Over', text: 'Move to a safe spot away from traffic. Turn on hazard lights.')),
      'n3': NodeModel(id: 'n3', type: NodeType.exclusiveGateway, name: 'Have spare?', rect: _gw(_cx, _row(2))),
      'n4': NodeModel(id: 'n4', type: NodeType.task, name: 'Change Tire', rect: _task(left, _row(3)),
          content: TaskContent(title: 'Change Tire', text: 'Loosen lugs, jack up car, swap tire, lower and tighten.')),
      'n5': NodeModel(id: 'n5', type: NodeType.task, name: 'Call Roadside', rect: _task(right, _row(3)),
          content: TaskContent(title: 'Call Roadside Assistance', text: 'Share your location and wait in a safe spot.')),
      'n6': NodeModel(id: 'n6', type: NodeType.task, name: 'Drive to Shop', rect: _task(_cx, _row(4)),
          content: TaskContent(title: 'Visit Tire Shop', text: 'Drive slowly on the spare (max 80 km/h) to get a replacement.')),
      'n7': NodeModel(id: 'n7', type: NodeType.endEvent, name: 'Done', rect: _event(_cx, _row(5))),
    };
    final edges = <String, EdgeModel>{
      'e1': EdgeModel(id: 'e1', sourceId: 'n1', targetId: 'n2'),
      'e2': EdgeModel(id: 'e2', sourceId: 'n2', targetId: 'n3'),
      'e3': EdgeModel(id: 'e3', sourceId: 'n3', targetId: 'n4', name: 'Yes',
          waypoints: _hv(_cx, _row(2), left, _row(3))),
      'e4': EdgeModel(id: 'e4', sourceId: 'n3', targetId: 'n5', name: 'No',
          waypoints: _hv(_cx, _row(2), right, _row(3))),
      'e5': EdgeModel(id: 'e5', sourceId: 'n4', targetId: 'n6',
          waypoints: _hv(left, _row(3), _cx, _row(4))),
      'e6': EdgeModel(id: 'e6', sourceId: 'n5', targetId: 'n6',
          waypoints: _hv(right, _row(3), _cx, _row(4))),
      'e7': EdgeModel(id: 'e7', sourceId: 'n6', targetId: 'n7'),
    };
    return DiagramModel(nodes: nodes, edges: edges);
  }

  /// Plant Care Routine: watering schedule with season check
  static DiagramModel plantCare() {
    const left = _cx - _branchX;
    const right = _cx + _branchX;
    final nodes = <String, NodeModel>{
      'n1': NodeModel(id: 'n1', type: NodeType.startEvent, name: 'Check Plant', rect: _event(_cx, _row(0))),
      'n2': NodeModel(id: 'n2', type: NodeType.task, name: 'Check Soil', rect: _task(_cx, _row(1)),
          content: TaskContent(title: 'Check Soil Moisture', text: 'Push your finger 2cm into the soil. If dry, water is needed.')),
      'n3': NodeModel(id: 'n3', type: NodeType.exclusiveGateway, name: 'Soil dry?', rect: _gw(_cx, _row(2))),
      'n4': NodeModel(id: 'n4', type: NodeType.task, name: 'Water Plant', rect: _task(left, _row(3)),
          content: TaskContent(title: 'Water Thoroughly', text: 'Water until it drains from the bottom. Empty saucer after 30 min.')),
      'n5': NodeModel(id: 'n5', type: NodeType.task, name: 'Skip Watering', rect: _task(right, _row(3)),
          content: TaskContent(title: 'No Water Needed', text: 'Soil is still moist. Check again in 2-3 days.')),
      'n6': NodeModel(id: 'n6', type: NodeType.task, name: 'Check Light', rect: _task(_cx, _row(4)),
          content: TaskContent(title: 'Adjust Light', text: 'Rotate plant quarter-turn for even growth. Move if leaves yellow.')),
      'n7': NodeModel(id: 'n7', type: NodeType.endEvent, name: 'Done', rect: _event(_cx, _row(5))),
    };
    final edges = <String, EdgeModel>{
      'e1': EdgeModel(id: 'e1', sourceId: 'n1', targetId: 'n2'),
      'e2': EdgeModel(id: 'e2', sourceId: 'n2', targetId: 'n3'),
      'e3': EdgeModel(id: 'e3', sourceId: 'n3', targetId: 'n4', name: 'Yes',
          waypoints: _hv(_cx, _row(2), left, _row(3))),
      'e4': EdgeModel(id: 'e4', sourceId: 'n3', targetId: 'n5', name: 'No',
          waypoints: _hv(_cx, _row(2), right, _row(3))),
      'e5': EdgeModel(id: 'e5', sourceId: 'n4', targetId: 'n6',
          waypoints: _hv(left, _row(3), _cx, _row(4))),
      'e6': EdgeModel(id: 'e6', sourceId: 'n5', targetId: 'n6',
          waypoints: _hv(right, _row(3), _cx, _row(4))),
      'e7': EdgeModel(id: 'e7', sourceId: 'n6', targetId: 'n7'),
    };
    return DiagramModel(nodes: nodes, edges: edges);
  }

  // ── Additional technical samples ────────────────────────────

  /// Git Merge Conflict Resolution
  static DiagramModel gitMergeConflict() {
    const left = _cx - _branchX;
    const right = _cx + _branchX;
    final nodes = <String, NodeModel>{
      'n1': NodeModel(id: 'n1', type: NodeType.startEvent, name: 'Conflict', rect: _event(_cx, _row(0))),
      'n2': NodeModel(id: 'n2', type: NodeType.task, name: 'Identify Files', rect: _task(_cx, _row(1)),
          content: TaskContent(title: 'Identify Conflicting Files', text: 'Run git status to see files with merge conflicts.')),
      'n3': NodeModel(id: 'n3', type: NodeType.task, name: 'Open Diff', rect: _task(_cx, _row(2)),
          content: TaskContent(title: 'Review the Diff', text: 'Look for <<<<<<< HEAD markers. Understand both sides of the change.')),
      'n4': NodeModel(id: 'n4', type: NodeType.exclusiveGateway, name: 'Simple fix?', rect: _gw(_cx, _row(3))),
      'n5': NodeModel(id: 'n5', type: NodeType.task, name: 'Edit Manually', rect: _task(left, _row(4)),
          content: TaskContent(title: 'Manual Resolution', text: 'Keep the correct code, remove conflict markers, test.')),
      'n6': NodeModel(id: 'n6', type: NodeType.task, name: 'Use Merge Tool', rect: _task(right, _row(4)),
          content: TaskContent(title: 'Visual Merge Tool', text: 'Use VS Code or IntelliJ merge tool for complex conflicts.')),
      'n7': NodeModel(id: 'n7', type: NodeType.task, name: 'Test & Commit', rect: _task(_cx, _row(5)),
          content: TaskContent(title: 'Test & Commit', text: 'Run tests, then git add and git commit to finalize the merge.')),
      'n8': NodeModel(id: 'n8', type: NodeType.endEvent, name: 'Resolved', rect: _event(_cx, _row(6))),
    };
    final edges = <String, EdgeModel>{
      'e1': EdgeModel(id: 'e1', sourceId: 'n1', targetId: 'n2'),
      'e2': EdgeModel(id: 'e2', sourceId: 'n2', targetId: 'n3'),
      'e3': EdgeModel(id: 'e3', sourceId: 'n3', targetId: 'n4'),
      'e4': EdgeModel(id: 'e4', sourceId: 'n4', targetId: 'n5', name: 'Yes',
          waypoints: _hv(_cx, _row(3), left, _row(4))),
      'e5': EdgeModel(id: 'e5', sourceId: 'n4', targetId: 'n6', name: 'No',
          waypoints: _hv(_cx, _row(3), right, _row(4))),
      'e6': EdgeModel(id: 'e6', sourceId: 'n5', targetId: 'n7',
          waypoints: _hv(left, _row(4), _cx, _row(5))),
      'e7': EdgeModel(id: 'e7', sourceId: 'n6', targetId: 'n7',
          waypoints: _hv(right, _row(4), _cx, _row(5))),
      'e8': EdgeModel(id: 'e8', sourceId: 'n7', targetId: 'n8'),
    };
    return DiagramModel(nodes: nodes, edges: edges);
  }

  /// CI/CD Pipeline: build, test, deploy with rollback
  static DiagramModel cicdPipeline() {
    const left = _cx - _branchX;
    const right = _cx + _branchX;
    final nodes = <String, NodeModel>{
      'n1': NodeModel(id: 'n1', type: NodeType.startEvent, name: 'Push', rect: _event(_cx, _row(0))),
      'n2': NodeModel(id: 'n2', type: NodeType.task, name: 'Build', rect: _task(_cx, _row(1)),
          content: TaskContent(title: 'Build Artifacts', text: 'Compile code, build Docker image, run linters.')),
      'n3': NodeModel(id: 'n3', type: NodeType.task, name: 'Run Tests', rect: _task(_cx, _row(2)),
          content: TaskContent(title: 'Automated Tests', text: 'Unit tests, integration tests, E2E tests in parallel.')),
      'n4': NodeModel(id: 'n4', type: NodeType.exclusiveGateway, name: 'Tests pass?', rect: _gw(_cx, _row(3))),
      'n5': NodeModel(id: 'n5', type: NodeType.task, name: 'Deploy Staging', rect: _task(left, _row(4)),
          content: TaskContent(title: 'Deploy to Staging', text: 'Push to staging environment. Run smoke tests.')),
      'n6': NodeModel(id: 'n6', type: NodeType.task, name: 'Fix & Retry', rect: _task(right, _row(4)),
          content: TaskContent(title: 'Fix Failures', text: 'Review test logs, fix issues, push again to trigger pipeline.')),
      'n7': NodeModel(id: 'n7', type: NodeType.task, name: 'Deploy Prod', rect: _task(_cx, _row(5)),
          content: TaskContent(title: 'Deploy to Production', text: 'Blue-green deploy with canary rollout. Monitor error rates.')),
      'n8': NodeModel(id: 'n8', type: NodeType.endEvent, name: 'Live', rect: _event(_cx, _row(6))),
    };
    final edges = <String, EdgeModel>{
      'e1': EdgeModel(id: 'e1', sourceId: 'n1', targetId: 'n2'),
      'e2': EdgeModel(id: 'e2', sourceId: 'n2', targetId: 'n3'),
      'e3': EdgeModel(id: 'e3', sourceId: 'n3', targetId: 'n4'),
      'e4': EdgeModel(id: 'e4', sourceId: 'n4', targetId: 'n5', name: 'Yes',
          waypoints: _hv(_cx, _row(3), left, _row(4))),
      'e5': EdgeModel(id: 'e5', sourceId: 'n4', targetId: 'n6', name: 'No',
          waypoints: _hv(_cx, _row(3), right, _row(4))),
      'e6': EdgeModel(id: 'e6', sourceId: 'n5', targetId: 'n7',
          waypoints: _hv(left, _row(4), _cx, _row(5))),
      'e7': EdgeModel(id: 'e7', sourceId: 'n7', targetId: 'n8'),
    };
    return DiagramModel(nodes: nodes, edges: edges);
  }

  /// Database Migration Checklist
  static DiagramModel dbMigration() {
    final nodes = <String, NodeModel>{
      'n1': NodeModel(id: 'n1', type: NodeType.startEvent, name: 'Plan', rect: _event(_cx, _row(0))),
      'n2': NodeModel(id: 'n2', type: NodeType.task, name: 'Backup DB', rect: _task(_cx, _row(1)),
          content: TaskContent(title: 'Create Backup', text: 'Full database dump. Verify backup integrity with restore test.')),
      'n3': NodeModel(id: 'n3', type: NodeType.task, name: 'Run Migration', rect: _task(_cx, _row(2)),
          content: TaskContent(title: 'Execute Migration', text: 'Apply schema changes. Monitor for lock contention on large tables.')),
      'n4': NodeModel(id: 'n4', type: NodeType.task, name: 'Validate Data', rect: _task(_cx, _row(3)),
          content: TaskContent(title: 'Validate Data', text: 'Run integrity checks. Compare row counts and checksums.')),
      'n5': NodeModel(id: 'n5', type: NodeType.task, name: 'Update App', rect: _task(_cx, _row(4)),
          content: TaskContent(title: 'Deploy App Changes', text: 'Deploy app version that uses the new schema. Monitor errors.')),
      'n6': NodeModel(id: 'n6', type: NodeType.endEvent, name: 'Complete', rect: _event(_cx, _row(5))),
    };
    final edges = <String, EdgeModel>{
      'e1': EdgeModel(id: 'e1', sourceId: 'n1', targetId: 'n2'),
      'e2': EdgeModel(id: 'e2', sourceId: 'n2', targetId: 'n3'),
      'e3': EdgeModel(id: 'e3', sourceId: 'n3', targetId: 'n4'),
      'e4': EdgeModel(id: 'e4', sourceId: 'n4', targetId: 'n5'),
      'e5': EdgeModel(id: 'e5', sourceId: 'n5', targetId: 'n6'),
    };
    return DiagramModel(nodes: nodes, edges: edges);
  }

  /// Importing a car from the USA to Germany — regulatory, customs, conversion.
  static DiagramModel carImportUSA() {
    final left = _cx - _branchX;
    final right = _cx + _branchX;
    final nodes = <String, NodeModel>{
      'n1': NodeModel(id: 'n1', type: NodeType.startEvent,
          name: 'Find Your Car', rect: _event(_cx, _row(0))),

      'n2': NodeModel(id: 'n2', type: NodeType.task,
          name: 'Purchase & Title', rect: _task(_cx, _row(1)),
          content: TaskContent(
            title: 'Purchase the Vehicle',
            text: 'Buy the car and ensure you receive a clean title (Certificate of Title). '
                'Get a Bill of Sale with VIN, price, and seller details. '
                'Verify the title is free of liens — German customs will reject cars with open loans. '
                'For classic cars (30+ years), get a Historical Vehicle Declaration from NHTSA.',
          )),

      'n3': NodeModel(id: 'n3', type: NodeType.task,
          name: 'Export from USA', rect: _task(_cx, _row(2)),
          content: TaskContent(
            title: 'US Export & Shipping',
            text: 'File an Electronic Export Information (EEI) via AES if the car is worth over \$2,500. '
                'Choose a shipping method:\n\n'
                '• RoRo (Roll-on/Roll-off) — cheapest, ~\$800–1,500\n'
                '• Container — safer, ~\$1,500–3,000\n'
                '• Air freight — fastest, ~\$5,000+\n\n'
                'Get marine insurance covering the full value. '
                'Shipping takes 3–6 weeks by sea (East Coast to Bremerhaven/Hamburg).',
          )),

      'n4': NodeModel(id: 'n4', type: NodeType.task,
          name: 'Customs Clearance', rect: _task(_cx, _row(3)),
          content: TaskContent(
            title: 'German Customs (Zoll)',
            text: 'When the car arrives in port, file an import declaration with German customs. '
                'You will need:\n\n'
                '• Original title and bill of sale\n'
                '• Shipping documents (Bill of Lading)\n'
                '• Proof of insurance\n'
                '• Your passport or Aufenthaltstitel\n\n'
                'Pay 10% import duty on the purchase price + shipping cost, '
                'then 19% VAT (Einfuhrumsatzsteuer) on top. '
                'Example: \$30,000 car + \$1,500 shipping = €29,500 base → ~€3,000 duty → ~€6,200 VAT.',
          )),

      'n5': NodeModel(id: 'n5', type: NodeType.exclusiveGateway,
          name: 'EU Compliant?', rect: _gw(_cx, _row(4))),

      // Left: Already compliant (rare — e.g., some models sold in both markets)
      'n6': NodeModel(id: 'n6', type: NodeType.task,
          name: 'COC Document', rect: _task(left, _row(5)),
          content: TaskContent(
            title: 'Obtain EU Certificate of Conformity',
            text: 'If the car model was also sold in the EU, the manufacturer may issue a '
                'Certificate of Conformity (COC). Contact the German importer of the brand. '
                'This skips the full Einzelabnahme and saves thousands of euros. '
                'Common for: BMW, Mercedes, Porsche models with EU equivalents.',
          )),

      // Right: Needs conversion (most US cars)
      'n7': NodeModel(id: 'n7', type: NodeType.task,
          name: 'Convert to EU Spec', rect: _task(right, _row(5)),
          content: TaskContent(
            title: 'Technical Conversion',
            text: 'US-spec cars need modifications for German road approval:\n\n'
                '• Headlights — replace sealed beams with E-marked units or re-aim for right-hand traffic\n'
                '• Rear fog light — mandatory in EU, usually missing on US models\n'
                '• Speedometer — must show km/h (not just mph)\n'
                '• Side markers — amber front, red rear reflectors per ECE\n'
                '• Catalytic converter — may need EU-spec cat for emissions compliance\n\n'
                'Use a shop that specializes in US imports (Importfahrzeuge). Budget €1,000–5,000.',
          )),

      // Merge into TÜV
      'n8': NodeModel(id: 'n8', type: NodeType.task,
          name: 'TÜV Inspection', rect: _task(_cx, _row(6)),
          content: TaskContent(
            title: 'Einzelabnahme (TÜV)',
            text: 'Book a Vollabnahme (§21 StVZO) at a TÜV or DEKRA station. '
                'The inspector checks every modification and measures emissions, '
                'noise levels, brakes, and lighting. '
                'Bring all conversion receipts and technical documentation.\n\n'
                'Cost: €150–500 depending on the station and vehicle. '
                'If something fails, you can fix it and return for a re-inspection.',
          )),

      'n9': NodeModel(id: 'n9', type: NodeType.exclusiveGateway,
          name: 'TÜV Passed?', rect: _gw(_cx, _row(7))),

      // Fail — fix and retry
      'n10': NodeModel(id: 'n10', type: NodeType.task,
          name: 'Fix Issues', rect: _task(right, _row(7)),
          content: TaskContent(
            title: 'Address TÜV Deficiencies',
            text: 'The TÜV report lists every deficiency with a severity rating. '
                'Common failures: headlight aim, missing reflectors, emission levels, '
                'rust on structural members, brake performance. '
                'Fix all items and book a Nachprüfung (re-inspection) — usually cheaper than the first visit.',
          )),

      // Pass — register
      'n11': NodeModel(id: 'n11', type: NodeType.task,
          name: 'Register', rect: _task(_cx, _row(8)),
          content: TaskContent(
            title: 'Register at Zulassungsstelle',
            text: 'Go to your local Kfz-Zulassungsstelle with:\n\n'
                '• TÜV report (Prüfbericht)\n'
                '• Customs clearance certificate (Verzollungsnachweis)\n'
                '• Proof of insurance (eVB number from your Kfz-Versicherung)\n'
                '• Your ID and proof of address (Meldebescheinigung)\n'
                '• SEPA mandate for Kfz-Steuer\n\n'
                'You will receive your Fahrzeugschein (Zulassungsbescheinigung Teil I) '
                'and can pick up your license plates. Cost: ~€30 + plates (~€35).',
          )),

      'n12': NodeModel(id: 'n12', type: NodeType.task,
          name: 'Insurance & Tax', rect: _task(_cx, _row(9)),
          content: TaskContent(
            title: 'Insurance & Vehicle Tax',
            text: 'US imports often have higher insurance premiums because parts are harder to source. '
                'Get quotes from multiple insurers — mention the Typschlüsselnummer from TÜV.\n\n'
                'Kfz-Steuer (annual vehicle tax) is based on engine displacement and CO₂ emissions. '
                'Large US V8s can cost €400–800/year. '
                'Classic cars (H-Kennzeichen, 30+ years) get a flat rate of €191/year.',
          )),

      'n13': NodeModel(id: 'n13', type: NodeType.endEvent,
          name: 'On the Road', rect: _event(_cx, _row(10))),
    };
    final edges = <String, EdgeModel>{
      'e1':  EdgeModel(id: 'e1',  sourceId: 'n1',  targetId: 'n2'),
      'e2':  EdgeModel(id: 'e2',  sourceId: 'n2',  targetId: 'n3'),
      'e3':  EdgeModel(id: 'e3',  sourceId: 'n3',  targetId: 'n4'),
      'e4':  EdgeModel(id: 'e4',  sourceId: 'n4',  targetId: 'n5'),
      'e5':  EdgeModel(id: 'e5',  sourceId: 'n5',  targetId: 'n6',  name: 'Yes (COC available)',
        waypoints: _hv(_cx, _row(4), left, _row(5))),
      'e6':  EdgeModel(id: 'e6',  sourceId: 'n5',  targetId: 'n7',  name: 'No (needs conversion)',
        waypoints: _hv(_cx, _row(4), right, _row(5))),
      'e7':  EdgeModel(id: 'e7',  sourceId: 'n6',  targetId: 'n8',
        waypoints: _vh(left, _row(5), _cx, _row(6))),
      'e8':  EdgeModel(id: 'e8',  sourceId: 'n7',  targetId: 'n8',
        waypoints: _vh(right, _row(5), _cx, _row(6))),
      'e9':  EdgeModel(id: 'e9',  sourceId: 'n8',  targetId: 'n9'),
      'e10': EdgeModel(id: 'e10', sourceId: 'n9',  targetId: 'n10', name: 'Fail',
        waypoints: _hv(_cx, _row(7), right, _row(7))),
      'e11': EdgeModel(id: 'e11', sourceId: 'n10', targetId: 'n8',
        waypoints: [Offset(right, _row(7)), Offset(right, _row(6) - 30), Offset(_cx + _taskW / 2 + 10, _row(6) - 30), Offset(_cx + _taskW / 2 + 10, _row(6))]),
      'e12': EdgeModel(id: 'e12', sourceId: 'n9',  targetId: 'n11', name: 'Pass'),
      'e13': EdgeModel(id: 'e13', sourceId: 'n11', targetId: 'n12'),
      'e14': EdgeModel(id: 'e14', sourceId: 'n12', targetId: 'n13'),
    };
    return DiagramModel(nodes: nodes, edges: edges);
  }

  /// FDA 510(k) medical device clearance process.
  static DiagramModel fda510k() {
    final left = _cx - _branchX;
    final right = _cx + _branchX;
    final nodes = <String, NodeModel>{
      'n1': NodeModel(id: 'n1', type: NodeType.startEvent,
          name: 'New Medical Device', rect: _event(_cx, _row(0))),

      'n2': NodeModel(id: 'n2', type: NodeType.task,
          name: 'Device Classification', rect: _task(_cx, _row(1)),
          content: TaskContent(
            title: 'Determine Device Classification',
            text: 'Search the FDA Product Classification Database for your device type. '
                'Most devices fall into Class I (low risk), Class II (moderate risk), '
                'or Class III (high risk).\n\n'
                'Class II devices typically require 510(k) clearance. '
                'Class III devices need a PMA (Pre-Market Approval) — a much longer process. '
                'Identify the product code, regulation number, and review panel.',
          )),

      'n3': NodeModel(id: 'n3', type: NodeType.task,
          name: 'Predicate Device', rect: _task(_cx, _row(2)),
          content: TaskContent(
            title: 'Identify Predicate Device',
            text: 'Find a legally marketed device that is substantially equivalent to yours. '
                'Search the FDA 510(k) database and PMA database.\n\n'
                'The predicate must have:\n'
                '• Same intended use\n'
                '• Same technological characteristics, OR\n'
                '• Different technology but equivalent safety/effectiveness\n\n'
                'A weak predicate is the #1 reason for 510(k) rejection. '
                'Consider using multiple predicates (split predicate strategy).',
          )),

      'n4': NodeModel(id: 'n4', type: NodeType.task,
          name: 'Testing', rect: _task(_cx, _row(3)),
          content: TaskContent(
            title: 'Performance & Safety Testing',
            text: 'Conduct all testing required for substantial equivalence:\n\n'
                '• Biocompatibility (ISO 10993) — cytotoxicity, sensitization, irritation\n'
                '• Electrical safety (IEC 60601-1) for powered devices\n'
                '• EMC testing (IEC 60601-1-2) — electromagnetic compatibility\n'
                '• Software validation (IEC 62304) if device contains software\n'
                '• Sterilization validation (ISO 11135/11137) if applicable\n'
                '• Shelf life / packaging validation\n\n'
                'All testing must be done at accredited laboratories (ISO 17025). '
                'Budget 3–12 months depending on complexity.',
          )),

      'n5': NodeModel(id: 'n5', type: NodeType.task,
          name: 'Prepare Submission', rect: _task(_cx, _row(4)),
          content: TaskContent(
            title: 'Compile 510(k) Submission',
            text: 'Assemble the submission package per FDA guidance:\n\n'
                '1. Cover letter and CDRH Premarket Review Submission Cover Sheet\n'
                '2. Indications for Use Statement\n'
                '3. 510(k) Summary or 510(k) Statement\n'
                '4. Substantial Equivalence Comparison Table\n'
                '5. Device Description (materials, design, principles of operation)\n'
                '6. Performance Testing Results\n'
                '7. Biocompatibility Assessment\n'
                '8. Labeling (IFU, packaging, device labels)\n'
                '9. Sterilization Documentation\n'
                '10. Software Documentation (if applicable)\n\n'
                'Submit electronically via eSTAR. FDA user fee: ~\$21,760 (small business: ~\$5,440).',
          )),

      'n6': NodeModel(id: 'n6', type: NodeType.task,
          name: 'FDA Review', rect: _task(_cx, _row(5)),
          content: TaskContent(
            title: 'FDA Substantive Review',
            text: 'The FDA has 90 days for a standard 510(k) review (often takes longer). '
                'The review goes through stages:\n\n'
                '• Acceptance Review (15 days) — checks completeness\n'
                '• Substantive Review — detailed technical evaluation\n'
                '• Interactive Review — FDA may request additional info (AI letter)\n\n'
                'Respond to Additional Information requests within 180 days or the submission is withdrawn. '
                'Average total review time: 4–6 months.',
          )),

      'n7': NodeModel(id: 'n7', type: NodeType.exclusiveGateway,
          name: 'FDA Decision?', rect: _gw(_cx, _row(6))),

      // Cleared
      'n8': NodeModel(id: 'n8', type: NodeType.task,
          name: 'SE Determination', rect: _task(left, _row(7)),
          content: TaskContent(
            title: 'Substantially Equivalent (SE)',
            text: 'The FDA issues a Substantially Equivalent (SE) letter — your device is cleared! '
                'You receive a 510(k) number (e.g., K231234).\n\n'
                'You can now legally market the device in the US. '
                'List the device in the FDA Establishment Registration database. '
                'Implement your Quality Management System (21 CFR 820) before manufacturing.',
          )),

      // Not cleared
      'n9': NodeModel(id: 'n9', type: NodeType.task,
          name: 'NSE Letter', rect: _task(right, _row(7)),
          content: TaskContent(
            title: 'Not Substantially Equivalent (NSE)',
            text: 'If the FDA determines your device is NSE, you have several options:\n\n'
                '• Request a meeting with the review division to discuss deficiencies\n'
                '• Submit a new 510(k) addressing the issues with stronger data\n'
                '• File a De Novo classification request (for novel low-to-moderate risk devices)\n'
                '• Pursue PMA approval (expensive — \$400K+ in fees alone)\n\n'
                'An NSE does not mean the device is unsafe — it means equivalence was not demonstrated.',
          )),

      // Post-market
      'n10': NodeModel(id: 'n10', type: NodeType.task,
          name: 'Post-Market', rect: _task(left, _row(8)),
          content: TaskContent(
            title: 'Post-Market Surveillance',
            text: 'After clearance, ongoing obligations include:\n\n'
                '• Medical Device Reporting (MDR) — report adverse events within 30 days\n'
                '• Annual registration and device listing\n'
                '• Design change management — some changes require a new 510(k)\n'
                '• FDA facility inspections (typically every 2–3 years)\n'
                '• Maintain complaint handling and CAPA system\n'
                '• Track and report corrections and removals',
          )),

      'n11': NodeModel(id: 'n11', type: NodeType.endEvent,
          name: 'Device on Market', rect: _event(left, _row(9))),

      'n12': NodeModel(id: 'n12', type: NodeType.endEvent,
          name: 'Reassess Strategy', rect: _event(right, _row(8))),
    };
    final edges = <String, EdgeModel>{
      'e1':  EdgeModel(id: 'e1',  sourceId: 'n1',  targetId: 'n2'),
      'e2':  EdgeModel(id: 'e2',  sourceId: 'n2',  targetId: 'n3'),
      'e3':  EdgeModel(id: 'e3',  sourceId: 'n3',  targetId: 'n4'),
      'e4':  EdgeModel(id: 'e4',  sourceId: 'n4',  targetId: 'n5'),
      'e5':  EdgeModel(id: 'e5',  sourceId: 'n5',  targetId: 'n6'),
      'e6':  EdgeModel(id: 'e6',  sourceId: 'n6',  targetId: 'n7'),
      'e7':  EdgeModel(id: 'e7',  sourceId: 'n7',  targetId: 'n8',  name: 'Cleared (SE)',
        waypoints: _hv(_cx, _row(6), left, _row(7))),
      'e8':  EdgeModel(id: 'e8',  sourceId: 'n7',  targetId: 'n9',  name: 'Not Cleared (NSE)',
        waypoints: _hv(_cx, _row(6), right, _row(7))),
      'e9':  EdgeModel(id: 'e9',  sourceId: 'n8',  targetId: 'n10'),
      'e10': EdgeModel(id: 'e10', sourceId: 'n10', targetId: 'n11'),
      'e11': EdgeModel(id: 'e11', sourceId: 'n9',  targetId: 'n12'),
    };
    return DiagramModel(nodes: nodes, edges: edges);
  }

  /// CE Marking for medical devices under EU MDR 2017/745.
  static DiagramModel ceMedicalDevice() {
    final left = _cx - _branchX;
    final right = _cx + _branchX;
    final nodes = <String, NodeModel>{
      'n1': NodeModel(id: 'n1', type: NodeType.startEvent,
          name: 'New Medical Device', rect: _event(_cx, _row(0))),

      'n2': NodeModel(id: 'n2', type: NodeType.task,
          name: 'Classification', rect: _task(_cx, _row(1)),
          content: TaskContent(
            title: 'Device Classification (MDR Annex VIII)',
            text: 'Classify your device using the 22 rules in MDR Annex VIII:\n\n'
                '• Class I — low risk (e.g., bandages, tongue depressors)\n'
                '• Class IIa — low-medium risk (e.g., hearing aids, ultrasound)\n'
                '• Class IIb — medium-high risk (e.g., ventilators, X-ray machines)\n'
                '• Class III — high risk (e.g., heart valves, implants)\n\n'
                'The classification determines which conformity assessment route you must follow '
                'and whether a Notified Body is required (Class IIa and above).',
          )),

      'n3': NodeModel(id: 'n3', type: NodeType.exclusiveGateway,
          name: 'Risk Class?', rect: _gw(_cx, _row(2))),

      // Class I — self-declaration
      'n4': NodeModel(id: 'n4', type: NodeType.task,
          name: 'Self-Declaration', rect: _task(left, _row(3)),
          content: TaskContent(
            title: 'Self-Declaration (Class I)',
            text: 'Class I devices (non-sterile, non-measuring) can self-certify. '
                'You must still:\n\n'
                '• Establish a Quality Management System (ISO 13485)\n'
                '• Create technical documentation per MDR Annex II & III\n'
                '• Conduct a clinical evaluation per MDR Article 61\n'
                '• Draft the EU Declaration of Conformity\n\n'
                'No Notified Body audit is required, but your documentation must be '
                'ready for market surveillance authority inspections at any time.',
          )),

      // Class IIa+ — Notified Body
      'n5': NodeModel(id: 'n5', type: NodeType.task,
          name: 'Select Notified Body', rect: _task(right, _row(3)),
          content: TaskContent(
            title: 'Select a Notified Body',
            text: 'For Class IIa, IIb, and III devices, a Notified Body must audit you.\n\n'
                'Check NANDO database for MDR-designated Notified Bodies. '
                'Major ones: TÜV SÜD, BSI, DEKRA, SGS. '
                'Wait times are currently 12–18 months due to MDR transition bottleneck.\n\n'
                'Submit an application with: device description, classification rationale, '
                'QMS certificate (or ISO 13485 readiness), and intended clinical claims.',
          )),

      // Merge into QMS
      'n6': NodeModel(id: 'n6', type: NodeType.task,
          name: 'QMS (ISO 13485)', rect: _task(_cx, _row(4)),
          content: TaskContent(
            title: 'Quality Management System',
            text: 'Implement ISO 13485 — the foundation of MDR compliance:\n\n'
                '• Design and development controls\n'
                '• Risk management process (ISO 14971)\n'
                '• Supplier and purchasing controls\n'
                '• Production and process validation\n'
                '• CAPA (Corrective and Preventive Actions)\n'
                '• Post-market surveillance procedures\n\n'
                'For Class IIa+, the Notified Body audits your QMS (Annex IX, Chapter I). '
                'The audit covers your facility, processes, and design documentation.',
          )),

      'n7': NodeModel(id: 'n7', type: NodeType.task,
          name: 'Technical Documentation', rect: _task(_cx, _row(5)),
          content: TaskContent(
            title: 'Technical Documentation (Annex II & III)',
            text: 'Create the Technical File covering:\n\n'
                '1. Device description and specification\n'
                '2. Design and manufacturing information\n'
                '3. General Safety and Performance Requirements (GSPR) checklist\n'
                '4. Benefit-risk analysis and risk management (ISO 14971)\n'
                '5. Product verification and validation\n'
                '6. Clinical evaluation report (CER) per MEDDEV 2.7/1 Rev. 4\n'
                '7. Labeling and Instructions for Use (IFU)\n'
                '8. Post-market surveillance plan (PMS)\n'
                '9. Post-market clinical follow-up plan (PMCF)',
          )),

      'n8': NodeModel(id: 'n8', type: NodeType.task,
          name: 'Clinical Evaluation', rect: _task(_cx, _row(6)),
          content: TaskContent(
            title: 'Clinical Evaluation',
            text: 'Demonstrate clinical safety and performance per MDR Article 61:\n\n'
                '• Literature review — systematic search of published clinical data\n'
                '• Equivalence route — demonstrate equivalence to a device with clinical data '
                '(requires contract with the equivalent device manufacturer under MDR)\n'
                '• Clinical investigation — your own clinical study per ISO 14155\n\n'
                'Class III and implantable devices almost always require clinical investigations. '
                'The Clinical Evaluation Report (CER) must be updated at least annually.',
          )),

      'n9': NodeModel(id: 'n9', type: NodeType.exclusiveGateway,
          name: 'Audit Result?', rect: _gw(_cx, _row(7))),

      // Non-conformities
      'n10': NodeModel(id: 'n10', type: NodeType.task,
          name: 'Address Findings', rect: _task(right, _row(7)),
          content: TaskContent(
            title: 'Address Non-Conformities',
            text: 'The Notified Body may issue:\n\n'
                '• Major non-conformities — must be resolved before certificate is issued\n'
                '• Minor non-conformities — must be resolved within an agreed timeframe\n'
                '• Observations — recommendations for improvement\n\n'
                'Provide root cause analysis and corrective action plans (CAPA). '
                'The Notified Body verifies your corrections before proceeding.',
          )),

      // CE Mark
      'n11': NodeModel(id: 'n11', type: NodeType.task,
          name: 'CE Marking', rect: _task(_cx, _row(8)),
          content: TaskContent(
            title: 'Affix CE Mark & Register',
            text: 'Once the Notified Body issues the EU Certificate of Conformity:\n\n'
                '1. Sign the EU Declaration of Conformity (DoC)\n'
                '2. Affix the CE mark to the device and packaging (with NB number for Class IIa+)\n'
                '3. Register in EUDAMED — the EU medical device database\n'
                '4. Assign a Unique Device Identifier (UDI) per MDR Article 27\n'
                '5. Appoint an Authorised Representative if you are outside the EU\n'
                '6. Register with the competent authority in each EU member state where you sell',
          )),

      'n12': NodeModel(id: 'n12', type: NodeType.task,
          name: 'Post-Market', rect: _task(_cx, _row(9)),
          content: TaskContent(
            title: 'Post-Market Surveillance',
            text: 'Ongoing obligations under MDR:\n\n'
                '• Post-Market Surveillance (PMS) plan and reports\n'
                '• Periodic Safety Update Reports (PSUR) — annually for Class IIa+\n'
                '• Post-Market Clinical Follow-up (PMCF) studies\n'
                '• Vigilance reporting — serious incidents within 15 days\n'
                '• Field Safety Corrective Actions (FSCA) when needed\n'
                '• Annual Notified Body surveillance audits\n'
                '• Certificate renewal every 5 years',
          )),

      'n13': NodeModel(id: 'n13', type: NodeType.endEvent,
          name: 'Market Access', rect: _event(_cx, _row(10))),
    };
    final edges = <String, EdgeModel>{
      'e1':  EdgeModel(id: 'e1',  sourceId: 'n1',  targetId: 'n2'),
      'e2':  EdgeModel(id: 'e2',  sourceId: 'n2',  targetId: 'n3'),
      'e3':  EdgeModel(id: 'e3',  sourceId: 'n3',  targetId: 'n4',  name: 'Class I',
        waypoints: _hv(_cx, _row(2), left, _row(3))),
      'e4':  EdgeModel(id: 'e4',  sourceId: 'n3',  targetId: 'n5',  name: 'Class IIa / IIb / III',
        waypoints: _hv(_cx, _row(2), right, _row(3))),
      'e5':  EdgeModel(id: 'e5',  sourceId: 'n4',  targetId: 'n6',
        waypoints: _vh(left, _row(3), _cx, _row(4))),
      'e6':  EdgeModel(id: 'e6',  sourceId: 'n5',  targetId: 'n6',
        waypoints: _vh(right, _row(3), _cx, _row(4))),
      'e7':  EdgeModel(id: 'e7',  sourceId: 'n6',  targetId: 'n7'),
      'e8':  EdgeModel(id: 'e8',  sourceId: 'n7',  targetId: 'n8'),
      'e9':  EdgeModel(id: 'e9',  sourceId: 'n8',  targetId: 'n9'),
      'e10': EdgeModel(id: 'e10', sourceId: 'n9',  targetId: 'n10', name: 'Non-Conformities',
        waypoints: _hv(_cx, _row(7), right, _row(7))),
      'e11': EdgeModel(id: 'e11', sourceId: 'n10', targetId: 'n8',
        waypoints: [Offset(right, _row(7)), Offset(right, _row(6) - 30), Offset(_cx + _taskW / 2 + 10, _row(6) - 30), Offset(_cx + _taskW / 2 + 10, _row(6))]),
      'e12': EdgeModel(id: 'e12', sourceId: 'n9',  targetId: 'n11', name: 'Approved'),
      'e13': EdgeModel(id: 'e13', sourceId: 'n11', targetId: 'n12'),
      'e14': EdgeModel(id: 'e14', sourceId: 'n12', targetId: 'n13'),
    };
    return DiagramModel(nodes: nodes, edges: edges);
  }

  /// ISO 13485 Quality Management System certification for medical devices.
  static DiagramModel iso13485() {
    final right = _cx + _branchX;
    final nodes = <String, NodeModel>{
      'n1': NodeModel(id: 'n1', type: NodeType.startEvent,
          name: 'Certification Kickoff', rect: _event(_cx, _row(0))),

      'n2': NodeModel(id: 'n2', type: NodeType.task,
          name: 'Gap Analysis', rect: _task(_cx, _row(1)),
          content: TaskContent(
            title: 'Gap Analysis',
            text: 'Assess your current quality system against ISO 13485:2016 requirements. '
                'Identify gaps in:\n\n'
                '• Management responsibility and resource allocation\n'
                '• Design and development controls\n'
                '• Purchasing and supplier management\n'
                '• Production and service provision\n'
                '• Monitoring, measurement, and CAPA processes\n\n'
                'Hire a consultant or use an internal auditor with ISO 13485 Lead Auditor certification. '
                'Timeline: 2–4 weeks.',
          )),

      'n3': NodeModel(id: 'n3', type: NodeType.task,
          name: 'Build QMS', rect: _task(_cx, _row(2)),
          content: TaskContent(
            title: 'Implement Quality Management System',
            text: 'Create and implement all required QMS processes:\n\n'
                '• Quality Manual and Quality Policy\n'
                '• Standard Operating Procedures (SOPs)\n'
                '• Work Instructions and Forms\n'
                '• Risk Management File (ISO 14971)\n'
                '• Design History File (DHF) for each device\n'
                '• Document and record control procedures\n'
                '• Training program and competency records\n\n'
                'Timeline: 3–9 months depending on company size and complexity.',
          )),

      'n4': NodeModel(id: 'n4', type: NodeType.task,
          name: 'Internal Audit', rect: _task(_cx, _row(3)),
          content: TaskContent(
            title: 'Internal Audit & Management Review',
            text: 'Conduct at least one full internal audit cycle before the certification audit:\n\n'
                '• Train internal auditors (or hire external auditors)\n'
                '• Audit each process against ISO 13485 clause requirements\n'
                '• Document findings: non-conformities, observations, opportunities\n'
                '• Execute CAPAs for all non-conformities found\n'
                '• Hold a Management Review meeting covering all required inputs\n\n'
                'This is your dress rehearsal — the certification body auditor will review these records.',
          )),

      'n5': NodeModel(id: 'n5', type: NodeType.task,
          name: 'Stage 1 Audit', rect: _task(_cx, _row(4)),
          content: TaskContent(
            title: 'Stage 1 Audit (Documentation Review)',
            text: 'The certification body (e.g., TÜV, BSI, SGS) conducts a Stage 1 audit:\n\n'
                '• Review QMS documentation for adequacy\n'
                '• Verify scope of certification\n'
                '• Confirm readiness for Stage 2\n'
                '• Identify areas of concern\n\n'
                'This may be done on-site or remotely. '
                'The auditor issues a report with any findings to address before Stage 2. '
                'Typical gap: 4–8 weeks between Stage 1 and Stage 2.',
          )),

      'n6': NodeModel(id: 'n6', type: NodeType.task,
          name: 'Stage 2 Audit', rect: _task(_cx, _row(5)),
          content: TaskContent(
            title: 'Stage 2 Audit (On-Site)',
            text: 'The full on-site certification audit:\n\n'
                '• Auditor interviews staff at all levels\n'
                '• Examines records: design files, production logs, complaints, CAPAs\n'
                '• Observes processes: manufacturing, testing, warehousing\n'
                '• Verifies traceability from design input to finished product\n'
                '• Checks regulatory compliance (MDR, FDA QSR as applicable)\n\n'
                'Duration: 2–5 days depending on company size. '
                'Results: certificate issued, or non-conformities requiring closure.',
          )),

      'n7': NodeModel(id: 'n7', type: NodeType.exclusiveGateway,
          name: 'Audit Result?', rect: _gw(_cx, _row(6))),

      // Major NCs
      'n8': NodeModel(id: 'n8', type: NodeType.task,
          name: 'Close NCs', rect: _task(right, _row(6)),
          content: TaskContent(
            title: 'Close Non-Conformities',
            text: 'Major non-conformities must be closed within 90 days (typically). '
                'For each NC:\n\n'
                '1. Root cause analysis (5 Whys, Fishbone, etc.)\n'
                '2. Immediate correction\n'
                '3. Corrective action to prevent recurrence\n'
                '4. Effectiveness verification\n\n'
                'Submit evidence to the certification body. '
                'A follow-up audit may be required for major findings.',
          )),

      // Certificate issued
      'n9': NodeModel(id: 'n9', type: NodeType.task,
          name: 'Certificate Issued', rect: _task(_cx, _row(7)),
          content: TaskContent(
            title: 'ISO 13485 Certificate Issued',
            text: 'The certification body issues your ISO 13485:2016 certificate, '
                'valid for 3 years.\n\n'
                'The certificate scope specifies: design, manufacturing, distribution, '
                'and/or servicing of specific device types. '
                'This certificate is recognized by MDSAP member countries '
                '(USA, Canada, Australia, Japan, Brazil).',
          )),

      'n10': NodeModel(id: 'n10', type: NodeType.task,
          name: 'Surveillance Audits', rect: _task(_cx, _row(8)),
          content: TaskContent(
            title: 'Annual Surveillance Audits',
            text: 'The certification body conducts annual surveillance audits (Year 1 and Year 2). '
                'These are shorter than the initial audit but cover:\n\n'
                '• Follow-up on previous findings\n'
                '• Sampling of QMS processes\n'
                '• Review of changes since last audit\n'
                '• Complaint and CAPA trends\n'
                '• Management Review outputs\n\n'
                'In Year 3: full re-certification audit (similar to Stage 2).',
          )),

      'n11': NodeModel(id: 'n11', type: NodeType.endEvent,
          name: 'Certified', rect: _event(_cx, _row(9))),
    };
    final edges = <String, EdgeModel>{
      'e1':  EdgeModel(id: 'e1',  sourceId: 'n1',  targetId: 'n2'),
      'e2':  EdgeModel(id: 'e2',  sourceId: 'n2',  targetId: 'n3'),
      'e3':  EdgeModel(id: 'e3',  sourceId: 'n3',  targetId: 'n4'),
      'e4':  EdgeModel(id: 'e4',  sourceId: 'n4',  targetId: 'n5'),
      'e5':  EdgeModel(id: 'e5',  sourceId: 'n5',  targetId: 'n6'),
      'e6':  EdgeModel(id: 'e6',  sourceId: 'n6',  targetId: 'n7'),
      'e7':  EdgeModel(id: 'e7',  sourceId: 'n7',  targetId: 'n8',  name: 'Non-Conformities',
        waypoints: _hv(_cx, _row(6), right, _row(6))),
      'e8':  EdgeModel(id: 'e8',  sourceId: 'n8',  targetId: 'n6',
        waypoints: [Offset(right, _row(6)), Offset(right, _row(5) - 30), Offset(_cx + _taskW / 2 + 10, _row(5) - 30), Offset(_cx + _taskW / 2 + 10, _row(5))]),
      'e9':  EdgeModel(id: 'e9',  sourceId: 'n7',  targetId: 'n9',  name: 'Passed'),
      'e10': EdgeModel(id: 'e10', sourceId: 'n9',  targetId: 'n10'),
      'e11': EdgeModel(id: 'e11', sourceId: 'n10', targetId: 'n11'),
    };
    return DiagramModel(nodes: nodes, edges: edges);
  }

  // ── Creators ─────────────────────────────────────────────────

  static const _creators = <String, SampleCreator>{
    'maria': SampleCreator(
      id: 'maria',
      name: 'Maria Chen',
      initials: 'MC',
      colorValue: 0xFF5C6BC0,
      bio: 'Process engineer at a Fortune 500 manufacturing company. '
          'Passionate about lean operations and visual work instructions. '
          '12 years of experience in industrial process design.',
      followers: 2340,
    ),
    'alex': SampleCreator(
      id: 'alex',
      name: 'Alex Rivera',
      initials: 'AR',
      colorValue: 0xFF26A69A,
      bio: 'Senior software engineer and DevOps advocate. '
          'Writes about debugging strategies, CI/CD pipelines, and '
          'engineering best practices. Speaker at QCon and StrangeLoop.',
      followers: 5120,
    ),
    'sam': SampleCreator(
      id: 'sam',
      name: 'Sam Kowalski',
      initials: 'SK',
      colorValue: 0xFFEF5350,
      bio: 'Agile coach helping teams ship better software. '
          'Certified Scrum Master and SAFe Program Consultant. '
          'Creator of workflow templates used by 500+ teams.',
      followers: 8900,
    ),
    'jordan': SampleCreator(
      id: 'jordan',
      name: 'Jordan Patel',
      initials: 'JP',
      colorValue: 0xFFFF7043,
      bio: 'UX researcher and information architect. '
          'Specializes in making complex processes understandable '
          'through visual design and interactive documentation.',
      followers: 1580,
    ),
  };

  /// Text-only content showcase: firefighter emergency response.
  /// Demonstrates different text-only card layouts.
  static DiagramModel textOnly() {
    final left = _cx - _branchX;
    final right = _cx + _branchX;

    final nodes = <String, NodeModel>{
      // Row 0: Start
      'n1': NodeModel(id: 'n1', type: NodeType.startEvent,
          name: 'Alarm Received', rect: _event(_cx, _row(0))),

      // Row 1: Title only — short, punchy command
      'n2': NodeModel(id: 'n2', type: NodeType.task,
          name: 'Don PPE', rect: _task(_cx, _row(1)),
          content: TaskContent(
            title: 'Don Protective Equipment',
          )),

      // Row 2: Title + short text — brief instruction
      'n3': NodeModel(id: 'n3', type: NodeType.task,
          name: 'Size-Up', rect: _task(_cx, _row(2)),
          content: TaskContent(
            title: 'Scene Size-Up',
            text: 'Assess building type, smoke conditions, wind direction, '
                'and number of floors. Report findings to Incident Commander.',
          )),

      // Row 3: Title + numbered list text — checklist style
      'n4': NodeModel(id: 'n4', type: NodeType.task,
          name: 'Establish Command', rect: _task(_cx, _row(3)),
          content: TaskContent(
            title: 'Establish Incident Command',
            text: '1. Identify yourself as IC on radio\n'
                '2. Set up command post upwind\n'
                '3. Request additional resources if needed\n'
                '4. Assign sectors (fire attack, ventilation, RIT)\n'
                '5. Begin personnel accountability report (PAR)',
          )),

      // Row 4: Gateway — fire type decision
      'n5': NodeModel(id: 'n5', type: NodeType.exclusiveGateway,
          name: 'Fire Type?', rect: _gw(_cx, _row(4))),

      // Row 5: Left branch — structural fire (long detailed text)
      'n6': NodeModel(id: 'n6', type: NodeType.task,
          name: 'Structural Fire Attack', rect: _task(left, _row(5)),
          content: TaskContent(
            title: 'Interior Structural Fire Attack',
            text: 'Deploy 1¾" attack line to the seat of the fire. '
                'Maintain crew integrity — always operate in teams of two '
                'or more. Stay low, follow the hose line as your lifeline.\n\n'
                'Search adjacent rooms systematically: right-hand or left-hand '
                'search pattern. Close doors behind you to limit fire spread.\n\n'
                'Monitor air supply continuously. Begin egress with 50% of '
                'your air remaining or at the low-air alarm — whichever comes '
                'first. Never remove your SCBA face piece inside the structure.\n\n'
                'Watch for signs of flashover: darkening smoke, rollover at '
                'ceiling level, intense radiant heat. If conditions deteriorate '
                'rapidly, evacuate immediately and transition to defensive '
                'operations.',
          )),

      // Row 5: Right branch — electrical/vehicle fire (title + short text + link)
      'n7': NodeModel(id: 'n7', type: NodeType.task,
          name: 'Vehicle / Electrical Fire', rect: _task(right, _row(5)),
          content: TaskContent(
            title: 'Vehicle or Electrical Fire',
            text: 'Approach from upwind at 45° angle. Use dry chemical or '
                'CO₂ extinguisher for electrical fires — never use water on '
                'energized equipment.\n\n'
                'For vehicle fires, check for alternative fuel systems (CNG, '
                'LPG, EV batteries). EV battery fires require sustained '
                'water application — 3,000+ gallons minimum.',
            linkUrl: 'https://nfpa.org/ev-fire-response',
            linkLabel: 'NFPA EV Fire Guidelines',
          )),

      // Row 7: Merge — overhaul (extra row gap for branch routing)
      'n8': NodeModel(id: 'n8', type: NodeType.task,
          name: 'Overhaul', rect: _task(_cx, _row(7)),
          content: TaskContent(
            title: 'Overhaul & Salvage',
            text: 'Systematically check for hidden fire extension behind '
                'walls, above ceilings, and below floors using thermal '
                'imaging camera (TIC).\n\n'
                'Open up only what is necessary — preserve the structure '
                'for investigation. Document fire origin and cause indicators '
                'before disturbing the scene.',
          )),

      // Row 8: Title + paragraph — debrief
      'n9': NodeModel(id: 'n9', type: NodeType.task,
          name: 'Debrief', rect: _task(_cx, _row(8)),
          content: TaskContent(
            title: 'Post-Incident Debrief',
            text: 'Conduct a hot debrief within one hour of scene clearance. '
                'Cover what went well, what could improve, and any near-miss '
                'events.\n\n'
                'Check in with all crew members for signs of stress or injury. '
                'CISM resources are available through dispatch 24/7.\n\n'
                'Complete NFIRS report within 24 hours.',
          )),

      // Row 9: End
      'n10': NodeModel(id: 'n10', type: NodeType.endEvent,
          name: 'Scene Secured', rect: _event(_cx, _row(9))),
    };

    final edges = <String, EdgeModel>{
      'e1': EdgeModel(id: 'e1', sourceId: 'n1', targetId: 'n2'),
      'e2': EdgeModel(id: 'e2', sourceId: 'n2', targetId: 'n3'),
      'e3': EdgeModel(id: 'e3', sourceId: 'n3', targetId: 'n4'),
      'e4': EdgeModel(id: 'e4', sourceId: 'n4', targetId: 'n5'),
      'e5': EdgeModel(id: 'e5', sourceId: 'n5', targetId: 'n6', name: 'Structural',
          waypoints: _hv(_cx, _row(4), left, _row(5))),
      'e6': EdgeModel(id: 'e6', sourceId: 'n5', targetId: 'n7', name: 'Vehicle / Electrical',
          waypoints: _hv(_cx, _row(4), right, _row(5))),
      'e7': EdgeModel(id: 'e7', sourceId: 'n6', targetId: 'n8',
          waypoints: _vh(left, _row(5), _cx, _row(7))),
      'e8': EdgeModel(id: 'e8', sourceId: 'n7', targetId: 'n8',
          waypoints: _vh(right, _row(5), _cx, _row(7))),
      'e9': EdgeModel(id: 'e9', sourceId: 'n8', targetId: 'n9'),
      'e10': EdgeModel(id: 'e10', sourceId: 'n9', targetId: 'n10'),
    };

    return DiagramModel(nodes: nodes, edges: edges);
  }

  /// Car configurator: gateway with 10 options to test the options modal.
  static DiagramModel carConfigurator() {
    // 10 color options fan out from a gateway, merge back, then continue.
    // Layout: start → model selection → color gateway → (10 branches) → merge → extras → end.

    final nodes = <String, NodeModel>{
      'n1': NodeModel(id: 'n1', type: NodeType.startEvent,
          name: 'Configure Your Car', rect: _event(_cx, _row(0))),

      'n2': NodeModel(id: 'n2', type: NodeType.task,
          name: 'Choose Model', rect: _task(_cx, _row(1)),
          content: TaskContent(
            title: 'Select Your Model',
            text: 'Browse our lineup and pick the model that fits your lifestyle. '
                'Each model comes with a unique set of standard features.',
          )),

      'n3': NodeModel(id: 'n3', type: NodeType.exclusiveGateway,
          name: 'Exterior Color?', rect: _gw(_cx, _row(2))),

      // 10 color options — all merge into the same next step
      'c1': NodeModel(id: 'c1', type: NodeType.task,
          name: 'Alpine White', rect: _task(_cx, _row(3)),
          content: TaskContent(title: 'Alpine White',
              text: 'A timeless, clean white that highlights the car\'s sculpted lines. Popular for its elegant simplicity and easy maintenance.')),
      'c2': NodeModel(id: 'c2', type: NodeType.task,
          name: 'Jet Black', rect: _task(_cx, _row(3)),
          content: TaskContent(title: 'Jet Black',
              text: 'Deep, mirror-like black finish. Striking presence on the road. Shows fingerprints and swirl marks more easily — requires careful washing.')),
      'c3': NodeModel(id: 'c3', type: NodeType.task,
          name: 'Melbourne Red', rect: _task(_cx, _row(3)),
          content: TaskContent(title: 'Melbourne Red Metallic',
              text: 'A rich, deep red with subtle metallic flake. Sporty and bold — turns heads at every corner.')),
      'c4': NodeModel(id: 'c4', type: NodeType.task,
          name: 'Mineral Grey', rect: _task(_cx, _row(3)),
          content: TaskContent(title: 'Mineral Grey Metallic',
              text: 'Sophisticated dark grey with a warm undertone. Hides dirt well and looks sharp in any lighting condition.')),
      'c5': NodeModel(id: 'c5', type: NodeType.task,
          name: 'Portimao Blue', rect: _task(_cx, _row(3)),
          content: TaskContent(title: 'Portimao Blue Metallic',
              text: 'A deep, saturated blue exclusive to M Sport models. Named after the Portuguese racing circuit — for drivers who mean business.')),
      'c6': NodeModel(id: 'c6', type: NodeType.task,
          name: 'San Remo Green', rect: _task(_cx, _row(3)),
          content: TaskContent(title: 'San Remo Green Metallic',
              text: 'A distinctive heritage green with golden undertones. Inspired by classic motorsport liveries — subtle yet unmistakable.')),
      'c7': NodeModel(id: 'c7', type: NodeType.task,
          name: 'Tanzanite Blue', rect: _task(_cx, _row(3)),
          content: TaskContent(title: 'Tanzanite Blue Metallic',
              text: 'A luxurious deep blue-violet that shifts between blue and purple depending on the light. A rare gemstone on wheels.')),
      'c8': NodeModel(id: 'c8', type: NodeType.task,
          name: 'Frozen Orange', rect: _task(_cx, _row(3)),
          content: TaskContent(title: 'Frozen Orange Metallic',
              text: 'Matte orange finish with a satin texture. An Individual color that demands attention — not for the faint of heart. Special matte care required.')),
      'c9': NodeModel(id: 'c9', type: NodeType.task,
          name: 'Oxide Grey', rect: _task(_cx, _row(3)),
          content: TaskContent(title: 'Oxide Grey Metallic',
              text: 'A warm, earthy grey with bronze undertones. Understated luxury — pairs beautifully with both light and dark interiors.')),
      'c10': NodeModel(id: 'c10', type: NodeType.task,
          name: 'Dravit Grey', rect: _task(_cx, _row(3)),
          content: TaskContent(title: 'Dravit Grey Metallic',
              text: 'A unique brownish-grey that changes character with the light — cool in shade, warm in sun. Named after a rare mineral.')),

      'n4': NodeModel(id: 'n4', type: NodeType.task,
          name: 'Interior & Extras', rect: _task(_cx, _row(4)),
          content: TaskContent(
            title: 'Choose Interior & Extras',
            text: 'Select your interior trim, upholstery, and optional packages:\n\n'
                '- Leather: Vernasca or Merino\n'
                '- Trim: Aluminium, Open-Pore Wood, or Carbon Fibre\n'
                '- Packages: M Sport, Technology, Comfort, Driving Assistant Pro\n'
                '- Wheels: 18" to 21" options available\n'
                '- Audio: Standard, Harman Kardon, or Bowers & Wilkins',
          )),

      'n5': NodeModel(id: 'n5', type: NodeType.task,
          name: 'Review Build', rect: _task(_cx, _row(5)),
          content: TaskContent(
            title: 'Review Your Configuration',
            text: 'Take a final look at your selected options before placing your order. '
                'You can always go back and change any selection.',
          )),

      'n6': NodeModel(id: 'n6', type: NodeType.endEvent,
          name: 'Order Placed', rect: _event(_cx, _row(6))),
    };

    final edges = <String, EdgeModel>{
      'e1': EdgeModel(id: 'e1', sourceId: 'n1', targetId: 'n2'),
      'e2': EdgeModel(id: 'e2', sourceId: 'n2', targetId: 'n3'),
      // 10 color edges from gateway
      'ec1': EdgeModel(id: 'ec1', sourceId: 'n3', targetId: 'c1', name: 'Alpine White'),
      'ec2': EdgeModel(id: 'ec2', sourceId: 'n3', targetId: 'c2', name: 'Jet Black'),
      'ec3': EdgeModel(id: 'ec3', sourceId: 'n3', targetId: 'c3', name: 'Melbourne Red'),
      'ec4': EdgeModel(id: 'ec4', sourceId: 'n3', targetId: 'c4', name: 'Mineral Grey'),
      'ec5': EdgeModel(id: 'ec5', sourceId: 'n3', targetId: 'c5', name: 'Portimao Blue'),
      'ec6': EdgeModel(id: 'ec6', sourceId: 'n3', targetId: 'c6', name: 'San Remo Green'),
      'ec7': EdgeModel(id: 'ec7', sourceId: 'n3', targetId: 'c7', name: 'Tanzanite Blue'),
      'ec8': EdgeModel(id: 'ec8', sourceId: 'n3', targetId: 'c8', name: 'Frozen Orange'),
      'ec9': EdgeModel(id: 'ec9', sourceId: 'n3', targetId: 'c9', name: 'Oxide Grey'),
      'ec10': EdgeModel(id: 'ec10', sourceId: 'n3', targetId: 'c10', name: 'Dravit Grey'),
      // All colors merge into extras
      'em1': EdgeModel(id: 'em1', sourceId: 'c1', targetId: 'n4'),
      'em2': EdgeModel(id: 'em2', sourceId: 'c2', targetId: 'n4'),
      'em3': EdgeModel(id: 'em3', sourceId: 'c3', targetId: 'n4'),
      'em4': EdgeModel(id: 'em4', sourceId: 'c4', targetId: 'n4'),
      'em5': EdgeModel(id: 'em5', sourceId: 'c5', targetId: 'n4'),
      'em6': EdgeModel(id: 'em6', sourceId: 'c6', targetId: 'n4'),
      'em7': EdgeModel(id: 'em7', sourceId: 'c7', targetId: 'n4'),
      'em8': EdgeModel(id: 'em8', sourceId: 'c8', targetId: 'n4'),
      'em9': EdgeModel(id: 'em9', sourceId: 'c9', targetId: 'n4'),
      'em10': EdgeModel(id: 'em10', sourceId: 'c10', targetId: 'n4'),
      // Continue
      'e3': EdgeModel(id: 'e3', sourceId: 'n4', targetId: 'n5'),
      'e4': EdgeModel(id: 'e4', sourceId: 'n5', targetId: 'n6'),
    };

    return DiagramModel(nodes: nodes, edges: edges);
  }

  /// Recipe: pasta from scratch — video-heavy cooking walkthrough.
  static DiagramModel pastaRecipe() {
    final nodes = <String, NodeModel>{
      'n1': NodeModel(id: 'n1', type: NodeType.startEvent,
          name: 'Pasta from Scratch', rect: _event(_cx, _row(0))),

      'n2': NodeModel(id: 'n2', type: NodeType.task,
          name: 'Ingredients', rect: _task(_cx, _row(1)),
          content: TaskContent(
            title: 'Gather Ingredients',
            text: '- 400g "00" flour (or all-purpose)\n'
                '- 4 large eggs\n'
                '- 1 tbsp olive oil\n'
                '- Pinch of salt\n'
                '- Semolina flour for dusting\n\n'
                'For the sauce:\n'
                '- 400g San Marzano tomatoes\n'
                '- 3 cloves garlic\n'
                '- Fresh basil\n'
                '- Parmesan\n'
                '- Salt, pepper, red pepper flakes',
          )),

      'n3': NodeModel(id: 'n3', type: NodeType.task,
          name: 'Make Dough', rect: _task(_cx, _row(2)),
          content: TaskContent(
            title: 'Make the Dough',
            videoPath: 'assets/recipe_video_1.mp4',
          )),

      'n4': NodeModel(id: 'n4', type: NodeType.task,
          name: 'Knead', rect: _task(_cx, _row(3)),
          content: TaskContent(
            title: 'Knead Until Smooth',
            text: 'Knead the dough for 8-10 minutes until it becomes silky '
                'and springs back when poked. Wrap in plastic and rest for '
                '30 minutes at room temperature.',
            videoPath: 'assets/recipe_video_2.mp4',
          )),

      'n5': NodeModel(id: 'n5', type: NodeType.task,
          name: 'Roll & Cut', rect: _task(_cx, _row(4)),
          content: TaskContent(
            title: 'Roll and Cut the Pasta',
            text: 'Divide dough into 4 pieces. Roll each through the pasta '
                'machine starting at the widest setting, narrowing each pass. '
                'Cut into your desired shape — tagliatelle, fettuccine, or pappardelle.',
            videoPath: 'assets/recipe_video_3.mp4',
          )),

      'n6': NodeModel(id: 'n6', type: NodeType.task,
          name: 'Make Sauce', rect: _task(_cx, _row(5)),
          content: TaskContent(
            title: 'Prepare the Sauce',
            videoPath: 'assets/recipe_video_4.mp4',
          )),

      'n7': NodeModel(id: 'n7', type: NodeType.task,
          name: 'Cook Pasta', rect: _task(_cx, _row(6)),
          content: TaskContent(
            title: 'Cook the Fresh Pasta',
            text: 'Bring a large pot of salted water to a rolling boil. '
                'Fresh pasta cooks in just 2-3 minutes — taste for al dente. '
                'Reserve a cup of pasta water before draining.',
          )),

      'n8': NodeModel(id: 'n8', type: NodeType.task,
          name: 'Combine & Serve', rect: _task(_cx, _row(7)),
          content: TaskContent(
            title: 'Toss and Serve',
            text: 'Add the drained pasta directly to the sauce. Toss over '
                'medium heat, adding pasta water a splash at a time until '
                'the sauce clings to every strand. Finish with fresh basil, '
                'a drizzle of olive oil, and grated Parmesan.',
            videoPath: 'assets/recipe_video_5.mp4',
          )),

      'n9': NodeModel(id: 'n9', type: NodeType.endEvent,
          name: 'Buon Appetito!', rect: _event(_cx, _row(8))),
    };

    final edges = <String, EdgeModel>{
      'e1': EdgeModel(id: 'e1', sourceId: 'n1', targetId: 'n2'),
      'e2': EdgeModel(id: 'e2', sourceId: 'n2', targetId: 'n3'),
      'e3': EdgeModel(id: 'e3', sourceId: 'n3', targetId: 'n4'),
      'e4': EdgeModel(id: 'e4', sourceId: 'n4', targetId: 'n5'),
      'e5': EdgeModel(id: 'e5', sourceId: 'n5', targetId: 'n6'),
      'e6': EdgeModel(id: 'e6', sourceId: 'n6', targetId: 'n7'),
      'e7': EdgeModel(id: 'e7', sourceId: 'n7', targetId: 'n8'),
      'e8': EdgeModel(id: 'e8', sourceId: 'n8', targetId: 'n9'),
    };

    return DiagramModel(nodes: nodes, edges: edges);
  }

  /// All sample diagrams with display names and creator info.
  static final List<SampleDiagramEntry> all = [
    SampleDiagramEntry(name: 'Content Showcase', builder: contentShowcase,
        creator: _creators['jordan']!),
    SampleDiagramEntry(name: 'IKEA KALLAX Assembly', builder: ikeaAssembly,
        creator: _creators['maria']!),
    SampleDiagramEntry(name: 'Emergency: Fire Evacuation', builder: emergencyProcedure,
        creator: _creators['maria']!),
    SampleDiagramEntry(name: 'Debug: API 500 Errors', builder: technicalDebugging,
        creator: _creators['alex']!),
    SampleDiagramEntry(name: 'Sprint Cycle', builder: sprintCycle,
        creator: _creators['sam']!),
    SampleDiagramEntry(name: 'Linear Flow', builder: linear,
        creator: _creators['jordan']!),
    SampleDiagramEntry(name: 'Diamond (2 merge)', builder: diamond,
        creator: _creators['jordan']!),
    SampleDiagramEntry(name: 'Three-Way Merge', builder: threeWayMerge,
        creator: _creators['sam']!),
    SampleDiagramEntry(name: 'Double Diamond (2x2 merge)', builder: doubleDiamond,
        creator: _creators['sam']!),
    SampleDiagramEntry(name: 'Four-Way Merge', builder: fourWayMerge,
        creator: _creators['alex']!),
    SampleDiagramEntry(name: 'Coffee Brewing Guide', builder: coffeeBrewing,
        creator: _creators['jordan']!),
    SampleDiagramEntry(name: 'Flat Tire Repair', builder: flatTireRepair,
        creator: _creators['maria']!),
    SampleDiagramEntry(name: 'Plant Care Routine', builder: plantCare,
        creator: _creators['jordan']!),
    SampleDiagramEntry(name: 'Git Merge Conflicts', builder: gitMergeConflict,
        creator: _creators['alex']!),
    SampleDiagramEntry(name: 'CI/CD Pipeline', builder: cicdPipeline,
        creator: _creators['alex']!),
    SampleDiagramEntry(name: 'Database Migration', builder: dbMigration,
        creator: _creators['sam']!),
    SampleDiagramEntry(name: 'Text Only: Fire Response', builder: textOnly,
        creator: _creators['maria']!),
    SampleDiagramEntry(name: 'Car Configurator', builder: carConfigurator,
        creator: _creators['jordan']!),
    SampleDiagramEntry(name: 'Pasta from Scratch', builder: pastaRecipe,
        creator: _creators['maria']!),
    SampleDiagramEntry(name: 'Car Import USA → Germany', builder: carImportUSA,
        creator: _creators['sam']!),
    SampleDiagramEntry(name: 'FDA 510(k) Clearance', builder: fda510k,
        creator: _creators['alex']!),
    SampleDiagramEntry(name: 'CE Marking (EU MDR)', builder: ceMedicalDevice,
        creator: _creators['maria']!),
    SampleDiagramEntry(name: 'ISO 13485 Certification', builder: iso13485,
        creator: _creators['sam']!),
  ];

  /// The current user (for prototype purposes).
  static const currentUser = SampleCreator(
    id: 'me',
    name: 'You',
    initials: 'ME',
    colorValue: 0xFF42A5F5,
    bio: '',
    followers: 0,
  );

  /// Diagrams owned by the current user.
  static final List<SampleDiagramEntry> myDiagrams = [
    SampleDiagramEntry(name: 'My Onboarding Flow', builder: linear,
        creator: currentUser),
    SampleDiagramEntry(name: 'Team Standup Process', builder: diamond,
        creator: currentUser),
    SampleDiagramEntry(name: 'Bug Triage Workflow', builder: threeWayMerge,
        creator: currentUser),
  ];
}

/// Metadata for a sample diagram creator.
class SampleCreator {
  final String id;
  final String name;
  final String initials;
  final int colorValue;
  final String bio;
  final int followers;

  const SampleCreator({
    required this.id,
    required this.name,
    required this.initials,
    required this.colorValue,
    required this.bio,
    required this.followers,
  });
}

/// Entry in the sample diagrams list.
class SampleDiagramEntry {
  final String name;
  final DiagramModel Function() builder;
  final SampleCreator creator;

  const SampleDiagramEntry({
    required this.name,
    required this.builder,
    required this.creator,
  });
}
