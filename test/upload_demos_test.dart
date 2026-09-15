import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:bpmn_editor/diagram/samples/sample_diagrams.dart';
import 'package:bpmn_editor/diagram/io/bpmn_serializer.dart';

// Tags the demo flowcharts under the "Demos" category on the qa account, and
// uploads the fitness video demo. So the new Demos chip is populated.
const _baseUrl = 'https://odoules.pfn.cz/rest2';
const _username = 'qa_1787670944';
const _password = '8bkZwhLK';
String get _auth => 'Basic ${base64Encode(utf8.encode('$_username:$_password'))}';
Map<String, String> get _h =>
    {'Authorization': _auth, 'Content-Type': 'application/json; charset=utf-8'};

void main() {
  test('upload fitness demo + retag All Content Types as Demos', () async {
    final ser = BpmnSerializer();

    // New fitness video demo.
    final res = await http.post(
      Uri.parse('$_baseUrl/browser/savemodel'),
      headers: _h,
      body: jsonEncode({
        'Name': 'Full-body Workout',
        'BpmnXml': ser.serialize(SampleDiagrams.demoFitness()),
        'Keywords': ['fitness', 'workout', 'demo'],
        'Sources': ['YMove'],
        'Categories': ['Demos'],
      }),
    );
    expect(res.statusCode, 200, reason: res.body);
    // ignore: avoid_print
    print('Full-body Workout -> ID ${jsonDecode(res.body)['Id']}');

    // Retag the existing "All Content Types" (ID 840) into Demos.
    final upd = await http.put(
      Uri.parse('$_baseUrl/browser/updatemodel/840'),
      headers: _h,
      body: jsonEncode({'Categories': ['Demos']}),
    );
    // ignore: avoid_print
    print('retag 840 -> ${upd.statusCode}');
    expect(upd.statusCode, 200, reason: upd.body);
  });
}
