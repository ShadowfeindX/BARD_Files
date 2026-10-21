import 'json.dart';

/// A `major.minor.patch` engine version, as carried in the envelope's `e`.
final class EngineVersion implements Comparable<EngineVersion> {
  /// Creates a version; all parts must be non-negative.
  const EngineVersion(this.major, this.minor, this.patch)
    : assert(major >= 0 && minor >= 0 && patch >= 0);

  /// Parses `1.4.0`. Proposed: pre-release and build suffixes and leading
  /// zeros are refused (the spec does not fix the string format).
  factory EngineVersion.parse(String text) {
    final match = _pattern.firstMatch(text);
    if (match == null) {
      throw ProtocolFormatException(
        '"$text" is not a major.minor.patch version',
      );
    }
    // tryParse: a huge number must be a format error, not a raw FormatException.
    final parts = [for (var i = 1; i <= 3; i++) int.tryParse(match[i]!)];
    if (parts.contains(null)) {
      throw ProtocolFormatException('"$text" has a part that is too large');
    }
    return EngineVersion(parts[0]!, parts[1]!, parts[2]!);
  }

  static final _pattern = RegExp(r'^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)$');

  /// Incompatible changes; a different major is reachable only by migration.
  final int major;

  /// Additive changes within a major.
  final int minor;

  /// Fixes within a minor.
  final int patch;

  @override
  int compareTo(EngineVersion other) {
    if (major != other.major) return major.compareTo(other.major);
    if (minor != other.minor) return minor.compareTo(other.minor);
    return patch.compareTo(other.patch);
  }

  /// Whether this version is lower than [other].
  bool operator <(EngineVersion other) => compareTo(other) < 0;

  @override
  bool operator ==(Object other) =>
      other is EngineVersion && compareTo(other) == 0;

  @override
  int get hashCode => Object.hash(major, minor, patch);

  @override
  String toString() => '$major.$minor.$patch';
}
