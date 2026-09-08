// One-time batch: generate + upload a PNG thumbnail for every model that
// doesn't have one, and set its ThumbnailFileId. Precomputes the card preview
// so the app never re-renders the diagram just to show a thumbnail.
//
// Non-destructive: only uploads files and sets ThumbnailFileId (nothing else).
// Idempotent: skips models that already have a thumbnail.
//
//   Dry-run:  ADMIN_USER=gtobias ADMIN_PASS=... flutter test test/backfill_thumbnails_test.dart
//   Sample:   THUMB_LIMIT=5 MIGRATE_LIVE=1 ADMIN_USER=... ADMIN_PASS=... flutter test ...
//   Full run: MIGRATE_LIVE=1 ADMIN_USER=... ADMIN_PASS=... flutter test ...
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart' show MediaType;
import 'package:bpmn_editor/diagram/io/bpmn_parser.dart';
import 'package:bpmn_editor/diagram/render/diagram_rasterizer.dart';

const _base = 'https://odoules.pfn.cz/rest2';

void main() {
  // Note: intentionally NOT calling TestWidgetsFlutterBinding.ensureInitialized()
  // — it mocks HTTP (returns 400). dart:ui toImage() works without it here.
  final env = Platform.environment;
  final user = env['ADMIN_USER'];
  final pass = env['ADMIN_PASS'];
  final live = env['MIGRATE_LIVE'] == '1';
  final limit = int.tryParse(env['THUMB_LIMIT'] ?? '');

  test('backfill model thumbnails', () async {
    if (user == null || pass == null) {
      markTestSkipped('set ADMIN_USER/ADMIN_PASS to run the backfill tool');
      return;
    }
    final auth = 'Basic ${base64Encode(utf8.encode('$user:$pass'))}';
    final headers = {'Authorization': auth};
    final jsonHeaders = {...headers, 'Content-Type': 'application/json'};
    final parser = BpmnParser();

    // Discover: models with content but no thumbnail yet.
    final listResp = await http.post(Uri.parse('$_base/browser/list/'),
        headers: jsonHeaders, body: jsonEncode({'withContent': true}));
    expect(listResp.statusCode, 200, reason: listResp.body);
    var targets = (jsonDecode(listResp.body) as List)
        .cast<Map<String, dynamic>>()
        .where((m) =>
            ((m['ThumbnailFileId'] as String?) ?? '').isEmpty &&
            ((m['BpmnXml'] as String?) ?? '').isNotEmpty)
        .toList();
    if (limit != null) targets = targets.take(limit).toList();

    stdout.writeln(live
        ? '=== LIVE thumbnail backfill ==='
        : '=== DRY RUN — set MIGRATE_LIVE=1 to write ===');
    stdout.writeln('  ${targets.length} models to process');

    var done = 0, skipped = 0, failed = 0;
    for (final m in targets) {
      final id = '${m['Id']}';
      try {
        final diagram = parser.parse(m['BpmnXml'] as String);
        final png = await rasterizeDiagramPng(diagram);
        if (png == null) {
          skipped++;
          continue;
        }
        if (!live) {
          stdout.writeln('  id=$id  ${m['Name']}  pngBytes=${png.length}  [would upload]');
          done++;
          continue;
        }
        // Upload the PNG.
        final upReq = http.MultipartRequest(
            'POST', Uri.parse('$_base/files/upload'))
          ..headers['Authorization'] = auth
          ..files.add(http.MultipartFile.fromBytes('file', png,
              filename: 'thumb_$id.png',
              contentType: MediaType('image', 'png')));
        final up = await http.Response.fromStream(await upReq.send());
        expect(up.statusCode, 200, reason: 'id=$id upload: ${up.body}');
        final fileId = (jsonDecode(up.body) as Map)['Id'] as String;

        // Attach it (only ThumbnailFileId).
        final put = await http.put(Uri.parse('$_base/browser/updatemodel/$id'),
            headers: jsonHeaders,
            body: jsonEncode({'ThumbnailFileId': fileId}));
        expect(put.statusCode, 200, reason: 'id=$id updatemodel: ${put.body}');
        stdout.writeln('  id=$id  $fileId  ✓');
        done++;
      } catch (e) {
        stdout.writeln('  id=$id  FAIL: $e');
        failed++;
      }
    }
    stdout.writeln('=== ${live ? 'uploaded' : 'would upload'}=$done skipped=$skipped failed=$failed ===');
    expect(failed, 0);
  }, timeout: const Timeout(Duration(minutes: 20)));
}
