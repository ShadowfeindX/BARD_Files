/// Who a phone message is from or to (04 §In-game phone).
library;

import 'actor.dart';
import 'ids.dart';

/// Longest phone message, in UTF-16 code units: the same cap the relay's
/// rules enforce on a message's text (06 §Realtime Database model), so a
/// message the engine accepts is never refused on the wire.
const int maxPhoneTextUnits = 2000;

/// One end of a phone message.
sealed class PhoneParty {
  const PhoneParty();
}

/// The Handler (GM), speaking as themselves.
final class PhoneGm extends PhoneParty {
  /// Creates the party.
  const PhoneGm();

  @override
  bool operator ==(Object other) => other is PhoneGm;

  @override
  int get hashCode => (PhoneGm).hashCode;

  @override
  String toString() => 'PhoneGm()';
}

/// A player's alias.
final class PhoneAlias extends PhoneParty {
  /// Creates the party.
  const PhoneAlias(this.alias);

  /// The alias.
  final AliasId alias;

  @override
  bool operator ==(Object other) => other is PhoneAlias && other.alias == alias;

  @override
  int get hashCode => Object.hash(PhoneAlias, alias);

  @override
  String toString() => 'PhoneAlias(${alias.value})';
}

/// A GM-run entity (an entity with no owning alias). The GM answers as it.
final class PhoneNpc extends PhoneParty {
  /// Creates the party.
  const PhoneNpc(this.entity);

  /// The entity.
  final EntityId entity;

  @override
  bool operator ==(Object other) => other is PhoneNpc && other.entity == entity;

  @override
  int get hashCode => Object.hash(PhoneNpc, entity);

  @override
  String toString() => 'PhoneNpc(${entity.value})';
}
