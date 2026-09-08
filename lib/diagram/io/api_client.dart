import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart' show MediaType;
import 'bpmn_parser.dart';
import 'bpmn_serializer.dart';
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
  final String description;
  final List<String> keywords;
  final List<String> sources;
  final List<String> categories;

  /// Id of the model's custom thumbnail file (served at `/files/file/{id}`),
  /// or empty when the model has no uploaded thumbnail.
  final String thumbnailFileId;

  ApiModelMeta({
    required this.id,
    required this.name,
    required this.ownerName,
    required this.ownerId,
    required this.createdAt,
    required this.version,
    this.description = '',
    required this.keywords,
    required this.sources,
    required this.categories,
    this.thumbnailFileId = '',
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
        description: (json['Description'] as String?) ?? '',
        keywords: _stringList(json['Keywords']),
        sources: _stringList(json['Sources']),
        categories: _stringList(json['Categories']),
        thumbnailFileId: (json['ThumbnailFileId'] as String?) ?? '',
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

/// A user's public profile, from `/user/profile/{id}`.
class ApiUserProfile {
  final int id;
  final String name;
  final int followerCount;
  final int followingCount;
  final bool isFollowedByMe;

  ApiUserProfile({
    required this.id,
    required this.name,
    required this.followerCount,
    required this.followingCount,
    required this.isFollowedByMe,
  });

  ApiUserProfile copyWith({int? followerCount, bool? isFollowedByMe}) =>
      ApiUserProfile(
        id: id,
        name: name,
        followerCount: followerCount ?? this.followerCount,
        followingCount: followingCount,
        isFollowedByMe: isFollowedByMe ?? this.isFollowedByMe,
      );

  factory ApiUserProfile.fromJson(Map<String, dynamic> json) {
    int asInt(dynamic v) =>
        (v is int) ? v : int.tryParse(v?.toString() ?? '') ?? 0;
    final first = (json['Name'] as String?)?.trim() ?? '';
    final last = (json['Surname'] as String?)?.trim() ?? '';
    final name = [first, last].where((s) => s.isNotEmpty).join(' ');
    return ApiUserProfile(
      id: asInt(json['Id']),
      name: name,
      followerCount: asInt(json['FollowerCount']),
      followingCount: asInt(json['FollowingCount']),
      isFollowedByMe: json['IsFollowedByMe'] == true,
    );
  }
}

/// A lightweight reference to a user, as returned in follower/following lists.
class ApiUserRef {
  final int id;
  final String name;
  final String uname;

  ApiUserRef({required this.id, required this.name, required this.uname});

  factory ApiUserRef.fromJson(Map<String, dynamic> json) {
    final first = (json['Name'] as String?)?.trim() ?? '';
    final last = (json['Surname'] as String?)?.trim() ?? '';
    return ApiUserRef(
      id: int.tryParse(json['Id']?.toString() ?? '') ?? 0,
      name: [first, last].where((s) => s.isNotEmpty).join(' '),
      uname: (json['Uname'] as String?) ?? '',
    );
  }
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

  /// Fetch a user's public profile (name, follower counts, follow state).
  Future<ApiUserProfile> getUserProfile(int userId) async {
    final response = await _client.get(
      Uri.parse('$_baseUrl/user/profile/$userId'),
      headers: _headers,
    );
    if (response.statusCode != 200) {
      throw ApiException(response.statusCode, response.body);
    }
    return ApiUserProfile.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>);
  }

  /// Decoded avatar bytes for [userId] from `/user/thumbnail/{id}`, or null if
  /// the user has no picture. Cached per user (including the "no image" result).
  Future<Uint8List?> getUserThumbnail(int userId) =>
      _thumbnailCache.putIfAbsent(userId, () => _fetchThumbnail(userId));

  final Map<int, Future<Uint8List?>> _thumbnailCache = {};

  Future<Uint8List?> _fetchThumbnail(int userId) async {
    try {
      final response = await _client.get(
        Uri.parse('$_baseUrl/user/thumbnail/$userId'),
        headers: _headers,
      );
      if (response.statusCode != 200) return null;
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final t = json['thumbnail'];
      if (t is! String || t.isEmpty) return null; // `false` when no avatar
      return _decodeAvatar(t);
    } catch (_) {
      return null;
    }
  }

  /// Decode an avatar payload, peeling any extra base64 layers until the bytes
  /// look like a real image (the backend has historically wrapped these).
  Uint8List? _decodeAvatar(String data) {
    var s = data.trim();
    final comma = s.indexOf(',');
    if (s.startsWith('data:') && comma != -1) s = s.substring(comma + 1);
    Uint8List? bytes;
    for (var i = 0; i < 4; i++) {
      try {
        bytes = base64Decode(s);
      } catch (_) {
        return bytes;
      }
      if (_looksLikeImage(bytes)) return bytes;
      try {
        s = utf8.decode(bytes).trim(); // maybe another base64 layer
      } catch (_) {
        return bytes; // not text — treat as the (unrecognized) image
      }
    }
    return bytes;
  }

  bool _looksLikeImage(Uint8List b) {
    if (b.length < 4) return false;
    if (b[0] == 0x89 && b[1] == 0x50 && b[2] == 0x4E && b[3] == 0x47) {
      return true; // PNG
    }
    if (b[0] == 0xFF && b[1] == 0xD8 && b[2] == 0xFF) return true; // JPEG
    if (b[0] == 0x47 && b[1] == 0x49 && b[2] == 0x46) return true; // GIF
    if (b.length >= 12 &&
        b[0] == 0x52 && b[1] == 0x49 && b[2] == 0x46 && b[3] == 0x46 &&
        b[8] == 0x57 && b[9] == 0x45 && b[10] == 0x42 && b[11] == 0x50) {
      return true; // WEBP
    }
    return false;
  }

  /// Users the authenticated user follows.
  Future<List<ApiUserRef>> getFollowing() => _userList('following');

  /// Users who follow the authenticated user.
  Future<List<ApiUserRef>> getFollowers() => _userList('followers');

  Future<List<ApiUserRef>> _userList(String which) async {
    final response = await _client.get(
      Uri.parse('$_baseUrl/user/$which'),
      headers: _headers,
    );
    if (response.statusCode != 200) {
      throw ApiException(response.statusCode, response.body);
    }
    final list = jsonDecode(response.body) as List;
    return list
        .map((e) => ApiUserRef.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Ids of the users the authenticated user follows. Reliable source of
  /// follow state — `/user/profile`'s `IsFollowedByMe` is currently unreliable.
  Future<Set<int>> followingUserIds() async =>
      (await getFollowing()).map((u) => u.id).toSet();

  /// Follow a user (idempotent server-side).
  Future<void> followUser(int userId) async {
    final response = await _client.post(
      Uri.parse('$_baseUrl/user/follow/$userId'),
      headers: _headers,
    );
    if (response.statusCode != 200) {
      throw ApiException(response.statusCode, response.body);
    }
  }

  /// Unfollow a user (idempotent server-side).
  Future<void> unfollowUser(int userId) async {
    final response = await _client.delete(
      Uri.parse('$_baseUrl/user/follow/$userId'),
      headers: _headers,
    );
    if (response.statusCode != 200) {
      throw ApiException(response.statusCode, response.body);
    }
  }

  /// List the models owned by the authenticated user, with their parsed
  /// diagrams. Powers the "My Flowcharts" section.
  Future<List<ApiModel>> listMyModels() async {
    return listModelsByOwner(await currentUserId());
  }

  /// List the models owned by [ownerId], with their parsed diagrams (powers
  /// the creator profile screen).
  ///
  /// Uses the server-side `ownerid` filter; the client-side owner check is a
  /// safety net in case the filter is ignored. The list endpoint returns
  /// metadata only (BpmnXml/Nodes are omitted), so each owned model is fetched
  /// via [getModel] to obtain its diagram.
  Future<List<ApiModel>> listModelsByOwner(int ownerId) async {
    final response = await _client.post(
      Uri.parse('$_baseUrl/browser/list/'),
      headers: _jsonHeaders,
      body: jsonEncode({'ownerid': ownerId}),
    );
    if (response.statusCode != 200) {
      throw ApiException(response.statusCode, response.body);
    }
    final list = jsonDecode(response.body) as List;
    final ownedMeta = <ApiModelMeta>[];
    for (final e in list) {
      final json = e as Map<String, dynamic>;
      if (json['OwnerId']?.toString() != ownerId.toString()) continue;
      ownedMeta.add(ApiModelMeta.fromJson(json));
    }
    return Future.wait(ownedMeta.map((meta) async {
      try {
        return await getModel(meta.id);
      } catch (_) {
        return ApiModel(meta: meta);
      }
    }));
  }

  /// Like [listModelsByOwner] but metadata only — no per-model [getModel], so
  /// it stays a single request. Diagrams are fetched lazily when a model is
  /// opened. Powers the fast "My Flowcharts" list.
  Future<List<ApiModelMeta>> listModelsByOwnerMeta(int ownerId) async {
    final response = await _client.post(
      Uri.parse('$_baseUrl/browser/list/'),
      headers: _jsonHeaders,
      body: jsonEncode({'ownerid': ownerId}),
    );
    if (response.statusCode != 200) {
      throw ApiException(response.statusCode, response.body);
    }
    final list = jsonDecode(response.body) as List;
    return [
      for (final e in list)
        if ((e as Map<String, dynamic>)['OwnerId']?.toString() ==
            ownerId.toString())
          ApiModelMeta.fromJson(e),
    ];
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
  /// inline in the list response). Reads BpmnXml only; the legacy Nodes flow
  /// format is no longer consulted (all models are migrated to BpmnXml).
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
    return ApiModel(meta: meta, bpmnXml: bpmnXml, diagram: diagram);
  }

  /// Create a new model on the server. Returns the created model metadata.
  Future<ApiModelMeta> saveModel({
    required String name,
    required DiagramModel diagram,
    List<String> keywords = const [],
    List<String> sources = const [],
    List<String> categories = const [],
    String? thumbnailFileId,
  }) async {
    final bpmnXml = _serializer.serialize(diagram);
    final body = {
      'Name': name,
      'BpmnXml': bpmnXml,
      if (keywords.isNotEmpty) 'Keywords': keywords,
      if (sources.isNotEmpty) 'Sources': sources,
      if (categories.isNotEmpty) 'Categories': categories,
      if (thumbnailFileId != null && thumbnailFileId.isNotEmpty)
        'ThumbnailFileId': thumbnailFileId,
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

  /// Update an existing model on the server. Any field left null is untouched.
  Future<ApiModelMeta> updateModel(
    String id, {
    String? name,
    DiagramModel? diagram,
    String? description,
    List<String>? keywords,
    List<String>? sources,
    List<String>? categories,
    String? thumbnailFileId,
  }) async {
    final body = <String, dynamic>{};
    if (name != null) body['Name'] = name;
    if (diagram != null) body['BpmnXml'] = _serializer.serialize(diagram);
    if (description != null) body['Description'] = description;
    if (keywords != null) body['Keywords'] = keywords;
    if (sources != null) body['Sources'] = sources;
    if (categories != null) body['Categories'] = categories;
    if (thumbnailFileId != null) body['ThumbnailFileId'] = thumbnailFileId;

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

  /// Upload [bytes] to the file store and return the assigned file id
  /// (e.g. "f_x0recF"), which can be used as a model's [ThumbnailFileId] or
  /// fetched back via [getFileBytes].
  Future<String> uploadFile(
    Uint8List bytes, {
    String filename = 'thumbnail.png',
    String mime = 'image/png',
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$_baseUrl/files/upload'),
    )
      ..headers['Authorization'] = _authHeader
      ..files.add(http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: filename,
        contentType: MediaType.parse(mime),
      ));
    final response =
        await http.Response.fromStream(await _client.send(request));
    if (response.statusCode != 200) {
      throw ApiException(response.statusCode, response.body);
    }
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final fileId = json['Id'] as String?;
    if (fileId == null || fileId.isEmpty) {
      throw ApiException(response.statusCode, 'no file id in upload response');
    }
    return fileId;
  }

  final Map<String, Future<Uint8List?>> _fileCache = {};

  /// Bytes of the stored file [fileId] (served at `/files/file/{id}`), or null
  /// when the id is empty or the fetch fails. Cached per id.
  Future<Uint8List?> getFileBytes(String fileId) {
    if (fileId.isEmpty) return Future.value(null);
    return _fileCache.putIfAbsent(fileId, () async {
      try {
        final response = await _client.get(
          Uri.parse('$_baseUrl/files/file/$fileId'),
          headers: _headers,
        );
        if (response.statusCode != 200) return null;
        return response.bodyBytes;
      } catch (_) {
        return null;
      }
    });
  }
}
