import 'dart:ui';
import 'package:xml/xml.dart';
import '../model/diagram_model.dart';

/// Parses a BPMN 2.0 XML string (with optional BPMN-DI) into a DiagramModel.
class BpmnParser {
  static const _nsBpmn = 'http://www.omg.org/spec/BPMN/20100524/MODEL';
  static const _nsBpmnDi = 'http://www.omg.org/spec/BPMN/20100524/DI';
  static const _nsDc = 'http://www.omg.org/spec/DD/20100524/DC';
  // ignore: unused_field
  static const _nsDi = 'http://www.omg.org/spec/DD/20100524/DI';
  static const _nsEd = 'http://bpmn-editor.app/extensions';

  DiagramModel parse(String xmlString) {
    final doc = XmlDocument.parse(xmlString);
    final definitions = doc.rootElement;

    final model = DiagramModel(
      definitionsId: definitions.getAttribute('id'),
    );

    // Find the process element.
    final process = _findElement(definitions, 'process', _nsBpmn);
    if (process == null) return model;

    model.processId = process.getAttribute('id');

    // Parse nodes.
    for (final child in process.children.whereType<XmlElement>()) {
      final localName = child.name.local;
      final ns = child.name.namespaceUri;

      // Only handle our supported BPMN namespace elements.
      if (ns != null && ns != _nsBpmn) continue;

      NodeType? type;
      switch (localName) {
        case 'startEvent':
          type = NodeType.startEvent;
          break;
        case 'endEvent':
          type = NodeType.endEvent;
          break;
        case 'task':
          type = NodeType.task;
          break;
        case 'exclusiveGateway':
          type = NodeType.exclusiveGateway;
          break;
        case 'sequenceFlow':
          _parseSequenceFlow(child, model);
          continue;
        default:
          // Unsupported element – ignore.
          continue;
      }

      final id = child.getAttribute('id') ?? '';
      final name = child.getAttribute('name') ?? '';
      final content = type == NodeType.task ? _parseTaskContent(child) : null;
      model.nodes[id] = NodeModel(
        id: id,
        type: type,
        name: name,
        rect: Rect.zero, // Will be set from DI or auto-layout.
        content: content,
      );
    }

    // Parse BPMN-DI.
    _parseDi(definitions, model);

    // Auto-layout nodes that still have Rect.zero.
    _autoLayoutMissing(model);

    return model;
  }

  void _parseSequenceFlow(XmlElement el, DiagramModel model) {
    final id = el.getAttribute('id') ?? '';
    final source = el.getAttribute('sourceRef') ?? '';
    final target = el.getAttribute('targetRef') ?? '';
    final name = el.getAttribute('name') ?? '';
    model.edges[id] = EdgeModel(
      id: id,
      sourceId: source,
      targetId: target,
      name: name,
    );
  }

  void _parseDi(XmlElement definitions, DiagramModel model) {
    final diagram = _findElement(definitions, 'BPMNDiagram', _nsBpmnDi);
    if (diagram == null) return;

    final plane = _findElement(diagram, 'BPMNPlane', _nsBpmnDi);
    if (plane == null) return;

    for (final child in plane.children.whereType<XmlElement>()) {
      final localName = child.name.local;
      if (localName == 'BPMNShape') {
        _parseShape(child, model);
      } else if (localName == 'BPMNEdge') {
        _parseEdge(child, model);
      }
    }
  }

  void _parseShape(XmlElement el, DiagramModel model) {
    final bpmnElement = el.getAttribute('bpmnElement') ?? '';
    final bounds = _findElement(el, 'Bounds', _nsDc);
    if (bounds == null) return;

    final x = double.tryParse(bounds.getAttribute('x') ?? '') ?? 0;
    final y = double.tryParse(bounds.getAttribute('y') ?? '') ?? 0;
    final w = double.tryParse(bounds.getAttribute('width') ?? '') ?? 0;
    final h = double.tryParse(bounds.getAttribute('height') ?? '') ?? 0;

    final node = model.nodes[bpmnElement];
    if (node != null) {
      node.rect = Rect.fromLTWH(x, y, w, h);
    }
  }

  void _parseEdge(XmlElement el, DiagramModel model) {
    final bpmnElement = el.getAttribute('bpmnElement') ?? '';
    final edge = model.edges[bpmnElement];
    if (edge == null) return;

    final waypoints = <Offset>[];
    for (final child in el.children.whereType<XmlElement>()) {
      if (child.name.local == 'waypoint') {
        final x = double.tryParse(child.getAttribute('x') ?? '') ?? 0;
        final y = double.tryParse(child.getAttribute('y') ?? '') ?? 0;
        waypoints.add(Offset(x, y));
      }
    }
    edge.waypoints = waypoints;
  }

  void _autoLayoutMissing(DiagramModel model) {
    double x = 100;
    const y = 200.0;
    const spacing = 220.0;

    for (final node in model.nodes.values) {
      if (node.rect == Rect.zero) {
        node.rect = NodeModel.defaultRect(node.type, Offset(x, y));
        x += spacing;
      }
    }
  }

  TaskContent? _parseTaskContent(XmlElement taskEl) {
    String? text;
    String? title;
    String? imagePath;
    String? videoPath;
    String? linkUrl;
    String? linkLabel;

    for (final child in taskEl.children.whereType<XmlElement>()) {
      if (child.name.local == 'documentation') {
        text = child.innerText.isNotEmpty ? child.innerText : null;
      } else if (child.name.local == 'extensionElements') {
        for (final ext in child.children.whereType<XmlElement>()) {
          if (ext.name.local == 'content') {
            for (final item in ext.children.whereType<XmlElement>()) {
              switch (item.name.local) {
                case 'title':
                  title = item.innerText.isNotEmpty ? item.innerText : null;
                  break;
                case 'image':
                  imagePath = item.getAttribute('src');
                  break;
                case 'video':
                  videoPath = item.getAttribute('src');
                  break;
                case 'url':
                  linkUrl = item.getAttribute('href');
                  linkLabel = item.getAttribute('label');
                  break;
              }
            }
          }
        }
      }
    }

    if (text == null && title == null && imagePath == null &&
        videoPath == null && linkUrl == null) {
      return null;
    }
    return TaskContent(
      title: title,
      text: text,
      imagePath: imagePath,
      videoPath: videoPath,
      linkUrl: linkUrl,
      linkLabel: linkLabel,
    );
  }

  XmlElement? _findElement(
      XmlElement parent, String localName, String? namespace) {
    for (final child in parent.children.whereType<XmlElement>()) {
      if (child.name.local == localName) {
        if (namespace == null || child.name.namespaceUri == namespace) {
          return child;
        }
        // Also match if no namespace is declared (common in simple files).
        if (child.name.namespaceUri == null) return child;
      }
    }
    return null;
  }
}
