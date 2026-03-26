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
    const video = '/tmp/bpmn_sample_video.mp4';

    const longText =
        'This is a detailed description that exceeds 200 characters to trigger '
        'the "tap to read more" behaviour in the presentation view. '
        'It contains multiple paragraphs worth of content so we can verify '
        'the scrollable text modal works correctly when tapped.\n\n'
        'The second paragraph continues with additional details about the task, '
        'ensuring the text is long enough to overflow the card.';

    final left = _cx - _branchX;
    final right = _cx + _branchX;

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

      // Row 6: Merge task (extra gap to avoid lines crossing row-4 nodes)
      'n8': NodeModel(id: 'n8', type: NodeType.task,
          name: 'Confirm Understanding', rect: _task(_cx, _row(6)),
          content: TaskContent(
            title: 'Knowledge Check',
            imagePath: img,
          )),

      // Row 7: Gateway — "Need more info?"
      'n9': NodeModel(id: 'n9', type: NodeType.exclusiveGateway,
          name: 'Need more info?', rect: _gw(_cx, _row(7))),

      // Row 8: Two branches
      'n10': NodeModel(id: 'n10', type: NodeType.task,
          name: 'Open Manual', rect: _task(left, _row(8)),
          content: TaskContent(
            title: 'Reference Manual',
            text: 'Full documentation with diagrams and specifications.',
            imagePath: img,
            linkUrl: 'https://example.com/manual',
            linkLabel: 'Open Manual PDF',
          )),
      'n11': NodeModel(id: 'n11', type: NodeType.task,
          name: 'Proceed', rect: _task(right, _row(8)),
          content: TaskContent(
            title: 'All Clear',
            text: 'You have completed the training module successfully.',
          )),

      // Row 9: End
      'n12': NodeModel(id: 'n12', type: NodeType.endEvent,
          name: 'Complete', rect: _event(_cx, _row(9))),
    };

    final edges = <String, EdgeModel>{
      'e1':  EdgeModel(id: 'e1',  sourceId: 'n1',  targetId: 'n2'),
      'e2':  EdgeModel(id: 'e2',  sourceId: 'n2',  targetId: 'n3'),
      'e3':  EdgeModel(id: 'e3',  sourceId: 'n3',  targetId: 'n4'),
      // 3-way split from gateway
      'e4':  EdgeModel(id: 'e4',  sourceId: 'n4',  targetId: 'n5',  name: 'Text',
          waypoints: _hv(_cx, _row(3), left, _row(4))),
      'e5':  EdgeModel(id: 'e5',  sourceId: 'n4',  targetId: 'n6',  name: 'Image'),
      'e6':  EdgeModel(id: 'e6',  sourceId: 'n4',  targetId: 'n7',  name: 'Video',
          waypoints: _hv(_cx, _row(3), right, _row(4))),
      // 3-way merge — go down first, then horizontal to avoid crossing n6
      'e7':  EdgeModel(id: 'e7',  sourceId: 'n5',  targetId: 'n8',
          waypoints: _vh(left, _row(4), _cx, _row(6))),
      'e8':  EdgeModel(id: 'e8',  sourceId: 'n6',  targetId: 'n8'),
      'e9':  EdgeModel(id: 'e9',  sourceId: 'n7',  targetId: 'n8',
          waypoints: _vh(right, _row(4), _cx, _row(6))),
      // Second gateway
      'e10': EdgeModel(id: 'e10', sourceId: 'n8',  targetId: 'n9'),
      'e11': EdgeModel(id: 'e11', sourceId: 'n9',  targetId: 'n10', name: 'Yes',
          waypoints: _hv(_cx, _row(7), left, _row(8))),
      'e12': EdgeModel(id: 'e12', sourceId: 'n9',  targetId: 'n11', name: 'No',
          waypoints: _hv(_cx, _row(7), right, _row(8))),
      // Both paths to end
      'e13': EdgeModel(id: 'e13', sourceId: 'n10', targetId: 'n12',
          waypoints: _hv(left, _row(8), _cx, _row(9))),
      'e14': EdgeModel(id: 'e14', sourceId: 'n11', targetId: 'n12',
          waypoints: _hv(right, _row(8), _cx, _row(9))),
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
