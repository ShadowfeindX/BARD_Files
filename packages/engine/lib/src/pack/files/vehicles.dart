/// The pack file `vehicles.json`: vehicle performance and durability categories.
///
/// Value types and their parser, kept together so a change to this file's
/// shape (Provisional, pending D) is a local edit.
library;

import '../../deprecation.dart';
import '../../immutable_map.dart';
import '../load/object_reader.dart';

/// A vehicle performance category and its driving modifier (rulebook §6).
final class VehiclePerformance {
  /// Creates a [VehiclePerformance].
  const VehiclePerformance({
    required this.key,
    required this.name,
    this.drivingModifier,
    this.deprecated,
    this.deprecatedFields = const ImmutableMap.empty(),
  });

  /// Category key.
  final String key;

  /// Display name.
  final String name;

  /// Modifier to driving checks; `null` when not set.
  final int? drivingModifier;

  /// The entry's deprecation record (P11), if it is going away.
  final Deprecation? deprecated;

  /// Deprecation records for single fields, by field name.
  final ImmutableMap<String, Deprecation> deprecatedFields;

  @override
  bool operator ==(Object other) =>
      other is VehiclePerformance &&
      other.key == key &&
      other.name == name &&
      other.drivingModifier == drivingModifier &&
      other.deprecated == deprecated &&
      other.deprecatedFields == deprecatedFields;

  @override
  int get hashCode => Object.hash(
    VehiclePerformance,
    key,
    name,
    drivingModifier,
    deprecated,
    deprecatedFields,
  );

  @override
  String toString() => 'VehiclePerformance($key, $name, $drivingModifier)';
}

/// A vehicle durability category (rulebook §6).
final class VehicleDurability {
  /// Creates a [VehicleDurability].
  const VehicleDurability({
    required this.key,
    required this.name,
    this.hp,
    this.hpOpenEnded = false,
    this.capacity,
    this.printedAs,
    this.deprecated,
    this.deprecatedFields = const ImmutableMap.empty(),
  });

  /// Category key.
  final String key;

  /// Display name.
  final String name;

  /// Hit points; `null` when not set.
  final int? hp;

  /// Whether the value is a floor, not a cap.
  final bool hpOpenEnded;

  /// Passenger capacity, as text.
  final String? capacity;

  /// How the book prints the row, for display.
  final String? printedAs;

  /// The entry's deprecation record (P11), if it is going away.
  final Deprecation? deprecated;

  /// Deprecation records for single fields, by field name.
  final ImmutableMap<String, Deprecation> deprecatedFields;

  @override
  bool operator ==(Object other) =>
      other is VehicleDurability &&
      other.key == key &&
      other.name == name &&
      other.hp == hp &&
      other.hpOpenEnded == hpOpenEnded &&
      other.capacity == capacity &&
      other.printedAs == printedAs &&
      other.deprecated == deprecated &&
      other.deprecatedFields == deprecatedFields;

  @override
  int get hashCode => Object.hash(
    VehicleDurability,
    key,
    name,
    hp,
    hpOpenEnded,
    capacity,
    printedAs,
    deprecated,
    deprecatedFields,
  );

  @override
  String toString() => 'VehicleDurability($key, $name, $hp)';
}

/// What `vehicles.json` holds.
typedef VehiclesFile = ({
  List<VehiclePerformance> performance,
  List<VehicleDurability> durability,
});

/// Parses `vehicles.json`.
VehiclesFile parseVehicles(ObjectReader r, int? packMajor) {
  final performance = r.objects('performance', (p) {
    final key = p.string('key');
    final name = p.string('name');
    final modifier = p.intOrPending('drivingModifier');
    final deprecated = p.deprecation(packMajor);
    final fields = p.deprecatedFields(packMajor);
    if (key == null || name == null) return null;
    return VehiclePerformance(
      key: key,
      name: name,
      drivingModifier: modifier,
      deprecated: deprecated,
      deprecatedFields: ImmutableMap.of(fields),
    );
  });
  final durability = r.objects('durability', (d) {
    final key = d.string('key');
    final name = d.string('name');
    final hp = d.intOrPending('hp');
    final hpOpenEnded = d.flag('hpOpenEnded');
    final capacity = d.optionalString('capacity');
    final printedAs = d.optionalString('printedAs');
    final deprecated = d.deprecation(packMajor);
    final fields = d.deprecatedFields(packMajor);
    if (key == null || name == null || hpOpenEnded == null) return null;
    return VehicleDurability(
      key: key,
      name: name,
      hp: hp,
      hpOpenEnded: hpOpenEnded,
      capacity: capacity,
      printedAs: printedAs,
      deprecated: deprecated,
      deprecatedFields: ImmutableMap.of(fields),
    );
  });
  return (performance: performance, durability: durability);
}
