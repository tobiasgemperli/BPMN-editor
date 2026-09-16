@Tags(['upload'])
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart' show MediaType;
import 'package:bpmn_editor/diagram/samples/sample_diagrams.dart';
import 'package:bpmn_editor/diagram/io/bpmn_serializer.dart';

// Publish the AT&T Internet self-install guide (with its troubleshooting
// branch) to the Demos category as Tobias Gemperli, with images as backend
// files so it renders for any viewer.
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
  test('upload AT&T Internet Self-Install to Demos', () async {
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

    final resp = await http.post(
      Uri.parse('$_baseUrl/browser/savemodel'),
      headers: {
        'Authorization': _authHeader,
        'Content-Type': 'application/json; charset=utf-8',
      },
      body: jsonEncode({
        'Name': 'AT&T Internet Self-Install',
        'BpmnXml': BpmnSerializer().serialize(diagram),
        'Keywords': ['Tobias Gemperli', 'AT&T', 'internet', 'troubleshooting'],
        'Sources': ['AT&T Wi-Fi Gateway self-install guide'],
        'Categories': ['Demos'],
      }),
    );
    expect(resp.statusCode, 200, reason: 'save failed: ${resp.body}');
    print('  OK  AT&T -> ID ${(jsonDecode(resp.body) as Map)['Id']}');
  });
}
