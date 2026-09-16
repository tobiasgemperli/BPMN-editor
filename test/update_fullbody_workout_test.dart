@Tags(['upload'])
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:bpmn_editor/diagram/samples/sample_diagrams.dart';
import 'package:bpmn_editor/diagram/io/bpmn_serializer.dart';

// One-off: model 845 "Full-body Workout" lost its first film (the barbell back
// squat, f_c9LJjW). Re-serialize the canonical demoFitness() — which has all 5
// exercise clips with the squat first — and push it back to model 845.
const _baseUrl = 'https://odoules.pfn.cz/rest2';
const _username = 'gtobias';
const _password = 'UUUiii111!!!';
const _modelId = '845';

String get _authHeader =>
    'Basic ${base64Encode(utf8.encode('$_username:$_password'))}';

void main() {
  test('restore lost first film on Full-body Workout (845)', () async {
    final bpmnXml = BpmnSerializer().serialize(SampleDiagrams.demoFitness());

    final resp = await http.put(
      Uri.parse('$_baseUrl/browser/updatemodel/$_modelId'),
      headers: {
        'Authorization': _authHeader,
        'Content-Type': 'application/json; charset=utf-8',
      },
      body: jsonEncode({'BpmnXml': bpmnXml}),
    );
    expect(resp.statusCode, 200, reason: 'update failed: ${resp.body}');
    print('  OK  model $_modelId updated (squat re-added as first film)');
  });
}
