import 'dart:convert';
import 'dart:typed_data';

/// A reference to another document, by path relative to the database root
/// (for example `campaigns/abc`). Stored as a Firestore `referenceValue`.
class FirestoreReference {
  /// Creates a reference.
  const FirestoreReference(this.path);

  /// Document path without the `projects/.../documents/` prefix.
  final String path;

  @override
  bool operator ==(Object other) =>
      other is FirestoreReference && other.path == path;

  @override
  int get hashCode => path.hashCode;

  @override
  String toString() => 'FirestoreReference($path)';
}

/// A geographic point, stored as a Firestore `geoPointValue`.
class FirestoreGeoPoint {
  /// Creates a point.
  const FirestoreGeoPoint(this.latitude, this.longitude);

  /// Degrees, -90 to 90.
  final double latitude;

  /// Degrees, -180 to 180.
  final double longitude;

  @override
  bool operator ==(Object other) =>
      other is FirestoreGeoPoint &&
      other.latitude == latitude &&
      other.longitude == longitude;

  @override
  int get hashCode => Object.hash(latitude, longitude);
}

/// Converts between plain Dart values and the Firestore REST `Value` JSON.
///
/// Dart type to Firestore type: `null` to null, `bool` to boolean, `int` to
/// integer (a decimal string on the wire), `double` to double, `String` to
/// string, `DateTime` to timestamp (always UTC), `Uint8List` to bytes
/// (base64), [FirestoreReference] to reference, [FirestoreGeoPoint] to
/// geoPoint, `List` to array, `Map<String, Object?>` to map.
class FirestoreValueCodec {
  /// Creates a codec. [documentsRoot] is the full resource name of the
  /// database's document root, `projects/P/databases/D/documents`; it is added
  /// to and stripped from reference values.
  const FirestoreValueCodec(this.documentsRoot);

  /// `projects/P/databases/D/documents`.
  final String documentsRoot;

  /// Encodes a Dart value as a Firestore `Value` object.
  Map<String, Object?> encode(Object? value) {
    if (value == null) return {'nullValue': null};
    if (value is bool) return {'booleanValue': value};
    if (value is int) return {'integerValue': value.toString()};
    if (value is double) {
      if (value.isNaN) return {'doubleValue': 'NaN'};
      if (value.isInfinite) {
        return {'doubleValue': value.isNegative ? '-Infinity' : 'Infinity'};
      }
      return {'doubleValue': value};
    }
    if (value is String) return {'stringValue': value};
    if (value is DateTime) {
      return {'timestampValue': value.toUtc().toIso8601String()};
    }
    if (value is Uint8List) return {'bytesValue': base64Encode(value)};
    if (value is FirestoreReference) {
      return {'referenceValue': '$documentsRoot/${value.path}'};
    }
    if (value is FirestoreGeoPoint) {
      return {
        'geoPointValue': {
          'latitude': value.latitude,
          'longitude': value.longitude,
        },
      };
    }
    if (value is List) {
      return {
        'arrayValue': {
          'values': [for (final e in value) encode(e)],
        },
      };
    }
    if (value is Map) {
      return {
        'mapValue': {'fields': encodeFields(value)},
      };
    }
    throw ArgumentError.value(
      value,
      'value',
      'unsupported Firestore value type ${value.runtimeType}',
    );
  }

  /// Encodes a map of field name to Dart value as a `fields` object.
  Map<String, Object?> encodeFields(Map<Object?, Object?> fields) {
    return {
      for (final entry in fields.entries)
        _fieldName(entry.key): encode(entry.value),
    };
  }

  String _fieldName(Object? key) {
    if (key is! String) {
      throw ArgumentError.value(key, 'key', 'field names must be strings');
    }
    return key;
  }

  /// Decodes a Firestore `Value` object into a Dart value.
  Object? decode(Map<String, Object?> value) {
    if (value.containsKey('nullValue')) return null;
    if (value['booleanValue'] case final bool b) return b;
    if (value['integerValue'] case final Object i) {
      return i is int ? i : int.parse(i as String);
    }
    if (value['doubleValue'] case final Object d) {
      if (d is num) return d.toDouble();
      return switch (d as String) {
        'NaN' => double.nan,
        'Infinity' => double.infinity,
        '-Infinity' => double.negativeInfinity,
        final other => double.parse(other),
      };
    }
    if (value['stringValue'] case final String s) return s;
    if (value['timestampValue'] case final String t) return parseTimestamp(t);
    if (value['bytesValue'] case final String b) {
      return Uint8List.fromList(base64Decode(b));
    }
    if (value['referenceValue'] case final String r) {
      final prefix = '$documentsRoot/';
      return FirestoreReference(
        r.startsWith(prefix) ? r.substring(prefix.length) : r,
      );
    }
    if (value['geoPointValue'] case final Map<String, Object?> g) {
      return FirestoreGeoPoint(
        (g['latitude'] as num?)?.toDouble() ?? 0,
        (g['longitude'] as num?)?.toDouble() ?? 0,
      );
    }
    if (value.containsKey('arrayValue')) {
      final array = value['arrayValue'] as Map<String, Object?>?;
      final values = (array?['values'] as List<Object?>?) ?? const [];
      return [for (final e in values) decode(e as Map<String, Object?>)];
    }
    if (value.containsKey('mapValue')) {
      final map = value['mapValue'] as Map<String, Object?>?;
      return decodeFields(map?['fields'] as Map<String, Object?>?);
    }
    throw FormatException('unknown Firestore value: ${value.keys.join(', ')}');
  }

  /// Decodes a `fields` object (which may be absent for an empty document).
  Map<String, Object?> decodeFields(Map<String, Object?>? fields) {
    return {
      for (final entry in (fields ?? const <String, Object?>{}).entries)
        entry.key: decode(entry.value! as Map<String, Object?>),
    };
  }

  /// Parses a Firestore timestamp. The server sends up to nanoseconds; Dart keeps microseconds, so
  /// the extra fraction digits are dropped.
  static DateTime parseTimestamp(String text) {
    final trimmed = text.replaceFirstMapped(
      RegExp(r'(\.\d{6})\d+'),
      (m) => m.group(1)!,
    );
    return DateTime.parse(trimmed).toUtc();
  }
}
