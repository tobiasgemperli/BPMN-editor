import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:http/http.dart' as http;
import 'package:bpmn_editor/diagram/io/api_client.dart';

const _bpmnXml = '<?xml version="1.0" encoding="UTF-8"?>'
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

Map<String, dynamic> _listItem(String id, String ownerId) => {
      'Id': id,
      'Name': 'Model $id',
      'OwnerName': 'Owner $ownerId',
      'OwnerId': ownerId,
      'Created': '2026-01-01 10:00:00',
      'Version': '1',
      // The real list endpoint omits BpmnXml/Nodes content.
      'BpmnXml': null,
    };

void main() {
  group('listMyModels', () {
    test('returns only the authenticated user\'s models, with diagrams '
        'fetched via getModel', () async {
      final getModelIds = <String>[];

      final mockClient = MockClient((request) async {
        final path = request.url.path;
        if (path == '/rest2/user/settings') {
          return http.Response(jsonEncode({'id': 5, 'uname': 'me'}), 200);
        }
        if (path == '/rest2/browser/list/') {
          expect(request.method, 'POST');
          return http.Response(
            jsonEncode([
              _listItem('10', '5'), // mine
              _listItem('11', '6'), // someone else
              _listItem('12', '5'), // mine
            ]),
            200,
          );
        }
        if (path.startsWith('/rest2/browser/getmodel/')) {
          final id = path.split('/').last;
          getModelIds.add(id);
          return http.Response(
            jsonEncode({
              'Id': id,
              'Name': 'Model $id',
              'OwnerName': 'Owner 5',
              'OwnerId': '5',
              'Created': '2026-01-01 10:00:00',
              'Version': 1,
              'BpmnXml': _bpmnXml,
            }),
            200,
          );
        }
        return http.Response('unexpected ${request.url}', 404);
      });

      final api = ApiClient.withClient(mockClient);
      final mine = await api.listMyModels();

      // Only owner-5 models, never owner 6.
      expect(mine.map((m) => m.meta.id), ['10', '12']);
      expect(mine.every((m) => m.meta.ownerId == '5'), isTrue);
      // getModel was called only for the owned models.
      expect(getModelIds..sort(), ['10', '12']);
      // Diagrams were parsed from the per-model BpmnXml.
      expect(mine.every((m) => m.diagram != null), isTrue);
    });

    test('currentUserId is cached after first lookup', () async {
      var settingsCalls = 0;
      final mockClient = MockClient((request) async {
        if (request.url.path == '/rest2/user/settings') {
          settingsCalls++;
          return http.Response(jsonEncode({'id': 7}), 200);
        }
        return http.Response('[]', 200);
      });

      final api = ApiClient.withClient(mockClient);
      expect(await api.currentUserId(), 7);
      expect(await api.currentUserId(), 7);
      expect(settingsCalls, 1);
    });
  });
}
