import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:bpmn_editor/diagram/samples/sample_diagrams.dart';
import 'package:bpmn_editor/diagram/io/bpmn_serializer.dart';

// Uploads the "all content types" showcase to the qa account (the one the app
// logs into by default), so it appears in that user's "My Flowcharts".
const _baseUrl = 'https://odoules.pfn.cz/rest2';
const _username = 'qa_1787670944';
const _password = '8bkZwhLK';

String get _authHeader =>
    'Basic ${base64Encode(utf8.encode('$_username:$_password'))}';

void main() {
  test('upload all-items showcase to qa', () async {
    final bpmnXml = BpmnSerializer().serialize(SampleDiagrams.allItems());

    final response = await http.post(
      Uri.parse('$_baseUrl/browser/savemodel'),
      headers: {
        'Authorization': _authHeader,
        'Content-Type': 'application/json; charset=utf-8',
      },
      body: jsonEncode({
        'Name': 'All Content Types',
        'BpmnXml': bpmnXml,
        'Keywords': ['showcase', 'demo'],
        'Sources': ['StepChat'],
        'Categories': ['Sample'],
      }),
    );

    expect(response.statusCode, 200, reason: response.body);
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    // ignore: avoid_print
    print('Uploaded "All Content Types" -> ID ${json['Id']}');
  });
}
