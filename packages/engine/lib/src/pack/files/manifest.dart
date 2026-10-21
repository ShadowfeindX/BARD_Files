/// The pack file `manifest.json`: id, version, engine API, tier, requirements.
///
/// Value types and their parser, kept together so a change to this file's
/// shape (Provisional, pending D) is a local edit.
library;

import '../../equality.dart';
import '../load/object_reader.dart';

/// Content tier of a pack (02 §Content kinds and tiers). Proposed values.
enum PackTier {
  /// D's official content.
  core,

  /// A GM's pack submitted to the public library.
  library,

  /// A GM's campaign or private pack.
  campaign,

  /// Content for one operation only (F3 part 3).
  operation,
}

/// Library verification state (02 §Manifest).
enum PackVerification {
  /// Reviewed and approved by a verifier.
  verified,

  /// Not reviewed yet, or verification was revoked.
  pending,
}

/// Another pack this one builds on (`requires` in the manifest).
final class PackDependency {
  /// Creates a [PackDependency].
  const PackDependency({required this.id, required this.range});

  /// Id of the required pack.
  final String id;

  /// Version range of the required pack, such as `^0.0.1`.
  final String range;

  @override
  bool operator ==(Object other) =>
      other is PackDependency && other.id == id && other.range == range;

  @override
  int get hashCode => Object.hash(PackDependency, id, range);

  @override
  String toString() => 'PackDependency($id, $range)';
}

/// A pack's `manifest.json` (02 §Manifest).
final class PackManifest {
  /// Creates a [PackManifest].
  PackManifest({
    required this.id,
    required this.name,
    required this.version,
    required this.engineApi,
    required this.publisher,
    required this.tier,
    required List<PackDependency> requires,
    required this.verification,
    this.contentHash,
  }) : requires = List.unmodifiable(requires);

  /// Pack id.
  final String id;

  /// Display name.
  final String name;

  /// The pack's own semantic version.
  final String version;

  /// Engine API major the pack targets.
  final int engineApi;

  /// Who publishes the pack.
  final String publisher;

  /// Content tier (02 §Content kinds and tiers). Proposed field.
  final PackTier tier;

  /// Packs this one builds on.
  final List<PackDependency> requires;

  /// Library verification state.
  final PackVerification verification;

  /// Hash written by tooling, if any; checked against the computed one.
  final String? contentHash;

  @override
  bool operator ==(Object other) =>
      other is PackManifest &&
      other.id == id &&
      other.name == name &&
      other.version == version &&
      other.engineApi == engineApi &&
      other.publisher == publisher &&
      other.tier == tier &&
      listEquals(other.requires, requires) &&
      other.verification == verification &&
      other.contentHash == contentHash;

  @override
  int get hashCode => Object.hash(
    PackManifest,
    id,
    name,
    version,
    engineApi,
    publisher,
    tier,
    Object.hashAll(requires),
    verification,
    contentHash,
  );

  @override
  String toString() => 'PackManifest($id, $name, $version)';
}

/// Parses `manifest.json`.
PackManifest? parseManifest(ObjectReader r) {
  final id = r.string('id');
  final name = r.string('name');
  final version = r.string('version');
  final engineApi = r.integer('engineApi');
  final publisher = r.string('publisher');
  final tier = _enum(r, 'tier', PackTier.values);
  final requires = r.objects('requires', (d) {
    final id = d.string('id');
    final range = d.string('range');
    if (id == null || range == null) return null;
    return PackDependency(id: id, range: range);
  });
  final verification = _enum(r, 'verification', PackVerification.values);
  final contentHash = r.optionalString('contentHash');
  if (version != null && !isSemver(version)) {
    r.error('version', 'Expected a version such as 1.3.1.');
    return null;
  }
  if (id == null ||
      name == null ||
      version == null ||
      engineApi == null ||
      publisher == null ||
      tier == null ||
      verification == null) {
    return null;
  }
  return PackManifest(
    id: id,
    name: name,
    version: version,
    engineApi: engineApi,
    publisher: publisher,
    tier: tier,
    requires: requires,
    verification: verification,
    contentHash: contentHash,
  );
}

T? _enum<T extends Enum>(ObjectReader r, String key, List<T> values) {
  final text = r.string(key);
  if (text == null) return null;
  for (final value in values) {
    if (value.name == text) return value;
  }
  r.error(key, 'Expected one of: ${values.map((v) => v.name).join(', ')}.');
  return null;
}
