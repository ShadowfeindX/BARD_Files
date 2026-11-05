import 'dart:convert';
import 'dart:typed_data';

import 'firestore_document.dart';
import 'firestore_exception.dart';
import 'firestore_query.dart';
import 'firestore_retry_policy.dart';
import 'firestore_transport.dart';
import 'firestore_value.dart';
import 'id_token_provider.dart';

/// Hand-written Firestore REST v1 client for the desktop app.
///
/// No collection path is known here: callers pass document paths relative to
/// the database root (`campaigns/abc`), so the collection layout (S-7) lives
/// above this class. Every request asks [IdTokenProvider] for a token (FS2) and
/// sends it as a Bearer header; Security Rules do the authorizing.
class FirestoreClient {
  /// Creates a client for [projectId].
  ///
  /// The project id is supplied at run time and must never be written into
  /// committed files. [delay] replaces the real wait between retries (tests).
  ///
  /// Every method reports bad arguments (a malformed path, conflicting
  /// preconditions) as an error of the returned future, so always `await`
  /// calls. A token provider that throws is not wrapped and is not retried.
  FirestoreClient({
    required this.projectId,
    required this.tokenProvider,
    required this.transport,
    this.databaseId = '(default)',
    this.retryPolicy = const DefaultFirestoreRetryPolicy(),
    this.host = 'https://firestore.googleapis.com',
    Future<void> Function(Duration)? delay,
  }) : _delay = delay ?? Future<void>.delayed,
       codec = FirestoreValueCodec(
         'projects/$projectId/databases/$databaseId/documents',
       );

  /// The Google Cloud project id.
  final String projectId;

  /// The database id; `(default)` unless a named database is used.
  final String databaseId;

  /// Source of ID tokens, asked once per attempt.
  final IdTokenProvider tokenProvider;

  /// The network layer.
  final FirestoreTransport transport;

  /// What to do after a failed attempt.
  final FirestoreRetryPolicy retryPolicy;

  /// Base URL; the emulator is `http://localhost:8080`.
  final String host;

  /// The value codec bound to this database.
  final FirestoreValueCodec codec;

  final Future<void> Function(Duration) _delay;

  String get _documentsUrl =>
      '$host/v1/projects/$projectId/databases/$databaseId/documents';

  /// Reads one document; returns `null` when it does not exist.
  Future<FirestoreDocument?> getDocument(String path) async {
    final uri = Uri.parse('$_documentsUrl/${_documentPath(path)}');
    try {
      final json = await _send('GET', uri);
      return _toDocument(_expectMap(json));
    } on FirestoreException catch (e) {
      if (e.kind == FirestoreErrorKind.notFound) return null;
      rethrow;
    }
  }

  /// Creates the document at [path], failing with
  /// [FirestoreErrorKind.alreadyExists] if it is already there.
  Future<FirestoreDocument> createDocument(
    String path,
    Map<String, Object?> data,
  ) async {
    final segments = _segments(path, wantDocument: true);
    final parent = segments.sublist(0, segments.length - 2).join('/');
    return await _create(
      parent,
      segments[segments.length - 2],
      segments.last,
      data,
    );
  }

  /// Creates a document in the collection [collectionPath] with a
  /// server-generated id. Not idempotent, so it is never retried after a
  /// transient failure.
  Future<FirestoreDocument> addDocument(
    String collectionPath,
    Map<String, Object?> data,
  ) async {
    final segments = _segments(collectionPath, wantDocument: false);
    final parent = segments.sublist(0, segments.length - 1).join('/');
    return await _create(parent, segments.last, null, data);
  }

  Future<FirestoreDocument> _create(
    String parent,
    String collectionId,
    String? documentId,
    Map<String, Object?> data,
  ) async {
    final encodedParent = parent.isEmpty
        ? ''
        : '/${parent.split('/').map(Uri.encodeComponent).join('/')}';
    final base = '$_documentsUrl$encodedParent';
    final uri = Uri.parse('$base/${Uri.encodeComponent(collectionId)}').replace(
      queryParameters: documentId == null ? null : {'documentId': documentId},
    );
    final json = await _send(
      'POST',
      uri,
      body: {'fields': codec.encodeFields(data)},
      idempotent: documentId != null,
    );
    return _toDocument(_expectMap(json));
  }

