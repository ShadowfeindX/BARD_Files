/// Source of dice faces handed to `decide`.
///
/// The engine never creates randomness itself (01 §RNG). Production uses the
/// `xrandom` adapter in the `session` package; tests use [ScriptedRng].
abstract interface class Rng {
  /// Rolls one die with [sides] faces and returns a face in `1..sides`.
  ///
  /// [sides] is at least 1.
  int rollDie(int sides);

  /// How many draws this source has consumed so far.
  ///
  /// Rolling events record the range of draws they used, so any roll can be
  /// audited from the seed. What one "draw" is belongs to the implementation;
  /// the engine only reads the counter before and after rolling.
  int get drawCount;
}

/// [Rng] that returns fixed faces in order, for tests.
///
/// Each face is one draw. Throws a [StateError] when the script runs out and an
/// [ArgumentError] when a scripted face does not fit the die being rolled, so
/// a test with the wrong script fails loudly instead of rolling something
/// else.
final class ScriptedRng implements Rng {
  /// Creates an RNG that returns [faces] one at a time.
  ScriptedRng(Iterable<int> faces) : _faces = List.unmodifiable(faces);

  final List<int> _faces;
  int _next = 0;

  @override
  int get drawCount => _next;

  /// Faces not yet returned.
  int get remaining => _faces.length - _next;

  @override
  int rollDie(int sides) {
    if (sides < 1) {
      throw ArgumentError.value(sides, 'sides', 'must be at least 1');
    }
    if (_next >= _faces.length) {
      throw StateError(
        'ScriptedRng exhausted after ${_faces.length} faces '
        '(asked for a d$sides).',
      );
    }
    final face = _faces[_next];
    if (face < 1 || face > sides) {
      throw ArgumentError(
        'Scripted face $face at position $_next does not fit a d$sides.',
      );
    }
    _next++;
    return face;
  }
}
