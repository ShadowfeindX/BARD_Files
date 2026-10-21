import 'package:engine/engine.dart';

/// Whose eyes an event stream is for (04 §Perspectives).
sealed class Perspective {
  const Perspective();
}

/// The GM sees every event in full.
final class GmPerspective extends Perspective {
  /// The GM perspective.
  const GmPerspective();
}

/// A player sees public events, events addressed to their alias, and the
/// fact that redacted ones happened.
final class PlayerPerspective extends Perspective {
  /// The perspective of [alias].
  const PlayerPerspective(this.alias);

  /// The alias.
  final AliasId alias;
}

/// A shared screen sees public events only.
final class TablePerspective extends Perspective {
  /// The table perspective.
  const TablePerspective();
}

/// What a perspective receives of one event.
enum Delivery {
  /// The whole event.
  full,

  /// Only that it happened ("the GM rolled something").
  redacted,

  /// Nothing about its content, only its place in the sequence. Keeps `seq`
  /// consecutive for the recipient (03 §Ordering); Proposed: it does reveal
  /// that a GM-only or other-alias event exists.
  hidden,
}

/// Applies 03 §Visibility and perspectives.
Delivery deliveryFor(Visibility visibility, Perspective perspective) {
  if (perspective is GmPerspective) return Delivery.full;
  return switch (visibility) {
    Public() => Delivery.full,
    Redacted() => Delivery.redacted,
    GmOnly() => Delivery.hidden,
    AliasesOnly(:final aliases) =>
      perspective is PlayerPerspective && aliases.contains(perspective.alias)
          ? Delivery.full
          : Delivery.hidden,
  };
}

/// What a perspective is allowed to read of [event] it receives in full.
///
/// The store, the GM and the codec keep the whole event; this only shapes the
/// copy a player or the table gets (Proposed, gate condition on row 7):
///
/// - `overriddenFrom` is dropped, so players read the final value of a
///   consequence the GM edited in review, not the original;
/// - an event addressed to several aliases is narrowed to the viewer's own
///   alias, so `BroadcastDelivered` does not reveal who else received it
///   (co-recipient visibility is open in 11 §Messaging).
///
/// Events addressed to a single alias need no narrowing. Add a case here when
/// an event can address several aliases or carries GM-only detail.
Event projectFor(Event event, Perspective perspective) {
  if (perspective is GmPerspective) return event;
  final viewer = perspective is PlayerPerspective ? perspective.alias : null;
  Visibility narrowed(Visibility v) =>
      v is AliasesOnly && viewer != null && v.aliases.contains(viewer)
      ? AliasesOnly({viewer})
      : v;
  return switch (event) {
    DamageApplied() => DamageApplied(
      entity: event.entity,
      amount: event.amount,
      check: event.check,
      actor: event.actor,
      visibility: narrowed(event.visibility),
    ),
    SanityLost() => SanityLost(
      entity: event.entity,
      amount: event.amount,
      check: event.check,
      actor: event.actor,
      visibility: narrowed(event.visibility),
    ),
    ConditionApplied() => ConditionApplied(
      entity: event.entity,
      condition: event.condition,
      check: event.check,
      actor: event.actor,
      visibility: narrowed(event.visibility),
    ),
    BroadcastDelivered() => BroadcastDelivered(
      text: event.text,
      actor: event.actor,
      visibility: narrowed(event.visibility) as AliasesOnly,
    ),
    _ => event,
  };
}
