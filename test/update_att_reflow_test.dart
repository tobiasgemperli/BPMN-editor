@Tags(['upload'])
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart' show MediaType;
import 'package:bpmn_editor/diagram/samples/sample_diagrams.dart';
import 'package:bpmn_editor/diagram/io/bpmn_serializer.dart';

// Replace model 855 with the re-flowed AT&T guide: native text + illustration-
// only images (no baked-in paragraphs) + callout tiles, images as backend files.
const _baseUrl = 'https://odoules.pfn.cz/rest2';
const _username = 'gtobias';
const _password = 'UUUiii111!!!';
const _modelId = '855';

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
  test('replace 855 with the re-flowed AT&T guide', () async {
    final diagram = SampleDiagrams.attInternetInstall();

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

    final resp = await http.put(
      Uri.parse('$_baseUrl/browser/updatemodel/$_modelId'),
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
    print('  OK  model $_modelId replaced with re-flowed guide');
  });
}
