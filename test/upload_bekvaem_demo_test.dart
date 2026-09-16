@Tags(['upload'])
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:bpmn_editor/diagram/samples/sample_diagrams.dart';
import 'package:bpmn_editor/diagram/io/bpmn_serializer.dart';

// One-off: publish the BEKVÄM step-stool tutorial to the "Demos" category,
// authored by Tobias Gemperli (gtobias, user id 21).
const _baseUrl = 'https://odoules.pfn.cz/rest2';
const _username = 'gtobias';
const _password = 'UUUiii111!!!';

String get _authHeader =>
    'Basic ${base64Encode(utf8.encode('$_username:$_password'))}';

void main() {
  test('upload BEKVÄM demo to Demos as Tobias Gemperli', () async {
    final bpmnXml = BpmnSerializer().serialize(SampleDiagrams.ikeaBekvaem());

    final body = {
      'Name': 'IKEA BEKVÄM Step Stool',
      'BpmnXml': bpmnXml,
      'Keywords': ['Tobias Gemperli', 'IKEA', 'assembly', 'tutorial'],
      'Sources': ['IKEA assembly instructions AA-444158-10'],
      'Categories': ['Demos'],
    };

    final response = await http.post(
      Uri.parse('$_baseUrl/browser/savemodel'),
      headers: {
        'Authorization': _authHeader,
        'Content-Type': 'application/json; charset=utf-8',
      },
      body: jsonEncode(body),
    );

    expect(response.statusCode, 200, reason: 'upload failed: ${response.body}');
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    print('  OK  IKEA BEKVÄM Step Stool -> ID ${json['Id']}');
  });
}
