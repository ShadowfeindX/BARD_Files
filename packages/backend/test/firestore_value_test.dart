import 'dart:typed_data';

import 'package:backend/backend.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const codec = FirestoreValueCodec('projects/p/databases/(default)/documents');

  test('round-trips every supported type', () {
    final data = <String, Object?>{
      'n': null,
      'b': true,
      'i': 9007199254740993,
      'd': 1.5,
      's': 'hé',
      't': DateTime.utc(2026, 11, 5, 9, 30, 1, 123, 456),
      'y': Uint8List.fromList([1, 2, 3]),
      'r': const FirestoreReference('campaigns/abc'),
      'g': const FirestoreGeoPoint(1.5, -2.5),
      'a': [1, 'x', null],
      'm': {
        'inner': {'k': 1},
      },
      'e': <Object?>[],
      'em': <String, Object?>{},
    };
    final decoded = codec.decodeFields(codec.encodeFields(data));
    expect(decoded, data);
  });

  test('wire shapes', () {
    expect(codec.encode(7), {'integerValue': '7'});
    expect(codec.encode(2.0), {'doubleValue': 2.0});
    expect(codec.encode(double.nan), {'doubleValue': 'NaN'});
    expect(codec.encode(double.negativeInfinity), {'doubleValue': '-Infinity'});
    expect(codec.encode(const FirestoreReference('a/b')), {
      'referenceValue': 'projects/p/databases/(default)/documents/a/b',
    });
    expect(codec.encode(DateTime.utc(2026, 1, 2)), {
      'timestampValue': '2026-01-02T00:00:00.000Z',
    });
  });

  test('decodes nanosecond timestamps and string numbers', () {
    expect(
      codec.decode({'timestampValue': '2026-11-05T09:30:01.123456789Z'}),
      DateTime.utc(2026, 11, 5, 9, 30, 1, 123, 456),
    );
    expect(codec.decode({'doubleValue': 'Infinity'}), double.infinity);
    expect(codec.decode({'integerValue': '-5'}), -5);
    expect(codec.decode({'arrayValue': <String, Object?>{}}), <Object?>[]);
  });

  test('rejects unsupported types and unknown values', () {
    expect(() => codec.encode(Object()), throwsArgumentError);
    expect(() => codec.encodeFields({1: 'x'}), throwsArgumentError);
    expect(() => codec.decode({'mystery': 1}), throwsFormatException);
  });
}
