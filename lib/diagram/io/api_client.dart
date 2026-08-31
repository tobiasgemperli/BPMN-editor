import 'dart:convert';
import 'package:http/http.dart' as http;
import 'bpmn_parser.dart';
import 'bpmn_serializer.dart';
import 'node_graph.dart';
import '../model/diagram_model.dart';

const _baseUrl = 'https://odoules.pfn.cz/rest2';
// QA test account (user id 22) — a clean account whose owned models make a
// realistic "My Flowcharts". The legacy `test`/`j5K_fv3sg` account (id 14)
// owns ~599 models and is a poor fit for that section.
const _username = 'qa_1787670944';
const _password = '8bkZwhLK';

String get _authHeader =>
    'Basic ${base64Encode(utf8.encode('$_username:$_password'))}';

/// Metadata returned by the Guide API for a model.
class ApiModelMeta {
  final String id;
  final String name;
  final String ownerName;
  final String ownerId;
  final DateTime createdAt;
  final int version;
  final List<String> keywords;
  final List<String> sources;
  final List<String> categories;

  ApiModelMeta({
    required this.id,
    required this.name,
    required this.ownerName,
    required this.ownerId,
    required this.createdAt,
    required this.version,
    required this.keywords,
    required this.sources,
    required this.categories,
  });

  factory ApiModelMeta.fromJson(Map<String, dynamic> json) => ApiModelMeta(
        id: json['Id']?.toString() ?? '',
        name: (json['Name'] as String?) ?? '',
        ownerName: (json['OwnerName'] as String?) ?? '',
        ownerId: (json['OwnerId'] as String?) ?? '',
        createdAt: DateTime.tryParse(json['Created'] ?? '') ?? DateTime.now(),
        version: (json['Version'] is int)
            ? json['Version'] as int
            : int.tryParse(json['Version']?.toString() ?? '') ?? 1,
        keywords: _stringList(json['Keywords']),
        sources: _stringList(json['Sources']),
        categories: _stringList(json['Categories']),
      );

  static List<String> _stringList(dynamic v) =>
      (v is List) ? v.map((e) => e.toString()).toList() : [];
}

/// Full model including the parsed diagram.
class ApiModel {
  final ApiModelMeta meta;
  final String? bpmnXml;
  final DiagramModel? diagram;

  ApiModel({required this.meta, this.bpmnXml, this.diagram});
}

class ApiException implements Exception {
  final int statusCode;
  final String message;
  ApiException(this.statusCode, this.message);

  @override
  String toString() => 'ApiException($statusCode): $message';
}

/// Client for the Guide REST API — Phase 1 BPMN storage endpoints.
class ApiClient {
  static final ApiClient instance = ApiClient._();
  ApiClient._();

  /// Constructor for testing with a custom HTTP client.
  ApiClient.withClient(this._httpClient);

  http.Client? _httpClient;
  http.Client get _client => _httpClient ?? http.Client();

  /// Cached id of the authenticated user (see [currentUserId]).
  int? _cachedUserId;

  final _parser = BpmnParser();
  final _serializer = BpmnSerializer();

  Map<String, String> get _headers => {'Authorization': _authHeader};
  Map<String, String> get _jsonHeaders => {
        'Authorization': _authHeader,
        'Content-Type': 'application/json; charset=utf-8',
      };

