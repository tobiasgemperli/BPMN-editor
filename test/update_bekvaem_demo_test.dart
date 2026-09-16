@Tags(['upload'])
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart' show MediaType;
import 'package:bpmn_editor/diagram/samples/sample_diagrams.dart';
import 'package:bpmn_editor/diagram/io/bpmn_serializer.dart';

// One-off: replace the BEKVÄM demo's bundled-asset images with uploaded backend
// files so they render for any viewer, and push the image-only (no-caption,
// start/end have images) diagram to model 850 owned by Tobias Gemperli.
const _baseUrl = 'https://odoules.pfn.cz/rest2';
const _username = 'gtobias';
const _password = 'UUUiii111!!!';
const _modelId = '850';

String get _authHeader =>
    'Basic ${base64Encode(utf8.encode('$_username:$_password'))}';

Future<String> _uploadFile(String assetPath) async {
  final bytes = await File(assetPath).readAsBytes();
  final req = http.MultipartRequest('POST', Uri.parse('$_baseUrl/files/upload'))
    ..headers['Authorization'] = _authHeader
    ..files.add(http.MultipartFile.fromBytes('file', bytes,
        filename: assetPath.split('/').last,
        contentType: MediaType('image', 'png')));
  final resp = await http.Response.fromStream(await req.send());
  expect(resp.statusCode, 200, reason: 'upload $assetPath failed: ${resp.body}');
  final id = (jsonDecode(resp.body) as Map<String, dynamic>)['Id'] as String?;
  expect(id != null && id.isNotEmpty, true, reason: 'no file id: ${resp.body}');
  return id!;
}

void main() {
  test('replace BEKVÄM images with backend files + update model 850', () async {
    final diagram = SampleDiagrams.ikeaBekvaem();

    // Upload each distinct asset once, mapping asset path -> remote:<fileId>.
    final assetPaths = <String>{
      for (final n in diagram.nodes.values)
        ...?n.content?.imagePaths,
    };
    final remoteFor = <String, String>{};
    for (final path in assetPaths) {
      final fileId = await _uploadFile(path);
      remoteFor[path] = 'remote:$fileId';
      print('  uploaded $path -> $fileId');
    }

    // Rewrite every node's image refs to their backend files.
    for (final node in diagram.nodes.values) {
      final c = node.content;
      if (c == null || c.imagePaths.isEmpty) continue;
      c.imagePaths =
          c.imagePaths.map((p) => remoteFor[p] ?? p).toList();
    }

    final bpmnXml = BpmnSerializer().serialize(diagram);
    final resp = await http.put(
      Uri.parse('$_baseUrl/browser/updatemodel/$_modelId'),
      headers: {
        'Authorization': _authHeader,
        'Content-Type': 'application/json; charset=utf-8',
      },
      body: jsonEncode({'BpmnXml': bpmnXml, 'Categories': ['Demos']}),
    );
    expect(resp.statusCode, 200, reason: 'update failed: ${resp.body}');
    print('  OK  model $_modelId updated (image-only, remote files)');
  });
}
