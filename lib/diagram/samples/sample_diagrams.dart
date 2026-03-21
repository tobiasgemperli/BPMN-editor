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

  /// Technical debugging: API returning 500 errors.
  ///
  /// ```
  /// Start -> Reproduce -> Check Logs -> [Error Type?]
  ///   --DB--> Check DB -> Fix Query -> Verify -> End
  ///   --Auth-> Check Tokens -> Refresh Auth -> Verify -> End
  ///   --Timeout-> Check Load -> Scale/Optimize -> Verify -> End
  /// ```
  static DiagramModel technicalDebugging() {
    final nodes = <String, NodeModel>{
      'n1': NodeModel(id: 'n1', type: NodeType.startEvent, name: 'Bug Report', rect: _event(80, 300)),
      'n2': NodeModel(id: 'n2', type: NodeType.task, name: 'Reproduce', rect: _task(260, 300),
        content: TaskContent(
          title: 'Reproduce the Issue',
          text: 'Open the API endpoint in question using the exact parameters from the bug report. '
              'Confirm the 500 error is reproducible. Note the exact request payload, headers, '
              'and timestamp. Check if the issue is environment-specific (staging vs production). '
              'Try with different user accounts to determine if it is user-specific.',
        )),
      'n3': NodeModel(id: 'n3', type: NodeType.task, name: 'Check Logs', rect: _task(460, 300),
        content: TaskContent(
          title: 'Analyze Server Logs',
          text: 'SSH into the production server or open the logging dashboard. '
              'Filter logs by the timestamp and request ID from the reproduction step. '
              'Look for stack traces, error messages, and any preceding warnings. '
              'Check application logs, web server logs (nginx/Apache), and system logs. '
              'Note the exact exception type and the line number where it occurs.',
        )),
      'n4': NodeModel(id: 'n4', type: NodeType.exclusiveGateway, name: 'Error Type?', rect: _gw(660, 300)),
      // DB path
      'n5': NodeModel(id: 'n5', type: NodeType.task, name: 'Check DB', rect: _task(880, 140),
        content: TaskContent(
          title: 'Inspect Database State',
          text: 'Connect to the database and run the failing query manually. '
              'Check for missing indices, locked rows, or corrupted data. '
              'Verify that recent migrations have been applied correctly. '
              'Look at the slow query log for performance issues.',
        )),
      'n6': NodeModel(id: 'n6', type: NodeType.task, name: 'Fix Query', rect: _task(1100, 140),
        content: TaskContent(
          title: 'Apply Database Fix',
          text: 'Fix the query, add the missing index, or repair the data. '
              'If a migration is needed, write it and test on staging first. '
              'Document the root cause in the ticket.',
        )),
      // Auth path
      'n7': NodeModel(id: 'n7', type: NodeType.task, name: 'Check Tokens', rect: _task(880, 300),
        content: TaskContent(
          title: 'Validate Authentication',
          text: 'Decode the JWT token and check expiry, issuer, and audience claims. '
              'Verify the signing key matches between auth server and API. '
              'Check if the user\'s session exists in the session store (Redis/DB). '
              'Look for clock skew between servers.',
        )),
      'n8': NodeModel(id: 'n8', type: NodeType.task, name: 'Fix Auth', rect: _task(1100, 300),
        content: TaskContent(
          title: 'Refresh Auth Configuration',
          text: 'Rotate the signing keys if compromised. Update the token expiry settings. '
              'Clear stale sessions from the session store. '
              'Deploy the auth fix and monitor for recurring failures.',
        )),
      // Timeout path
      'n9': NodeModel(id: 'n9', type: NodeType.task, name: 'Check Load', rect: _task(880, 460),
        content: TaskContent(
          title: 'Analyze System Resources',
          text: 'Check CPU, memory, and disk usage on the affected server. '
              'Review the connection pool utilization and open file descriptors. '
              'Check if any background jobs or cron tasks are consuming excessive resources. '
              'Look at the request queue depth and average response times.',
        )),
      'n10': NodeModel(id: 'n10', type: NodeType.task, name: 'Optimize', rect: _task(1100, 460),
        content: TaskContent(
          title: 'Scale or Optimize',
          text: 'Add caching for expensive queries. Increase connection pool size. '
              'Scale horizontally by adding more instances behind the load balancer. '
              'Set appropriate timeouts on upstream service calls.',
        )),
      // Merge
      'n11': NodeModel(id: 'n11', type: NodeType.task, name: 'Verify Fix', rect: _task(1320, 300),
        content: TaskContent(
          title: 'Verify the Fix',
          text: 'Re-run the exact reproduction steps from step 1. '
              'Confirm the 500 error no longer occurs. Run the full API test suite. '
              'Monitor production logs for 30 minutes after deployment. '
              'Update the bug ticket with the root cause and resolution.',
        )),
      'n12': NodeModel(id: 'n12', type: NodeType.endEvent, name: 'Resolved', rect: _event(1520, 300)),
    };
    final edges = <String, EdgeModel>{
      'e1':  EdgeModel(id: 'e1',  sourceId: 'n1',  targetId: 'n2'),
      'e2':  EdgeModel(id: 'e2',  sourceId: 'n2',  targetId: 'n3'),
      'e3':  EdgeModel(id: 'e3',  sourceId: 'n3',  targetId: 'n4'),
      'e4':  EdgeModel(id: 'e4',  sourceId: 'n4',  targetId: 'n5',  name: 'Database'),
      'e5':  EdgeModel(id: 'e5',  sourceId: 'n4',  targetId: 'n7',  name: 'Auth'),
      'e6':  EdgeModel(id: 'e6',  sourceId: 'n4',  targetId: 'n9',  name: 'Timeout'),
      'e7':  EdgeModel(id: 'e7',  sourceId: 'n5',  targetId: 'n6'),
      'e8':  EdgeModel(id: 'e8',  sourceId: 'n7',  targetId: 'n8'),
      'e9':  EdgeModel(id: 'e9',  sourceId: 'n9',  targetId: 'n10'),
      'e10': EdgeModel(id: 'e10', sourceId: 'n6',  targetId: 'n11'),
      'e11': EdgeModel(id: 'e11', sourceId: 'n8',  targetId: 'n11'),
      'e12': EdgeModel(id: 'e12', sourceId: 'n10', targetId: 'n11'),
      'e13': EdgeModel(id: 'e13', sourceId: 'n11', targetId: 'n12'),
    };
    return DiagramModel(nodes: nodes, edges: edges);
  }

  /// Emergency procedure: building fire evacuation.
  ///
  /// ```
  /// Alarm -> Alert Others -> [Fire Size?]
  ///   --Small-> Use Extinguisher -> [Fire Out?] --Yes-> Report -> End
  ///                                              --No-> Evacuate
  ///   --Large-> Evacuate -> Assembly Point -> Headcount -> [All Accounted?]
  ///     --Yes-> Wait for FD -> End
  ///     --No-> Inform FD -> Wait -> End
  /// ```
  static DiagramModel emergencyProcedure() {
    final nodes = <String, NodeModel>{
      'n1': NodeModel(id: 'n1', type: NodeType.startEvent, name: 'Fire Alarm', rect: _event(80, 300)),
      'n2': NodeModel(id: 'n2', type: NodeType.task, name: 'Alert Others', rect: _task(260, 300),
        content: TaskContent(
          title: 'Alert Nearby Personnel',
          text: 'Immediately shout "FIRE" to alert people in the vicinity. '
              'Activate the nearest manual fire alarm pull station. '
              'Do NOT use elevators. Do NOT attempt to collect personal belongings. '
              'If safe to do so, close doors and windows behind you to slow fire spread.',
        )),
      'n3': NodeModel(id: 'n3', type: NodeType.exclusiveGateway, name: 'Fire Size?', rect: _gw(460, 300)),
      // Small fire path
      'n4': NodeModel(id: 'n4', type: NodeType.task, name: 'Extinguisher', rect: _task(660, 140),
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
      'n5': NodeModel(id: 'n5', type: NodeType.exclusiveGateway, name: 'Fire Out?', rect: _gw(880, 140)),
      'n6': NodeModel(id: 'n6', type: NodeType.task, name: 'Report', rect: _task(1080, 60),
        content: TaskContent(
          title: 'File Incident Report',
          text: 'Call the fire department to report the extinguished fire — they must still inspect. '
              'Notify building management and your supervisor. '
              'Document the location, time, cause (if known), and actions taken. '
              'The affected area must not be re-entered until cleared by the fire department.',
        )),
      'n7': NodeModel(id: 'n7', type: NodeType.endEvent, name: 'Safe', rect: _event(1280, 60)),
      // Large fire / extinguisher failed path
      'n8': NodeModel(id: 'n8', type: NodeType.task, name: 'Evacuate', rect: _task(660, 460),
        content: TaskContent(
          title: 'Evacuate the Building',
          text: 'Follow the marked evacuation routes — green EXIT signs. '
              'Use stairwells, never elevators. Stay low if there is smoke. '
              'If a door is hot to the touch, do NOT open it — find an alternate route. '
              'Help anyone with mobility impairments. '
              'Move quickly but do not run or push.',
        )),
      'n9': NodeModel(id: 'n9', type: NodeType.task, name: 'Assembly Point', rect: _task(900, 460),
        content: TaskContent(
          title: 'Go to Assembly Point',
          text: 'Proceed to the designated assembly point (parking lot B, north side). '
              'Stay at least 150 meters from the building. '
              'Do not re-enter the building for any reason. '
              'Keep access roads clear for emergency vehicles.',
        )),
      'n10': NodeModel(id: 'n10', type: NodeType.task, name: 'Headcount', rect: _task(1140, 460),
        content: TaskContent(
          title: 'Conduct Headcount',
          text: 'Floor wardens: use the emergency roster to verify all personnel are accounted for. '
              'Check with each department lead. '
              'Identify anyone who was known to be in the building. '
              'Report results to the incident commander within 10 minutes.',
        )),
      'n11': NodeModel(id: 'n11', type: NodeType.exclusiveGateway, name: 'All Accounted?', rect: _gw(1360, 460)),
      'n12': NodeModel(id: 'n12', type: NodeType.task, name: 'Wait for FD', rect: _task(1560, 360),
        content: TaskContent(
          title: 'Await Fire Department',
          text: 'Remain at the assembly point until the fire department gives the all-clear. '
              'Provide the incident commander with building access information. '
              'Do not re-enter until officially authorized.',
        )),
      'n13': NodeModel(id: 'n13', type: NodeType.task, name: 'Inform FD', rect: _task(1560, 560),
        content: TaskContent(
          title: 'Report Missing Persons',
          text: 'Immediately inform the fire department incident commander of unaccounted personnel. '
              'Provide names, last known locations, and any mobility impairments. '
              'Do NOT attempt to re-enter the building to search for them.',
        )),
      'n14': NodeModel(id: 'n14', type: NodeType.endEvent, name: 'Complete', rect: _event(1780, 460)),
    };
    final edges = <String, EdgeModel>{
      'e1':  EdgeModel(id: 'e1',  sourceId: 'n1',  targetId: 'n2'),
      'e2':  EdgeModel(id: 'e2',  sourceId: 'n2',  targetId: 'n3'),
      'e3':  EdgeModel(id: 'e3',  sourceId: 'n3',  targetId: 'n4',  name: 'Small'),
      'e4':  EdgeModel(id: 'e4',  sourceId: 'n3',  targetId: 'n8',  name: 'Large'),
      'e5':  EdgeModel(id: 'e5',  sourceId: 'n4',  targetId: 'n5'),
      'e6':  EdgeModel(id: 'e6',  sourceId: 'n5',  targetId: 'n6',  name: 'Yes'),
      'e7':  EdgeModel(id: 'e7',  sourceId: 'n5',  targetId: 'n8',  name: 'No'),
      'e8':  EdgeModel(id: 'e8',  sourceId: 'n6',  targetId: 'n7'),
      'e9':  EdgeModel(id: 'e9',  sourceId: 'n8',  targetId: 'n9'),
      'e10': EdgeModel(id: 'e10', sourceId: 'n9',  targetId: 'n10'),
      'e11': EdgeModel(id: 'e11', sourceId: 'n10', targetId: 'n11'),
      'e12': EdgeModel(id: 'e12', sourceId: 'n11', targetId: 'n12', name: 'Yes'),
      'e13': EdgeModel(id: 'e13', sourceId: 'n11', targetId: 'n13', name: 'No'),
      'e14': EdgeModel(id: 'e14', sourceId: 'n12', targetId: 'n14'),
      'e15': EdgeModel(id: 'e15', sourceId: 'n13', targetId: 'n14'),
    };
    return DiagramModel(nodes: nodes, edges: edges);
  }

  /// IKEA shelf assembly (KALLAX 2x2).
  ///
  /// ```
  /// Start -> Unpack -> Check Parts -> [All Parts?]
  ///   --No-> Contact IKEA -> End
  ///   --Yes-> Assemble Frame -> Insert Shelves -> Mount to Wall -> Done
  /// ```
  static DiagramModel ikeaAssembly() {
    final nodes = <String, NodeModel>{
      'n1': NodeModel(id: 'n1', type: NodeType.startEvent, name: 'Start', rect: _event(80, 300)),
      'n2': NodeModel(id: 'n2', type: NodeType.task, name: 'Unpack', rect: _task(260, 300),
        content: TaskContent(
          title: 'Unpack All Parts',
          text: 'Open the box and carefully remove all components. '
              'Lay them out on a clean, flat surface — ideally on the cardboard packaging to protect your floor. '
              'Do not use a knife to cut deep into the box as you may scratch the panels. '
              'Remove all plastic wrapping and styrofoam inserts.',
        )),
      'n3': NodeModel(id: 'n3', type: NodeType.task, name: 'Check Parts', rect: _task(460, 300),
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
      'n4': NodeModel(id: 'n4', type: NodeType.exclusiveGateway, name: 'All Parts?', rect: _gw(680, 300)),
      // Missing parts
      'n5': NodeModel(id: 'n5', type: NodeType.task, name: 'Contact IKEA', rect: _task(680, 480),
        content: TaskContent(
          title: 'Order Missing Parts',
          text: 'Go to IKEA.com/replace or call customer service. '
              'You will need the product article number (on the label inside the box) '
              'and the part numbers from the instruction sheet. '
              'IKEA will ship replacement parts for free.',
        )),
      'n6': NodeModel(id: 'n6', type: NodeType.endEvent, name: 'Wait', rect: _event(680, 640)),
      // Assembly path
      'n7': NodeModel(id: 'n7', type: NodeType.task, name: 'Frame', rect: _task(900, 300),
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
      'n8': NodeModel(id: 'n8', type: NodeType.task, name: 'Dividers', rect: _task(1120, 300),
        content: TaskContent(
          title: 'Insert Shelf Dividers',
          text: 'Slide the horizontal divider into position first — insert dowels, then lock with cams. '
              'Next, insert the vertical divider. It should slot into the notch on the horizontal divider, '
              'creating four equal compartments.\n\n'
              'Ensure all cam locks are firmly turned. Gently wiggle the unit — '
              'if it racks (leans to one side), a cam lock is not fully engaged.',
        )),
      'n9': NodeModel(id: 'n9', type: NodeType.task, name: 'Back Panel', rect: _task(1340, 300),
        content: TaskContent(
          title: 'Attach the Back Panel',
          text: 'Lay the unit face-down on the floor. '
              'Place the thin fibreboard back panel on top, aligning it with the edges. '
              'The smooth side faces outward (toward the wall).\n\n'
              'Nail it in place using the small nails provided. '
              'Start with the four corners, then add nails every 10-15 cm along each edge and along the dividers. '
              'The back panel is critical for structural rigidity — do not skip nails.',
        )),
      'n10': NodeModel(id: 'n10', type: NodeType.task, name: 'Wall Mount', rect: _task(1560, 300),
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
      'n11': NodeModel(id: 'n11', type: NodeType.endEvent, name: 'Done', rect: _event(1760, 300)),
    };
    final edges = <String, EdgeModel>{
      'e1': EdgeModel(id: 'e1', sourceId: 'n1',  targetId: 'n2'),
      'e2': EdgeModel(id: 'e2', sourceId: 'n2',  targetId: 'n3'),
      'e3': EdgeModel(id: 'e3', sourceId: 'n3',  targetId: 'n4'),
      'e4': EdgeModel(id: 'e4', sourceId: 'n4',  targetId: 'n5',  name: 'No'),
      'e5': EdgeModel(id: 'e5', sourceId: 'n4',  targetId: 'n7',  name: 'Yes'),
      'e6': EdgeModel(id: 'e6', sourceId: 'n5',  targetId: 'n6'),
      'e7': EdgeModel(id: 'e7', sourceId: 'n7',  targetId: 'n8'),
      'e8': EdgeModel(id: 'e8', sourceId: 'n8',  targetId: 'n9'),
      'e9': EdgeModel(id: 'e9', sourceId: 'n9',  targetId: 'n10'),
      'e10': EdgeModel(id: 'e10', sourceId: 'n10', targetId: 'n11'),
    };
    return DiagramModel(nodes: nodes, edges: edges);
  }

  /// All sample diagrams with display names.
  static final List<({String name, DiagramModel Function() builder})> all = [
    (name: 'IKEA KALLAX Assembly', builder: ikeaAssembly),
    (name: 'Emergency: Fire Evacuation', builder: emergencyProcedure),
    (name: 'Debug: API 500 Errors', builder: technicalDebugging),
    (name: 'Sprint Cycle', builder: sprintCycle),
    (name: 'Linear Flow', builder: linear),
    (name: 'Diamond (2 merge)', builder: diamond),
    (name: 'Three-Way Merge', builder: threeWayMerge),
    (name: 'Double Diamond (2x2 merge)', builder: doubleDiamond),
    (name: 'Four-Way Merge', builder: fourWayMerge),
  ];
}
