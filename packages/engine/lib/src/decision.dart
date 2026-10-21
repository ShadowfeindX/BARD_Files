import 'equality.dart';
import 'events/events.dart';

/// The outcome of `Engine.decide` (01 §Public API surface, Proposed).
sealed class Decision {
  const Decision();
}

/// The command is valid; these events record what happened, in order.
final class Accepted extends Decision {
  /// Creates an accepted decision.
  Accepted(List<Event> events) : events = List.unmodifiable(events);

  /// The events to sequence, store and apply.
  final List<Event> events;

  @override
  bool operator ==(Object other) =>
      other is Accepted && listEquals(other.events, events);

  @override
  int get hashCode => Object.hash(Accepted, Object.hashAll(events));

  @override
  String toString() => 'Accepted($events)';
}

/// The command is not valid; it produces no events.
final class Rejected extends Decision {
  /// Creates a rejected decision.
  const Rejected(this.reason);

  /// Why the command was refused.
  final Rejection reason;

  @override
  bool operator ==(Object other) => other is Rejected && other.reason == reason;

  @override
  int get hashCode => Object.hash(Rejected, reason);

  @override
  String toString() => 'Rejected($reason)';
}

/// Machine-readable reason for a rejection. Proposed.
enum RejectionCode {
  /// The operation has not started yet.
  notStarted,

  /// The operation has already started.
  alreadyStarted,

  /// A key does not exist in the pack (attribute, skill, tier, ...).
  unknownPackKey,

  /// A value is outside what the pack allows, or a field is malformed.
  invalidValue,

  /// The command names an entity that does not exist.
  unknownEntity,

  /// A pack expression could not be evaluated.
  evaluationFailed,
}

/// Why a command was refused: a [code] for programs and a [message] for
/// people.
final class Rejection {
  /// Creates a rejection.
  const Rejection(this.code, this.message);

  /// Machine-readable reason.
  final RejectionCode code;

  /// Readable explanation, shown to whoever sent the command.
  final String message;

  @override
  bool operator ==(Object other) =>
      other is Rejection && other.code == code && other.message == message;

  @override
  int get hashCode => Object.hash(code, message);

  @override
  String toString() => 'Rejection(${code.name}: $message)';
}