  /// Writes [data] as the whole document at [path]: replaces it if it exists,
  /// creates it otherwise.
  ///
  /// [mustExist] adds an existence precondition (`true` = update only,
  /// `false` = create only). [ifUpdateToken] succeeds only if the stored
  /// document still has that update time (optimistic concurrency). Pass
  /// [FirestoreDocument.updateToken] of the version you read.
  Future<FirestoreDocument> setDocument(
    String path,
    Map<String, Object?> data, {
    bool? mustExist,
    String? ifUpdateToken,
  }) => _patch(path, data, null, mustExist, ifUpdateToken);

  /// Writes only the fields named in [fieldPaths] (dotted paths such as
  /// `meta.owner`), taking their values from [data]; a path missing from
  /// [data] deletes that field. Other fields are left alone. Creates the
  /// document if it does not exist, unless [mustExist] is `true`.
  Future<FirestoreDocument> patchDocument(
    String path,
    Map<String, Object?> data, {
    required List<String> fieldPaths,
    bool? mustExist,
    String? ifUpdateToken,
  }) => _patch(path, data, fieldPaths, mustExist, ifUpdateToken);

  Future<FirestoreDocument> _patch(
    String path,
    Map<String, Object?> data,
    List<String>? fieldPaths,
    bool? mustExist,
    String? ifUpdateToken,
  ) async {
    if (fieldPaths != null && fieldPaths.isEmpty) {
      // An empty mask would drop the parameter and overwrite the document.
      throw ArgumentError.value(fieldPaths, 'fieldPaths', 'must not be empty');
    }
    final query = <String, List<String>>{
      if (fieldPaths != null)
        'updateMask.fieldPaths': [for (final f in fieldPaths) _quoteField(f)],
      ..._preconditionParams(mustExist, ifUpdateToken),
    };
    final uri = _withQuery('$_documentsUrl/${_documentPath(path)}', query);
    final json = await _send(
      'PATCH',
      uri,
      body: {'fields': codec.encodeFields(data)},
    );
    return _toDocument(_expectMap(json));
  }

  /// Deletes the document at [path]. Deleting a missing document succeeds
  /// unless [mustExist] is `true`.
  Future<void> deleteDocument(
    String path, {
    bool? mustExist,
    String? ifUpdateToken,
  }) async {
    final uri = _withQuery(
      '$_documentsUrl/${_documentPath(path)}',
      _preconditionParams(mustExist, ifUpdateToken),
    );
    await _send('DELETE', uri);
  }

  /// Runs [query] under [parentPath] (`''` for the database root, or a
  /// document path for a sub-collection) and returns the matching documents.
  Future<List<FirestoreDocument>> runQuery(
    FirestoreQuery query, {
    String parentPath = '',
  }) async {
    final parent = parentPath.isEmpty ? '' : '/${_documentPath(parentPath)}';
    final uri = Uri.parse('$_documentsUrl$parent:runQuery');
    final json = await _send(
      'POST',
      uri,
      body: {'structuredQuery': _encodeQuery(query)},
    );
    if (json is! List) throw _badShape('a list', json);
    return [
      for (final row in json)
        if (_expectMap(row)['document'] case final Map<String, Object?> doc)
          _toDocument(doc),
    ];
  }

  // ---- request pipeline --------------------------------------------------

  /// Sends one logical request, asking for a token on every attempt and
  /// applying [retryPolicy] on failure. Returns the decoded JSON body.
  Future<Object?> _send(
    String method,
    Uri uri, {
    Map<String, Object?>? body,
    bool idempotent = true,
  }) async {
    final payload = body == null
        ? null
        : Uint8List.fromList(utf8.encode(jsonEncode(body)));
    var attempt = 0;
    var refreshed = false;
    var forceRefresh = false;
    while (true) {
      attempt++;
      final error = await _attempt(method, uri, payload, forceRefresh);
      if (error.result != null) return error.result!.value;
      final decision = retryPolicy.decide(
        error: error.error!,
        attempt: attempt,
        idempotent: idempotent,
        tokenAlreadyRefreshed: refreshed,
      );
      switch (decision) {
        case GiveUp():
          throw error.error!;
        case RetryAfter(:final delay):
          forceRefresh = false;
          await _delay(delay);
        case RefreshTokenAndRetry():
          refreshed = true;
          forceRefresh = true;
      }
    }
  }

