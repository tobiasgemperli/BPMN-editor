@Tags(['integration'])
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:bpmn_editor/diagram/io/api_client.dart';
import 'package:bpmn_editor/diagram/model/diagram_model.dart';

/// Integration tests that hit the real Guide API.
/// Run with: flutter test test/api_client_integration_test.dart --tags integration
void main() {
  final api = ApiClient.instance;

  DiagramModel _makeDiagram() {
    final model = DiagramModel();
    model.nodes['s1'] = NodeModel(
      id: 's1',
      type: NodeType.startEvent,
      rect: const Rect.fromLTWH(100, 100, 48, 48),
    );
    model.nodes['t1'] = NodeModel(
      id: 't1',
      type: NodeType.task,
      name: 'Integration Test Task',
      rect: const Rect.fromLTWH(200, 85, 140, 70),
    );
    model.nodes['e1'] = NodeModel(
      id: 'e1',
      type: NodeType.endEvent,
      rect: const Rect.fromLTWH(400, 100, 48, 48),
    );
    model.edges['flow1'] =
        EdgeModel(id: 'flow1', sourceId: 's1', targetId: 't1');
    model.edges['flow2'] =
        EdgeModel(id: 'flow2', sourceId: 't1', targetId: 'e1');
    return model;
  }

  test('full round-trip: save → get → update → get → delete', () async {
    // 1. Save a new model.
    final diagram = _makeDiagram();
    final created = await api.saveModel(
      name: 'Integration Test Diagram',
      diagram: diagram,
      keywords: ['test', 'integration'],
    );

    expect(created.id, isNotEmpty);
    expect(created.name, 'Integration Test Diagram');
    expect(created.version, 1);

    final id = created.id;

    try {
      // 2. Get the model and verify BpmnXml was stored and parses correctly.
      final fetched = await api.getModel(id);
      expect(fetched.meta.name, 'Integration Test Diagram');
      expect(fetched.bpmnXml, isNotNull);
      expect(fetched.bpmnXml!, contains('startEvent'));
      expect(fetched.diagram, isNotNull);
      expect(fetched.diagram!.nodes, hasLength(3));
      expect(fetched.diagram!.edges, hasLength(2));
      expect(fetched.diagram!.nodes['t1']!.name, 'Integration Test Task');

      // 3. Update the model name and diagram.
      diagram.nodes['t1']!.name = 'Updated Task';
      final updated = await api.updateModel(
        id,
        name: 'Integration Test Updated',
        diagram: diagram,
        keywords: ['test', 'updated'],
      );
      expect(updated.version, 2);
      expect(updated.name, 'Integration Test Updated');

      // 4. Get again to confirm update persisted.
      final refetched = await api.getModel(id);
      expect(refetched.meta.name, 'Integration Test Updated');
      expect(refetched.diagram!.nodes['t1']!.name, 'Updated Task');

      // 5. Delete the model.
      await api.deleteModel(id);

      // 6. Confirm it's gone.
      expect(
        () => api.getModel(id),
        throwsA(isA<ApiException>().having(
          (e) => e.statusCode,
          'statusCode',
          404,
        )),
      );
    } catch (_) {
      // Clean up on failure.
      try {
        await api.deleteModel(id);
      } catch (_) {}
      rethrow;
    }
  });

  test('listModels returns a list', () async {
    final models = await api.listModels();
    expect(models, isA<List<ApiModelMeta>>());
  });

  test('getModel throws 404 for non-existent model', () async {
    expect(
      () => api.getModel('999999'),
      throwsA(isA<ApiException>().having(
        (e) => e.statusCode,
        'statusCode',
        404,
      )),
    );
  });

  test('deleteModel throws 404 for non-existent model', () async {
    expect(
      () => api.deleteModel('999999'),
      throwsA(isA<ApiException>().having(
        (e) => e.statusCode,
        'statusCode',
        404,
      )),
    );
  });
}
