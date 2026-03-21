import 'dart:ui' show Offset;
import 'package:xml/xml.dart';
import '../model/diagram_model.dart';

/// Serializes a DiagramModel into valid BPMN 2.0 XML with BPMN-DI layout.
class BpmnSerializer {
  static const _nsBpmn = 'http://www.omg.org/spec/BPMN/20100524/MODEL';
  static const _nsBpmnDi = 'http://www.omg.org/spec/BPMN/20100524/DI';
  static const _nsDc = 'http://www.omg.org/spec/DD/20100524/DC';
  static const _nsDi = 'http://www.omg.org/spec/DD/20100524/DI';
  static const _nsEd = 'http://bpmn-editor.app/extensions';

  String serialize(DiagramModel model) {
    final defId = model.definitionsId ?? 'definitions_1';
    final procId = model.processId ?? 'process_1';

    final builder = XmlBuilder();
    builder.processing('xml', 'version="1.0" encoding="UTF-8"');

    builder.element(
      'bpmn:definitions',
      attributes: {
        'xmlns:bpmn': _nsBpmn,
        'xmlns:bpmndi': _nsBpmnDi,
        'xmlns:dc': _nsDc,
        'xmlns:di': _nsDi,
        'id': defId,
        'targetNamespace': 'http://example.com/bpmn',
      },
      nest: () {
        // Process element.
        builder.element('bpmn:process', attributes: {
          'id': procId,
          'isExecutable': 'false',
        }, nest: () {
          // Nodes.
          for (final node in model.nodes.values) {
            final tag = _bpmnTag(node.type);
            final attrs = <String, String>{'id': node.id};
            if (node.name.isNotEmpty) attrs['name'] = node.name;
            final content = node.content;
            if (content != null && !content.isEmpty) {
              builder.element('bpmn:$tag', attributes: attrs, nest: () {
                if (content.text != null) {
                  builder.element('bpmn:documentation',
                      nest: content.text);
                }
                _serializeExtensionElements(builder, content);
              });
            } else {
              builder.element('bpmn:$tag', attributes: attrs);
            }
          }

          // Sequence flows.
          for (final edge in model.edges.values) {
            final attrs = <String, String>{
              'id': edge.id,
              'sourceRef': edge.sourceId,
              'targetRef': edge.targetId,
            };
            if (edge.name.isNotEmpty) attrs['name'] = edge.name;
            builder.element('bpmn:sequenceFlow', attributes: attrs);
          }
        });

        // BPMN-DI.
        builder.element('bpmndi:BPMNDiagram', attributes: {
          'id': 'BPMNDiagram_1',
        }, nest: () {
          builder.element('bpmndi:BPMNPlane', attributes: {
            'id': 'BPMNPlane_1',
            'bpmnElement': procId,
          }, nest: () {
            // Shapes.
            for (final node in model.nodes.values) {
              builder.element('bpmndi:BPMNShape', attributes: {
                'id': '${node.id}_di',
                'bpmnElement': node.id,
              }, nest: () {
                builder.element('dc:Bounds', attributes: {
                  'x': node.rect.left.toStringAsFixed(1),
                  'y': node.rect.top.toStringAsFixed(1),
                  'width': node.rect.width.toStringAsFixed(1),
                  'height': node.rect.height.toStringAsFixed(1),
                });
              });
            }

            // Edges.
            for (final edge in model.edges.values) {
              builder.element('bpmndi:BPMNEdge', attributes: {
                'id': '${edge.id}_di',
                'bpmnElement': edge.id,
              }, nest: () {
                final wps = edge.waypoints.isNotEmpty
                    ? edge.waypoints
                    : _computeWaypoints(edge, model);
                for (final wp in wps) {
                  builder.element('di:waypoint', attributes: {
                    'x': wp.dx.toStringAsFixed(1),
                    'y': wp.dy.toStringAsFixed(1),
                  });
                }
              });
            }
          });
        });
      },
    );

    final doc = builder.buildDocument();
    return doc.toXmlString(pretty: true);
  }

  void _serializeExtensionElements(XmlBuilder builder, TaskContent content) {
    final hasExtensions = content.title != null ||
        content.imagePath != null ||
        content.videoPath != null ||
        content.linkUrl != null;
    if (!hasExtensions) return;

    builder.element('bpmn:extensionElements', nest: () {
      builder.element('ed:content', attributes: {
        'xmlns:ed': _nsEd,
      }, nest: () {
        if (content.title != null) {
          builder.element('ed:title', nest: content.title);
        }
        if (content.imagePath != null) {
          builder.element('ed:image',
              attributes: {'src': content.imagePath!});
        }
        if (content.videoPath != null) {
          builder.element('ed:video',
              attributes: {'src': content.videoPath!});
        }
        if (content.linkUrl != null) {
          final attrs = <String, String>{'href': content.linkUrl!};
          if (content.linkLabel != null) attrs['label'] = content.linkLabel!;
          builder.element('ed:url', attributes: attrs);
        }
      });
    });
  }

  String _bpmnTag(NodeType type) {
    switch (type) {
      case NodeType.startEvent:
        return 'startEvent';
      case NodeType.endEvent:
        return 'endEvent';
      case NodeType.task:
        return 'task';
      case NodeType.exclusiveGateway:
        return 'exclusiveGateway';
    }
  }

  List<Offset> _computeWaypoints(EdgeModel edge, DiagramModel model) {
    final source = model.nodes[edge.sourceId];
    final target = model.nodes[edge.targetId];
    if (source == null || target == null) return [];
    return [source.center, target.center];
  }
}