  /// List models from the server.
  Future<List<ApiModelMeta>> listModels() async {
    final response = await _client.post(
      Uri.parse('$_baseUrl/browser/list'),
      headers: _headers,
      body: jsonEncode({}),
    );
    if (response.statusCode != 200) {
      throw ApiException(response.statusCode, response.body);
    }
    final list = jsonDecode(response.body) as List;
    return list
        .map((e) => ApiModelMeta.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// The id of the currently authenticated user, from `/user/settings`.
  /// Cached after the first successful lookup.
  Future<int> currentUserId() async {
    if (_cachedUserId != null) return _cachedUserId!;
    final response = await _client.get(
      Uri.parse('$_baseUrl/user/settings'),
      headers: _headers,
    );
    if (response.statusCode != 200) {
      throw ApiException(response.statusCode, response.body);
    }
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final id = json['id'];
    final parsed = (id is int) ? id : int.tryParse(id?.toString() ?? '');
    if (parsed == null) {
      throw ApiException(response.statusCode, 'no user id in /user/settings');
    }
    return _cachedUserId = parsed;
  }

  /// List the models owned by the authenticated user, with their parsed
  /// diagrams. Powers the "My Flowcharts" section.
  ///
  /// The list endpoint returns metadata only (BpmnXml/Nodes are omitted), so
  /// each owned model is fetched via [getModel] to obtain its diagram.
  Future<List<ApiModel>> listMyModels() async {
    final myId = await currentUserId();
    final response = await _client.post(
      Uri.parse('$_baseUrl/browser/list/'),
      headers: _jsonHeaders,
      body: jsonEncode({}),
    );
    if (response.statusCode != 200) {
      throw ApiException(response.statusCode, response.body);
    }
    final list = jsonDecode(response.body) as List;
    final mineMeta = <ApiModelMeta>[];
    for (final e in list) {
      final json = e as Map<String, dynamic>;
      if (json['OwnerId']?.toString() != myId.toString()) continue;
      mineMeta.add(ApiModelMeta.fromJson(json));
    }
    return Future.wait(mineMeta.map((meta) async {
      try {
        return await getModel(meta.id);
      } catch (_) {
        return ApiModel(meta: meta);
      }
    }));
  }

  /// Get a single model by ID, including its BpmnXml.
  Future<ApiModel> getModel(String id) async {
    final response = await _client.get(
      Uri.parse('$_baseUrl/browser/getmodel/$id'),
      headers: _headers,
    );
    if (response.statusCode != 200) {
      throw ApiException(response.statusCode, response.body);
    }
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return _modelFromJson(json);
  }

  /// Build an [ApiModel] from a model JSON object (as returned by getmodel or
  /// inline in the list response). Parses BpmnXml first, falling back to the
  /// legacy Nodes flow format.
  ApiModel _modelFromJson(Map<String, dynamic> json) {
    final meta = ApiModelMeta.fromJson(json);
    final bpmnXml = json['BpmnXml'] as String?;
    DiagramModel? diagram;
    if (bpmnXml != null && bpmnXml.isNotEmpty) {
      try {
        diagram = _parser.parse(bpmnXml);
      } catch (_) {
        // If XML is malformed, return null diagram.
      }
    }
    // Legacy models carry no BpmnXml — reconstruct from the Nodes flow format.
    if (diagram == null && json['Nodes'] is List) {
      final built = diagramFromNodes(json['Nodes'] as List);
      if (built.nodes.isNotEmpty) diagram = built;
    }
    return ApiModel(meta: meta, bpmnXml: bpmnXml, diagram: diagram);
  }

  /// Create a new model on the server. Returns the created model metadata.
  Future<ApiModelMeta> saveModel({
    required String name,
    required DiagramModel diagram,
    List<String> keywords = const [],
    List<String> sources = const [],
    List<String> categories = const [],
  }) async {
    final bpmnXml = _serializer.serialize(diagram);
    final body = {
      'Name': name,
      'BpmnXml': bpmnXml,
      if (keywords.isNotEmpty) 'Keywords': keywords,
      if (sources.isNotEmpty) 'Sources': sources,
      if (categories.isNotEmpty) 'Categories': categories,
    };
    final response = await _client.post(
      Uri.parse('$_baseUrl/browser/savemodel'),
      headers: _jsonHeaders,
      body: jsonEncode(body),
    );
    if (response.statusCode != 200) {
      throw ApiException(response.statusCode, response.body);
    }
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return ApiModelMeta.fromJson(json);
  }

  /// Update an existing model on the server.
  Future<ApiModelMeta> updateModel(
    String id, {
    String? name,
    DiagramModel? diagram,
    List<String>? keywords,
  }) async {
    final body = <String, dynamic>{};
    if (name != null) body['Name'] = name;
    if (diagram != null) body['BpmnXml'] = _serializer.serialize(diagram);
    if (keywords != null) body['Keywords'] = keywords;

    final response = await _client.put(
      Uri.parse('$_baseUrl/browser/updatemodel/$id'),
      headers: _jsonHeaders,
      body: jsonEncode(body),
    );
    if (response.statusCode != 200) {
      throw ApiException(response.statusCode, response.body);
    }
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return ApiModelMeta.fromJson(json);
  }

  /// Delete a model on the server.
  Future<void> deleteModel(String id) async {
    final response = await _client.delete(
      Uri.parse('$_baseUrl/browser/deletemodel/$id'),
      headers: _headers,
    );
    if (response.statusCode != 200) {
      throw ApiException(response.statusCode, response.body);
    }
  }
}
