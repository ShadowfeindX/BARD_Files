import '../../deprecation.dart';
import '../../expr/expr.dart';
import '../../expr/expr_json.dart';
import 'pack_issue.dart';
import 'pending.dart';

/// Reads one JSON object of a pack file and reports every problem to an
/// [IssueLog].
///
/// Each getter marks its key as known. [finish] then reports every key that
/// no getter asked for, because unknown keys are errors (02 §Loading and
/// validation). Getters return `null` on a problem, so a parser can keep going
/// and the author sees every issue at once.
final class ObjectReader {
  ObjectReader._(this.log, this.file, this.path, this._json);

  /// Starts reading the top-level value of [file]. Returns `null` (and logs an
  /// error) when it is not an object.
  static ObjectReader? root(IssueLog log, String file, Object? json) {
    if (json is Map<String, Object?>) {
      return ObjectReader._(log, file, '', json);
    }
    log.error(file, '', 'The file must hold a JSON object.');
    return null;
  }

  /// Where issues go.
  final IssueLog log;

  /// Pack-relative file name.
  final String file;

  /// JSON path of this object inside [file]; empty at the top.
  final String path;

  final Map<String, Object?> _json;
  final Set<String> _known = {};

  /// The JSON path of [key] in this object.
  String at(String key) => path.isEmpty ? key : '$path.$key';

  /// Whether the object has [key] (even with a `null` value).
  bool has(String key) => _json.containsKey(key);

  /// Logs an error at [key].
  void error(String key, String message) => log.error(file, at(key), message);

  /// Logs a warning at [key].
  void warning(String key, String message) =>
      log.warning(file, at(key), message);

  Object? _take(String key) {
    _known.add(key);
    return _json[key];
  }

  bool _missing(String key) {
    if (_json.containsKey(key)) return false;
    _known.add(key);
    error(key, 'Missing required key.');
    return true;
  }

  /// A required non-empty string.
  String? string(String key) {
    if (_missing(key)) return null;
    return _asString(key, _take(key));
  }

  /// An optional non-empty string; `null` when absent.
  String? optionalString(String key) =>
      has(key) ? _asString(key, _take(key)) : null;

  /// A required string, or the pending marker (reported as a warning).
  String? stringOrPending(String key) {
    if (_missing(key)) return null;
    final value = _take(key);
    if (_pending(key, value)) return null;
    return _asString(key, value);
  }

  String? _asString(String key, Object? value) {
    if (value is String && value.isNotEmpty) return value;
    error(key, 'Expected a non-empty string.');
    return null;
  }

  /// A required whole number.
  int? integer(String key) {
    if (_missing(key)) return null;
    return _asInt(key, _take(key));
  }

  /// An optional whole number; `null` when absent.
  int? optionalInt(String key) => has(key) ? _asInt(key, _take(key)) : null;

  /// A required whole number, or the pending marker (a warning).
  int? intOrPending(String key) {
    if (_missing(key)) return null;
    final value = _take(key);
    if (_pending(key, value)) return null;
    return _asInt(key, value);
  }

  int? _asInt(String key, Object? value) {
    if (value is num &&
        value.isFinite &&
        value == value.truncate() &&
        value.abs() <= maxSafeInteger) {
      return value.toInt();
    }
    error(key, 'Expected a whole number.');
    return null;
  }

  /// A required number (whole or not).
  num? number(String key) {
    if (_missing(key)) return null;
    final value = _take(key);
    if (value is num && value.isFinite && value.abs() <= maxSafeInteger) {
      return value;
    }
    error(key, 'Expected a number.');
    return null;
  }

  /// An optional `true`/`false`; [orElse] when absent.
  bool? flag(String key, {bool orElse = false}) {
    if (!has(key)) return orElse;
    final value = _take(key);
    if (value is bool) return value;
    error(key, 'Expected true or false.');
    return null;
  }

  /// A required expression (see `decodeExpr`). [allowedVars] lists the `var`
  /// keys this placement may read. With [formula], dice are refused.
  Expr? expr(
    String key, {
    Set<String> allowedVars = const {},
    bool formula = false,
  }) {
    if (_missing(key)) return null;
    return _asExpr(key, _take(key), allowedVars, formula);
  }

  /// An optional expression; `null` when absent.
  Expr? optionalExpr(String key, {Set<String> allowedVars = const {}}) =>
      has(key) ? _asExpr(key, _take(key), allowedVars, false) : null;

