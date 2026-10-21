import 'json.dart';

/// A semantic engine version, as carried in the envelope's `e`:
/// `major.minor.patch` with an optional pre-release (`1.0.0-dev.1`).
///
/// Ordering follows Semantic Versioning 2.0.0 precedence, so a pre-release
/// sorts before its release (`1.0.0-dev.1 < 1.0.0`). Build metadata (`+...`)
/// and leading zeros are refused (Proposed: the spec does not fix the string
/// format).
final class EngineVersion implements Comparable<EngineVersion> {
  /// Creates a version; all parts must be non-negative. [preRelease] holds the
  /// dot-separated pre-release identifiers, empty for a release.
  const EngineVersion(
    this.major,
    this.minor,
    this.patch, [
    this.preRelease = const [],
  ]) : assert(major >= 0 && minor >= 0 && patch >= 0);

  /// Parses `1.4.0` or `1.0.0-dev.1`.
  factory EngineVersion.parse(String text) {
    final match = _pattern.firstMatch(text);
    if (match == null) {
      throw ProtocolFormatException(
        '"$text" is not a major.minor.patch[-pre.release] version',
      );
    }
    // tryParse: a huge number must be a format error, not a raw FormatException.
    final parts = [for (var i = 1; i <= 3; i++) int.tryParse(match[i]!)];
    if (parts.contains(null)) {
      throw ProtocolFormatException('"$text" has a part that is too large');
    }
    final pre = match[4];
    final identifiers = pre == null ? const <String>[] : pre.split('.');
    for (final id in identifiers) {
      if (_numeric.hasMatch(id) && int.tryParse(id) == null) {
        throw ProtocolFormatException('"$text" has a part that is too large');
      }
    }
    return EngineVersion(
      parts[0]!,
      parts[1]!,
      parts[2]!,
      List.unmodifiable(identifiers),
    );
  }

  static final _pattern = RegExp(
    r'^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)'
    r'(?:-((?:0|[1-9]\d*|\d*[A-Za-z-][0-9A-Za-z-]*)'
    r'(?:\.(?:0|[1-9]\d*|\d*[A-Za-z-][0-9A-Za-z-]*))*))?$',
  );

  static final _numeric = RegExp(r'^\d+$');

  /// Incompatible changes; a different major is reachable only by migration.
  final int major;

  /// Additive changes within a major.
  final int minor;

  /// Fixes within a minor.
  final int patch;

  /// Pre-release identifiers (`["dev", "1"]`), empty for a release.
  final List<String> preRelease;

  /// Whether this is a pre-release.
  bool get isPreRelease => preRelease.isNotEmpty;

  @override
  int compareTo(EngineVersion other) {
    if (major != other.major) return major.compareTo(other.major);
    if (minor != other.minor) return minor.compareTo(other.minor);
    if (patch != other.patch) return patch.compareTo(other.patch);
    // A release outranks any of its pre-releases.
    if (preRelease.isEmpty && other.preRelease.isEmpty) return 0;
    if (preRelease.isEmpty) return 1;
    if (other.preRelease.isEmpty) return -1;
    for (var i = 0; i < preRelease.length && i < other.preRelease.length; i++) {
      final byId = _compareIdentifier(preRelease[i], other.preRelease[i]);
      if (byId != 0) return byId;
    }
    return preRelease.length.compareTo(other.preRelease.length);
  }

  // Numeric identifiers compare as numbers and rank below alphanumeric ones;
  // alphanumeric identifiers compare in ASCII order (SemVer 2.0.0, item 11).
  static int _compareIdentifier(String a, String b) {
    final aNum = _numeric.hasMatch(a) ? int.parse(a) : null;
    final bNum = _numeric.hasMatch(b) ? int.parse(b) : null;
    if (aNum != null && bNum != null) return aNum.compareTo(bNum);
    if (aNum != null) return -1;
    if (bNum != null) return 1;
    return a.compareTo(b);
  }

  /// Whether this version is lower than [other].
  bool operator <(EngineVersion other) => compareTo(other) < 0;

  @override
  bool operator ==(Object other) =>
      other is EngineVersion && compareTo(other) == 0;

  @override
  int get hashCode =>
      Object.hash(major, minor, patch, Object.hashAll(preRelease));

  @override
  String toString() =>
      '$major.$minor.$patch${isPreRelease ? '-${preRelease.join('.')}' : ''}';
}
