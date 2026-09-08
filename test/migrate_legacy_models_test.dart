// One-time migration: convert the remaining legacy `Nodes`-format models to
// persisted `BpmnXml`, using the app's own converter + serializer so output
// matches every other migrated model.
//
// Non-destructive: sends ONLY the `BpmnXml` field; never touches Nodes / owner /
// metadata. Guards on empty-BpmnXml (won't overwrite real diagrams) and
// re-fetches each model to assert `Nodes` stayed byte-identical.
//
// Runs under `flutter test` because the converter imports dart:ui.
//   Dry-run (default):  ADMIN_USER=gtobias ADMIN_PASS=... flutter test test/migrate_legacy_models_test.dart
//   Live write:  MIGRATE_LIVE=1 ADMIN_USER=gtobias ADMIN_PASS=... flutter test ...
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:bpmn_editor/diagram/io/node_graph.dart';
import 'package:bpmn_editor/diagram/io/bpmn_serializer.dart';
import 'package:bpmn_editor/diagram/io/bpmn_parser.dart';

const _base = 'https://odoules.pfn.cz/rest2';

void main() {
  final env = Platform.environment;
  final user = env['ADMIN_USER'];
  final pass = env['ADMIN_PASS'];
  final live = env['MIGRATE_LIVE'] == '1';

  test('migrate legacy Nodes models to BpmnXml', () async {
    if (user == null || pass == null) {
      markTestSkipped('set ADMIN_USER/ADMIN_PASS to run the migration tool');
      return;
    }
    final auth = 'Basic ${base64Encode(utf8.encode('$user:$pass'))}';
    final headers = {'Authorization': auth};
    final jsonHeaders = {...headers, 'Content-Type': 'application/json'};
    final serializer = BpmnSerializer();
    final parser = BpmnParser();

    // Discover targets: every model with empty BpmnXml but non-empty Nodes.
    final listResp = await http.post(
      Uri.parse('$_base/browser/list/'),
      headers: jsonHeaders,
      body: jsonEncode({'withContent': true}),
    );
    expect(listResp.statusCode, 200, reason: 'list failed: ${listResp.body}');
    final all = jsonDecode(listResp.body) as List;
    final targets = all
        .cast<Map<String, dynamic>>()
        .where((m) =>
            ((m['BpmnXml'] as String?) ?? '').trim().isEmpty &&
            m['Nodes'] is List &&
            (m['Nodes'] as List).isNotEmpty)
        .map((m) => int.parse('${m['Id']}'))
        .toList()
      ..sort();

    stdout.writeln(live
        ? '=== LIVE migration (writing BpmnXml) ==='
        : '=== DRY RUN (no writes) — set MIGRATE_LIVE=1 to persist ===');
    stdout.writeln('  discovered ${targets.length} models to convert: $targets');

    var converted = 0, skipped = 0, failed = 0;
    for (final id in targets) {
      final before =
          jsonDecode((await http.get(Uri.parse('$_base/browser/getmodel/$id'),
                  headers: headers))
              .body) as Map<String, dynamic>;
      final existingXml = (before['BpmnXml'] as String?) ?? '';
      final nodesJson = before['Nodes'];

      if (existingXml.isNotEmpty) {
        stdout.writeln('  id=$id  SKIP (already has BpmnXml)');
        skipped++;
        continue;
      }
      if (nodesJson is! List || nodesJson.isEmpty) {
        stdout.writeln('  id=$id  SKIP (no Nodes to convert)');
        skipped++;
        continue;
      }

      final diagram = diagramFromNodes(nodesJson);
      if (diagram.nodes.isEmpty) {
        stdout.writeln('  id=$id  FAIL (converter produced 0 nodes)');
        failed++;
        continue;
      }
      final xml = serializer.serialize(diagram);
      // Sanity: our own output must round-trip through the parser.
      final reparsed = parser.parse(xml);
      expect(reparsed.nodes.length, diagram.nodes.length,
          reason: 'id=$id serialized XML did not round-trip');

      stdout.writeln(
          '  id=$id  ${before['Name']}  nodes=${diagram.nodes.length} edges=${diagram.edges.length} xmlLen=${xml.length}'
          '${live ? '' : '  [would write]'}');

      if (!live) {
        converted++;
        continue;
      }

      // Write ONLY BpmnXml.
      final put = await http.put(
        Uri.parse('$_base/browser/updatemodel/$id'),
        headers: jsonHeaders,
        body: jsonEncode({'BpmnXml': xml}),
      );
      expect(put.statusCode, 200,
          reason: 'id=$id updatemodel failed: ${put.body}');

      // Verify: BpmnXml now persisted AND Nodes byte-identical.
      final after =
          jsonDecode((await http.get(Uri.parse('$_base/browser/getmodel/$id'),
                  headers: headers))
              .body) as Map<String, dynamic>;
      expect((after['BpmnXml'] as String?)?.isNotEmpty, true,
          reason: 'id=$id BpmnXml not persisted');
      expect(jsonEncode(after['Nodes']), jsonEncode(nodesJson),
          reason: 'id=$id Nodes changed — MIGRATION IS DESTRUCTIVE, STOP');
      stdout.writeln('        -> written, Nodes intact ✓');
      converted++;
    }

    stdout.writeln(
        '=== ${live ? 'migrated' : 'would migrate'}=$converted skipped=$skipped failed=$failed ===');
    expect(failed, 0, reason: 'some models failed to convert');
  }, timeout: const Timeout(Duration(minutes: 3)));
}