  /// A required expression, or the pending marker (a warning).
  Expr? exprOrPending(String key, {Set<String> allowedVars = const {}}) {
    if (_missing(key)) return null;
    final value = _take(key);
    if (_pending(key, value)) return null;
    return _asExpr(key, value, allowedVars, false);
  }

  Expr? _asExpr(String key, Object? value, Set<String> vars, bool formula) {
    try {
      final expr = decodeExpr(value, allowedVars: vars, path: at(key));
      if (formula && expr.rollsDice) {
        error(key, 'A formula may not roll dice.');
        return null;
      }
      _reportUnruledExplode(value, at(key));
      return expr;
    } on FormatException catch (e) {
      // decodeExpr already puts the full path in its message.
      log.error(file, '', e.message);
      return null;
    }
  }

  /// Reports every dice node in [json] whose `explode` is `null` or absent as
  /// pending D (gap G3). Such dice roll like `explode: false` until ruled.
  ///
  /// Walks the raw JSON rather than the decoded tree so each warning carries
  /// the node's exact path. Only called after [json] decoded cleanly.
  void _reportUnruledExplode(Object? json, String nodePath) {
    if (json is! Map<String, Object?>) return;
    if (json['type'] == 'dice' && isPendingMarker(json['explode'])) {
      log.pendingD(file, '$nodePath.explode');
    }
    for (final listKey in const ['terms', 'pool', 'args']) {
      final list = json[listKey];
      if (list is! List<Object?>) continue;
      for (var i = 0; i < list.length; i++) {
        _reportUnruledExplode(list[i], '$nodePath.$listKey[$i]');
      }
    }
  }

  /// A required list of objects, each read by [each]. Entries that fail are
  /// left out of the result (their problems are logged).
  List<T> objects<T>(String key, T? Function(ObjectReader entry) each) {
    if (_missing(key)) return const [];
    return _asObjects(key, _take(key), each);
  }

  /// An optional list of objects; empty when absent.
  List<T> optionalObjects<T>(
    String key,
    T? Function(ObjectReader entry) each,
  ) => has(key) ? _asObjects(key, _take(key), each) : const [];

  List<T> _asObjects<T>(
    String key,
    Object? value,
    T? Function(ObjectReader entry) each,
  ) {
    if (value is! List<Object?>) {
      error(key, 'Expected a list.');
      return const [];
    }
    final result = <T>[];
    for (var i = 0; i < value.length; i++) {
      final item = value[i];
      final itemPath = '${at(key)}[$i]';
      if (item is! Map<String, Object?>) {
        log.error(file, itemPath, 'Expected an object.');
        continue;
      }
      final reader = ObjectReader._(log, file, itemPath, item);
      final parsed = each(reader);
      reader.finish();
      if (parsed != null) result.add(parsed);
    }
    return result;
  }

  /// A required nested object, read by [read].
  T? object<T>(String key, T? Function(ObjectReader reader) read) {
    if (_missing(key)) return null;
    final value = _take(key);
    if (value is! Map<String, Object?>) {
      error(key, 'Expected an object.');
      return null;
    }
    final reader = ObjectReader._(log, file, at(key), value);
    final parsed = read(reader);
    reader.finish();
    return parsed;
  }

  /// A required list of non-empty strings.
  List<String> strings(String key) {
    if (_missing(key)) return const [];
    return _asStrings(key, _take(key));
  }

  /// An optional list of non-empty strings; empty when absent.
  List<String> optionalStrings(String key) =>
      has(key) ? _asStrings(key, _take(key)) : const [];

  List<String> _asStrings(String key, Object? value) {
    if (value is List<Object?> &&
        value.every((v) => v is String && v.isNotEmpty)) {
      return value.cast<String>();
    }
    error(key, 'Expected a list of non-empty strings.');
    return const [];
  }

  /// A required list that must be empty: a slot the engine has no vocabulary
  /// for yet, such as a condition's `effects`.
  void emptyList(String key, String why) {
    if (_missing(key)) return;
    final value = _take(key);
    if (value is List<Object?> && value.isEmpty) return;
    error(key, 'Must be an empty list for now: $why');
  }

  /// An optional slot that only holds the pending marker until the engine
  /// supports its value (for example a gap D has not ruled). Present and
  /// pending is a warning; any other value is an error.
  void pendingSlot(String key) {
    if (!has(key)) return;
    final value = _take(key);
    if (_pending(key, value)) return;
    final hint = value is Map && value.isEmpty
        ? ' An empty object is not the pending marker (`null`); how the '
              'stripper writes markers is awaiting a ruling.'
        : '';
    error(
      key,
      'Only the pending marker is allowed here until D rules on it and the '
      'engine supports a value.$hint',
    );
  }

