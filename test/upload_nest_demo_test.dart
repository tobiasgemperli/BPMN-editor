@Tags(['upload'])
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart' show MediaType;
import 'package:bpmn_editor/diagram/samples/sample_diagrams.dart';
import 'package:bpmn_editor/diagram/io/bpmn_serializer.dart';

// Publish the Nest Learning Thermostat self-install guide (with its
// troubleshooting branch) to the Demos category as Tobias Gemperli, with the
// guide's line drawings uploaded as backend files so it renders for any viewer.
const _baseUrl = 'https://odoules.pfn.cz/rest2';
const _username = 'gtobias';
const _password = 'UUUiii111!!!';

String get _authHeader =>
    'Basic ${base64Encode(utf8.encode('$_username:$_password'))}';

Future<String> _upload(String assetPath) async {
  final bytes = await File(assetPath).readAsBytes();
  final req = http.MultipartRequest('POST', Uri.parse('$_baseUrl/files/upload'))
    ..headers['Authorization'] = _authHeader
    ..files.add(http.MultipartFile.fromBytes('file', bytes,
        filename: assetPath.split('/').last,
        contentType: MediaType('image', 'png')));
  final resp = await http.Response.fromStream(await req.send());
  expect(resp.statusCode, 200, reason: 'upload $assetPath failed: ${resp.body}');
  return (jsonDecode(resp.body) as Map<String, dynamic>)['Id'] as String;
}

void main() {
  test('upload Nest Thermostat Install to Demos', () async {
    final diagram = SampleDiagrams.nestThermostatInstall();

    final assets = <String>{
      for (final n in diagram.nodes.values) ...?n.content?.imagePaths,
    };
    final remoteFor = <String, String>{};
    for (final a in assets) {
      remoteFor[a] = 'remote:${await _upload(a)}';
      print('  uploaded $a');
    }
    for (final n in diagram.nodes.values) {
      final c = n.content;
      if (c == null || c.imagePaths.isEmpty) continue;
      c.imagePaths = c.imagePaths.map((p) => remoteFor[p] ?? p).toList();
    }

    // Update the canonical model 856 in place with the portrait images.
    final resp = await http.put(
      Uri.parse('$_baseUrl/browser/updatemodel/856'),
      headers: {
        'Authorization': _authHeader,
        'Content-Type': 'application/json; charset=utf-8',
      },
      body: jsonEncode({
        'BpmnXml': BpmnSerializer().serialize(diagram),
        'Categories': ['Demos'],
      }),
    );
    expect(resp.statusCode, 200, reason: 'update failed: ${resp.body}');
    print('  OK  model 856 updated (portrait images)');

    // Remove the stray duplicate 857 created by the earlier savemodel push.
    final del = await http.delete(
      Uri.parse('$_baseUrl/browser/deletemodel/857'),
      headers: {'Authorization': _authHeader},
    );
    print('  delete 857 -> ${del.statusCode}');
    expect(del.statusCode == 200 || del.statusCode == 404, true,
        reason: 'delete 857 failed: ${del.body}');
  });
}
