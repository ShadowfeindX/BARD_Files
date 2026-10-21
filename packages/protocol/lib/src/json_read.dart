import 'package:protocol_envelope/protocol_envelope.dart';

/// Typed readers over decoded JSON, throwing [ProtocolFormatException] with
/// the offending key so a bad frame is rejected with a readable reason.
extension JsonReader on JsonMap {
  /// A required string.
  String string(String key) {
    final value = this[key];
    if (value is String) return value;
    throw ProtocolFormatException('"$key" must be a string');
  }

  /// An optional string; `null` when absent or `null`.
  String? optString(String key) {
    final value = this[key];
    if (value == null) return null;
    if (value is String) return value;
    throw ProtocolFormatException('"$key" must be a string');
  }

  /// A required integer.
  int integer(String key) {
    final value = this[key];
    if (value is int) return value;
    throw ProtocolFormatException('"$key" must be an integer');
  }

  /// An optional integer.
  int? optInt(String key) {
    final value = this[key];
    if (value == null) return null;
    if (value is int) return value;
    throw ProtocolFormatException('"$key" must be an integer');
  }

  /// A required number.
  num number(String key) {
    final value = this[key];
    if (value is num && value.isFinite) return value;
    throw ProtocolFormatException('"$key" must be a number');
  }

  /// A required boolean.
  bool boolean(String key) {
    final value = this[key];
    if (value is bool) return value;
    throw ProtocolFormatException('"$key" must be true or false');
  }

  /// A boolean that falls back to [fallback] when absent (additive fields).
  bool boolOr(String key, bool fallback) =>
      this[key] == null ? fallback : boolean(key);

  /// An optional boolean; `null` when absent or `null`.
  bool? optBool(String key) {
    final value = this[key];
    if (value == null) return null;
    if (value is bool) return value;
    throw ProtocolFormatException('"$key" must be true or false');
  }

  /// A required object.
  JsonMap object(String key) => asMap(this[key], '"$key"');

  /// An optional object.
  JsonMap? optObject(String key) =>
      this[key] == null ? null : asMap(this[key], '"$key"');

  /// A required list.
  List<Object?> list(String key) {
    final value = this[key];
    if (value is List<Object?>) return value;
    throw ProtocolFormatException('"$key" must be a list');
  }

  /// A required list of objects.
  List<JsonMap> objectList(String key) => [
    for (final item in list(key)) asMap(item, 'items of "$key"'),
  ];

  /// A required object whose values are all strings.
  Map<String, String> stringMap(String key) => {
    for (final e in object(key).entries)
      e.key: e.value is String
          ? e.value as String
          : throw ProtocolFormatException('"$key.${e.key}" must be a string'),
  };

  /// A required object whose values are all integers.
  Map<String, int> intMap(String key) => {
    for (final e in object(key).entries)
      e.key: e.value is int
          ? e.value as int
          : throw ProtocolFormatException('"$key.${e.key}" must be an integer'),
  };
}

/// [value] as a JSON object, or a [ProtocolFormatException] naming [what].
JsonMap asMap(Object? value, String what) {
  if (value is Map && value.keys.every((k) => k is String)) {
    return Map<String, Object?>.from(value);
  }
  throw ProtocolFormatException('$what must be a JSON object');
}

/// Reads an enum value by [Enum.name].
T enumByName<T extends Enum>(List<T> values, JsonMap map, String key) {
  final name = map.string(key);
  for (final value in values) {
    if (value.name == name) return value;
  }
  throw ProtocolFormatException('"$key" has an unknown value "$name"');
}

/// Runs [build], turning constructor and engine errors into a
/// [ProtocolFormatException] that names [what].
T guarded<T>(String what, T Function() build) {
  try {
    return build();
  } on ProtocolFormatException {
    rethrow;
  } on FormatException catch (e) {
    throw ProtocolFormatException('$what: ${e.message}');
  } on ArgumentError catch (e) {
    throw ProtocolFormatException('$what: ${e.message}');
  }
}
