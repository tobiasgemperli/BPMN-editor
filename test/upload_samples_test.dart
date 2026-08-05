@Tags(['upload'])
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:bpmn_editor/diagram/samples/sample_diagrams.dart';
import 'package:bpmn_editor/diagram/io/bpmn_serializer.dart';

const _baseUrl = 'https://odoules.pfn.cz/rest2';
const _username = 'test';
const _password = 'j5K_fv3sg';

String get _authHeader =>
    'Basic ${base64Encode(utf8.encode('$_username:$_password'))}';

void main() {
  test('upload all sample diagrams to backend', () async {
    final serializer = BpmnSerializer();
    final samples = SampleDiagrams.all;

    print('Uploading ${samples.length} sample diagrams...\n');

    int success = 0;

    for (final entry in samples) {
      final diagram = entry.builder();
      final bpmnXml = serializer.serialize(diagram);

      final body = {
        'Name': entry.name,
        'BpmnXml': bpmnXml,
        'Keywords': [entry.creator.name],
        'Sources': ['StepChat Samples'],
        'Categories': ['Sample'],
      };

      final response = await http.post(
        Uri.parse('$_baseUrl/browser/savemodel'),
        headers: {
          'Authorization': _authHeader,
          'Content-Type': 'application/json; charset=utf-8',
        },
        body: jsonEncode(body),
      );

      expect(response.statusCode, 200,
          reason: '${entry.name} failed: ${response.body}');

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      print('  OK  ${entry.name} -> ID ${json['Id']}');
      success++;
    }

    print('\nUploaded $success/${samples.length} diagrams.');
    expect(success, samples.length);
  });
}
