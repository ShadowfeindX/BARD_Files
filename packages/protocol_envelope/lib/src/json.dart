/// A decoded JSON object.
typedef JsonMap = Map<String, Object?>;

/// Thrown when a frame or message body is not valid protocol JSON.
class ProtocolFormatException extends FormatException {
  /// Creates an exception describing what was wrong with the frame.
  const ProtocolFormatException(super.message);
}

/// Casts [value] to a [JsonMap], or throws naming [what].
JsonMap asJsonMap(Object? value, String what) {
  if (value is Map<String, Object?>) return value;
  if (value is Map && value.keys.every((k) => k is String)) {
    return Map<String, Object?>.from(value);
  }
  throw ProtocolFormatException('$what must be a JSON object');
}

/// Reads a required string field.
String reqString(JsonMap map, String key) {
  final value = map[key];
  if (value is String) return value;
  throw ProtocolFormatException('"$key" must be a string');
}

/// Reads an optional string field (absent or null gives null).
String? optString(JsonMap map, String key) {
  final value = map[key];
  if (value == null) return null;
  if (value is String) return value;
  throw ProtocolFormatException('"$key" must be a string');
}

/// Reads a required integer field.
int reqInt(JsonMap map, String key) {
  final value = map[key];
  if (value is int) return value;
  throw ProtocolFormatException('"$key" must be an integer');
}

/// Reads an optional integer field (absent or null gives null).
int? optInt(JsonMap map, String key) {
  final value = map[key];
  if (value == null) return null;
  if (value is int) return value;
  throw ProtocolFormatException('"$key" must be an integer');
}

/// Reads a required object field.
JsonMap reqMap(JsonMap map, String key) => asJsonMap(map[key], '"$key"');

/// Reads an optional object field (absent or null gives null).
JsonMap? optMap(JsonMap map, String key) =>
    map[key] == null ? null : asJsonMap(map[key], '"$key"');

/// Reads a required list of objects.
List<JsonMap> reqMapList(JsonMap map, String key) {
  final value = map[key];
  if (value is! List) throw ProtocolFormatException('"$key" must be a list');
  return [for (final item in value) asJsonMap(item, 'items of "$key"')];
}

/// Reads a required integer field that must be at least [min].
int reqIntMin(JsonMap map, String key, int min) {
  final value = reqInt(map, key);
  if (value < min) throw ProtocolFormatException('"$key" must be >= $min');
  return value;
}