  Future<_Outcome> _attempt(
    String method,
    Uri uri,
    Uint8List? payload,
    bool forceRefresh,
  ) async {
    // The token is fetched per attempt and never stored (FS2).
    final token = await tokenProvider.getIdToken(forceRefresh: forceRefresh);
    final headers = {
      if (token != null) 'Authorization': 'Bearer $token',
      'Accept': 'application/json',
      if (payload != null) 'Content-Type': 'application/json',
    };
    final FirestoreHttpResponse response;
    try {
      response = await transport.send(
        method: method,
        uri: uri,
        headers: headers,
        body: payload,
      );
    } on FirestoreTransportException catch (e) {
      return _Outcome.failure(
        FirestoreException(
          kind: FirestoreErrorKind.unavailable,
          message: e.message,
        ),
      );
    }
    final decoded = _tryDecode(response.body);
    if (response.isSuccess) return _Outcome.success(decoded);
    return _Outcome.failure(
      FirestoreException.fromResponse(
        response.statusCode,
        _errorObject(decoded),
      ),
    );
  }

  static Object? _tryDecode(String body) {
    if (body.trim().isEmpty) return null;
    try {
      return jsonDecode(body);
    } on FormatException {
      return null;
    }
  }

  /// Error bodies are `{"error":{..}}`; `runQuery` wraps them in a list.
  static Map<String, Object?>? _errorObject(Object? decoded) {
    final first = decoded is List && decoded.isNotEmpty
        ? decoded.first
        : decoded;
    if (first is Map<String, Object?>) {
      final error = first['error'];
      if (error is Map<String, Object?>) return error;
    }
    return null;
  }

  static Map<String, Object?> _expectMap(Object? json) =>
      json is Map<String, Object?> ? json : throw _badShape('an object', json);

  static FirestoreException _badShape(String wanted, Object? got) =>
      FirestoreException(
        kind: FirestoreErrorKind.unknown,
        message: 'expected $wanted in the response, got ${got.runtimeType}',
      );

  // ---- encoding helpers --------------------------------------------------

  FirestoreDocument _toDocument(Map<String, Object?> json) {
    try {
      return _decodeDocument(json);
    } on TypeError {
      throw _badShape('a document', json);
    } on FormatException {
      throw _badShape('a document', json);
    }
  }

  FirestoreDocument _decodeDocument(Map<String, Object?> json) {
    final name = json['name']! as String;
    final prefix = '${codec.documentsRoot}/';
    return FirestoreDocument(
      path: name.startsWith(prefix) ? name.substring(prefix.length) : name,
      data: codec.decodeFields(json['fields'] as Map<String, Object?>?),
      createTime: _time(json['createTime']),
      updateTime: _time(json['updateTime']),
      updateToken: json['updateTime'] as String?,
    );
  }

  static DateTime? _time(Object? value) =>
      value is String ? FirestoreValueCodec.parseTimestamp(value) : null;

  Map<String, Object?> _encodeQuery(FirestoreQuery q) {
    return {
      if (q.select != null)
        'select': {
          'fields': [
            for (final f in q.select!) {'fieldPath': _quoteField(f)},
          ],
        },
      'from': [
        {'collectionId': q.collectionId, 'allDescendants': q.allDescendants},
      ],
      if (q.where != null) 'where': _encodeFilter(q.where!),
      if (q.orderBy.isNotEmpty)
        'orderBy': [
          for (final o in q.orderBy)
            {
              'field': {'fieldPath': _quoteField(o.field)},
              'direction': o.descending ? 'DESCENDING' : 'ASCENDING',
            },
        ],
      if (q.startAt != null)
        'startAt': _encodeCursor(q.startAt!, isStart: true),
      if (q.endAt != null) 'endAt': _encodeCursor(q.endAt!, isStart: false),
      if (q.offset != null) 'offset': q.offset,
      if (q.limit != null) 'limit': q.limit,
    };
  }