  /// An optional text field of the provisional pack shape: explanatory prose
  /// with no effect on rules. Must be a string; its value is not used.
  void prose(String key) {
    if (!has(key)) return;
    final value = _take(key);
    if (value is! String) error(key, 'Expected text.');
  }

  /// An optional value kept as raw JSON, unvalidated. Used only for content
  /// that is pending D as a whole (such as `occult.json`).
  Object? raw(String key) => has(key) ? _take(key) : null;

  /// The entry's optional `deprecated` record (P11). [packMajor] is the
  /// pack's own major version: `removeIn` must be later.
  Deprecation? deprecation(int? packMajor) {
    if (!has('deprecated')) return null;
    final record = object('deprecated', (r) => r._readDeprecation(packMajor));
    if (record != null) warning('deprecated', _describe(record));
    return record;
  }

  /// The entry's optional `deprecatedFields` map, field name to record. Each
  /// named field, and each `replacedBy`, must be a field the parser accepts on
  /// this entry (call this last, after every other getter).
  Map<String, Deprecation> deprecatedFields(int? packMajor) {
    if (!has('deprecatedFields')) return const {};
    final value = _take('deprecatedFields');
    if (value is! Map<String, Object?>) {
      error('deprecatedFields', 'Expected an object.');
      return const {};
    }
    final result = <String, Deprecation>{};
    for (final MapEntry(key: field, value: record) in value.entries) {
      final fieldPath = '${at('deprecatedFields')}.$field';
      if (!_known.contains(field) || field.startsWith('deprecated')) {
        log.error(
          file,
          fieldPath,
          'No field "$field" on this entry to deprecate.',
        );
        continue;
      }
      if (record is! Map<String, Object?>) {
        log.error(file, fieldPath, 'Expected a deprecation record.');
        continue;
      }
      final reader = ObjectReader._(log, file, fieldPath, record);
      final parsed = reader._readDeprecation(packMajor);
      reader.finish();
      final replacedBy = parsed?.replacedBy;
      if (replacedBy != null &&
          (!_known.contains(replacedBy) ||
              replacedBy.startsWith('deprecated') ||
              replacedBy == field)) {
        log.error(
          file,
          '$fieldPath.replacedBy',
          'No other field "$replacedBy" on this entry to replace it.',
        );
        continue;
      }
      if (parsed != null) {
        result[field] = parsed;
        log.warning(file, fieldPath, _describe(parsed));
      }
    }
    return result;
  }

  Deprecation? _readDeprecation(int? packMajor) {
    final since = string('since');
    final removeIn = integer('removeIn');
    final note = string('note');
    final replacedBy = optionalString('replacedBy');
    if (since != null && !isSemver(since)) {
      error('since', 'Expected a version such as 1.4.0.');
    }
    if (removeIn != null && packMajor != null && removeIn <= packMajor) {
      error('removeIn', 'Must be a later major than the pack\'s ($packMajor).');
    }
    if (since == null || removeIn == null || note == null) return null;
    return Deprecation(
      since: since,
      removeIn: removeIn,
      note: note,
      replacedBy: replacedBy,
    );
  }

  /// Every key of the object, for parsers that accept free-form keys (such
  /// as `strings/`). Marks them all as known.
  Map<String, Object?> takeAll() {
    _known.addAll(_json.keys);
    return _json;
  }

  /// Reports every key no getter asked for.
  void finish() {
    for (final key in _json.keys) {
      if (!_known.contains(key)) error(key, 'Unknown key.');
    }
  }

  static String _describe(Deprecation d) {
    final instead = d.replacedBy == null ? '' : ' Use ${d.replacedBy}.';
    return 'Deprecated since ${d.since}, removed in ${d.removeIn}: '
        '${d.note}$instead';
  }

  bool _pending(String key, Object? value) {
    if (!isPendingMarker(value)) return false;
    log.pendingD(file, at(key));
    return true;
  }
}

/// Whether [text] is a `major.minor.patch` version, with an optional
/// pre-release or build suffix.
bool isSemver(String text) => _semver.hasMatch(text);

final _semver = RegExp(r'^\d+\.\d+\.\d+([-+][0-9A-Za-z.\-+]*)?$');

/// The major of a version accepted by [isSemver].
int semverMajor(String version) => int.parse(version.split('.').first);
