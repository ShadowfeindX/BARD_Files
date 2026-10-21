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

/// Characters that show nothing: zero-width space and joiners, word joiner,
/// byte-order mark, soft hyphen, bidi marks and embeddings, invisible math
/// operators, Hangul fillers and variation selectors. Text made only of these
/// and whitespace counts as empty. The UI mirrors this list.
final RegExp invisiblePhoneChars = RegExp(
  '[\u00AD\u115F\u1160\u180E\u200B-\u200F\u202A-\u202E\u2060-\u2064'
  '\u3164\uFE00-\uFE0F\uFEFF\uFFA0]',
);