  Map<String, Object?> _encodeCursor(QueryCursor c, {required bool isStart}) =>
      {
        'values': [for (final v in c.values) codec.encode(v)],
        // REST `before` means "before the position": it includes the position
        // for a start cursor and excludes it for an end cursor.
        'before': isStart ? c.inclusive : !c.inclusive,
      };

  Map<String, Object?> _encodeFilter(QueryFilter f) {
    switch (f) {
      case AndFilter(:final filters):
        return {
          'compositeFilter': {
            'op': 'AND',
            'filters': [for (final x in filters) _encodeFilter(x)],
          },
        };
      case OrFilter(:final filters):
        return {
          'compositeFilter': {
            'op': 'OR',
            'filters': [for (final x in filters) _encodeFilter(x)],
          },
        };
      case FieldFilter(:final field, :final op, :final value):
        final ref = {'fieldPath': _quoteField(field)};
        final isUnaryValue = value == null || (value is double && value.isNaN);
        if (isUnaryValue && (op == FilterOp.equal || op == FilterOp.notEqual)) {
          final negate = op == FilterOp.notEqual;
          final name = value == null
              ? (negate ? 'IS_NOT_NULL' : 'IS_NULL')
              : (negate ? 'IS_NOT_NAN' : 'IS_NAN');
          return {
            'unaryFilter': {'op': name, 'field': ref},
          };
        }
        return {
          'fieldFilter': {
            'field': ref,
            'op': op.wireName,
            'value': codec.encode(value),
          },
        };
    }
  }

  static Map<String, List<String>> _preconditionParams(
    bool? mustExist,
    String? ifUpdateToken,
  ) {
    if (mustExist != null && ifUpdateToken != null) {
      throw ArgumentError('pass either mustExist or ifUpdateToken, not both');
    }
    return {
      if (mustExist != null) 'currentDocument.exists': ['$mustExist'],
      if (ifUpdateToken != null) 'currentDocument.updateTime': [ifUpdateToken],
    };
  }

  /// Builds a URL with repeated query parameters (`updateMask.fieldPaths`).
  static Uri _withQuery(String url, Map<String, List<String>> params) {
    if (params.isEmpty) return Uri.parse(url);
    final pairs = [
      for (final e in params.entries)
        for (final v in e.value)
          '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(v)}',
    ];
    return Uri.parse('$url?${pairs.join('&')}');
  }

  /// Quotes a dotted field path so each segment that is not a plain
  /// identifier is wrapped in backticks, as Firestore field paths require.
  static String _quoteField(String path) {
    final plain = RegExp(r'^[a-zA-Z_][a-zA-Z_0-9]*$');
    return path
        .split('.')
        .map(
          (s) => plain.hasMatch(s)
              ? s
              : '`${s.replaceAll(r'\', r'\\').replaceAll('`', r'\`')}`',
        )
        .join('.');
  }

  /// Validates [path] as a document path and returns it with each segment
  /// URL-encoded.
  static String _documentPath(String path) =>
      _segments(path, wantDocument: true).map(Uri.encodeComponent).join('/');

  static List<String> _segments(String path, {required bool wantDocument}) {
    final segments = path.split('/');
    final isDocument = segments.length.isEven;
    if (path.isEmpty ||
        segments.any((s) => s.isEmpty) ||
        isDocument != wantDocument) {
      throw ArgumentError.value(
        path,
        'path',
        wantDocument
            ? 'must be a document path (an even number of segments)'
            : 'must be a collection path (an odd number of segments)',
      );
    }
    return segments;
  }
}

/// A successful decoded body, boxed so `null` (an empty body) is distinct
/// from "no result".
class _Success {
  const _Success(this.value);
  final Object? value;
}

class _Outcome {
  _Outcome.success(Object? value) : result = _Success(value), error = null;
  _Outcome.failure(this.error) : result = null;
  final _Success? result;
  final FirestoreException? error;
}
