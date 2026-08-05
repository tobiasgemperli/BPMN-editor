import 'dart:convert';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:http/http.dart' as http;
import 'package:bpmn_editor/diagram/io/api_client.dart';
import 'package:bpmn_editor/diagram/model/diagram_model.dart';

DiagramModel _simpleDiagram() {
  final model = DiagramModel();
  model.nodes['s1'] = NodeModel(
    id: 's1',
    type: NodeType.startEvent,
    rect: const Rect.fromLTWH(100, 100, 48, 48),
  );
  model.nodes['t1'] = NodeModel(
    id: 't1',
    type: NodeType.task,
    name: 'Do something',
    rect: const Rect.fromLTWH(200, 85, 140, 70),
  );
  model.edges['e1'] = EdgeModel(id: 'e1', sourceId: 's1', targetId: 't1');
  return model;
}

void main() {
  group('ApiClient unit tests', () {
    test('listModels sends POST to browser/list and parses response', () async {
      final mockClient = MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/rest2/browser/list');
        expect(request.headers['Authorization'], startsWith('Basic '));

        return http.Response(
          jsonEncode([
            {
              'Id': '1',
              'Name': 'Test Model',
              'OwnerName': 'Alice',
              'OwnerId': '5',
              'Created': '2026-01-01 10:00:00',
              'Version': '2',
              'Keywords': ['k1'],
              'Sources': [],
              'Categories': ['ops'],
            },
          ]),
          200,
        );
      });

      final api = ApiClient.withClient(mockClient);
      final models = await api.listModels();

      expect(models, hasLength(1));
      expect(models.first.id, '1');
      expect(models.first.name, 'Test Model');
      expect(models.first.ownerName, 'Alice');
      expect(models.first.version, 2);
      expect(models.first.keywords, ['k1']);
      expect(models.first.categories, ['ops']);
    });

    test('listModels throws ApiException on non-200', () async {
      final mockClient = MockClient((_) async {
        return http.Response('server error', 500);
      });

      final api = ApiClient.withClient(mockClient);
      expect(() => api.listModels(), throwsA(isA<ApiException>()));
    });

    test('getModel sends GET and parses BpmnXml into diagram', () async {
      const bpmnXml = '<?xml version="1.0" encoding="UTF-8"?>'
          '<bpmn:definitions xmlns:bpmn="http://www.omg.org/spec/BPMN/20100524/MODEL" '
          'xmlns:bpmndi="http://www.omg.org/spec/BPMN/20100524/DI" '
          'xmlns:dc="http://www.omg.org/spec/DD/20100524/DC" '
          'xmlns:di="http://www.omg.org/spec/DD/20100524/DI" '
          'id="d1" targetNamespace="http://example.com/bpmn">'
          '<bpmn:process id="p1" isExecutable="false">'
          '<bpmn:startEvent id="s1"/>'
          '</bpmn:process>'
          '<bpmndi:BPMNDiagram id="dia1">'
          '<bpmndi:BPMNPlane id="plane1" bpmnElement="p1">'
          '<bpmndi:BPMNShape id="s1_di" bpmnElement="s1">'
          '<dc:Bounds x="100" y="100" width="48" height="48"/>'
          '</bpmndi:BPMNShape>'
          '</bpmndi:BPMNPlane>'
          '</bpmndi:BPMNDiagram>'
          '</bpmn:definitions>';

      final mockClient = MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/rest2/browser/getmodel/42');

        return http.Response(
          jsonEncode({
            'Id': '42',
            'Name': 'My Model',
            'OwnerName': 'Bob',
            'OwnerId': '3',
            'Created': '2026-06-01 12:00:00',
            'Version': 1,
            'Keywords': [],
            'Sources': [],
            'Categories': [],
            'BpmnXml': bpmnXml,
          }),
          200,
        );
      });

      final api = ApiClient.withClient(mockClient);
      final result = await api.getModel('42');

      expect(result.meta.id, '42');
      expect(result.meta.name, 'My Model');
      expect(result.bpmnXml, isNotNull);
      expect(result.diagram, isNotNull);
      expect(result.diagram!.nodes.containsKey('s1'), isTrue);
    });

    test('getModel returns null diagram for missing BpmnXml', () async {
      final mockClient = MockClient((_) async {
        return http.Response(
          jsonEncode({
            'Id': '1',
            'Name': 'Empty',
            'OwnerName': '',
            'OwnerId': '',
            'Created': '2026-01-01 00:00:00',
            'Version': 1,
            'BpmnXml': null,
          }),
          200,
        );
      });

      final api = ApiClient.withClient(mockClient);
      final result = await api.getModel('1');
      expect(result.diagram, isNull);
    });

    test('saveModel sends POST with serialized BPMN XML', () async {
      final diagram = _simpleDiagram();

      final mockClient = MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/rest2/browser/savemodel');
        expect(request.headers['Content-Type'],
            contains('application/json'));

        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['Name'], 'Test Save');
        expect(body['BpmnXml'], isNotNull);
        expect((body['BpmnXml'] as String), contains('<bpmn:startEvent'));

        return http.Response(
          jsonEncode({
            'Id': '99',
            'OwnerName': 'Test',
            'OwnerId': '1',
            'Created': '2026-08-05 10:00:00',
            'Name': 'Test Save',
            'Version': '1',
          }),
          200,
        );
      });

      final api = ApiClient.withClient(mockClient);
      final meta = await api.saveModel(name: 'Test Save', diagram: diagram);

      expect(meta.id, '99');
      expect(meta.name, 'Test Save');
      expect(meta.version, 1);
    });

    test('updateModel sends PUT with partial fields', () async {
      final mockClient = MockClient((request) async {
        expect(request.method, 'PUT');
        expect(request.url.path, '/rest2/browser/updatemodel/10');

        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['Name'], 'Renamed');
        expect(body.containsKey('BpmnXml'), isFalse);

        return http.Response(
          jsonEncode({
            'Id': '10',
            'Name': 'Renamed',
            'OwnerName': 'Test',
            'OwnerId': '1',
            'Created': '2026-08-05 10:00:00',
            'Version': '2',
          }),
          200,
        );
      });

      final api = ApiClient.withClient(mockClient);
      final meta = await api.updateModel('10', name: 'Renamed');

      expect(meta.id, '10');
      expect(meta.version, 2);
    });

    test('updateModel includes BpmnXml when diagram is provided', () async {
      final diagram = _simpleDiagram();

      final mockClient = MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body.containsKey('BpmnXml'), isTrue);
        expect((body['BpmnXml'] as String), contains('startEvent'));

        return http.Response(
          jsonEncode({
            'Id': '10',
            'Name': 'Updated',
            'OwnerName': 'Test',
            'OwnerId': '1',
            'Created': '2026-08-05 10:00:00',
            'Version': '3',
          }),
          200,
        );
      });

      final api = ApiClient.withClient(mockClient);
      await api.updateModel('10', name: 'Updated', diagram: diagram);
    });

    test('deleteModel sends DELETE', () async {
      final mockClient = MockClient((request) async {
        expect(request.method, 'DELETE');
        expect(request.url.path, '/rest2/browser/deletemodel/55');

        return http.Response(jsonEncode({'success': true}), 200);
      });

      final api = ApiClient.withClient(mockClient);
      await api.deleteModel('55');
    });

    test('deleteModel throws on 404', () async {
      final mockClient = MockClient((_) async {
        return http.Response('model not found', 404);
      });

      final api = ApiClient.withClient(mockClient);
      expect(() => api.deleteModel('999'), throwsA(isA<ApiException>()));
    });
  });

  group('ApiModelMeta.fromJson edge cases', () {
    test('handles Version as int', () {
      final meta = ApiModelMeta.fromJson({
        'Id': '1',
        'Name': 'A',
        'Version': 3,
        'Created': '2026-01-01 00:00:00',
      });
      expect(meta.version, 3);
    });

    test('handles Version as string', () {
      final meta = ApiModelMeta.fromJson({
        'Id': '1',
        'Name': 'A',
        'Version': '5',
        'Created': '2026-01-01 00:00:00',
      });
      expect(meta.version, 5);
    });

    test('handles null/missing fields gracefully', () {
      final meta = ApiModelMeta.fromJson({'Id': null});
      expect(meta.id, '');
      expect(meta.name, '');
      expect(meta.keywords, isEmpty);
    });
  });
}
