part of 'commands.dart';

/// Commands handled by `MessagingSystem` (11 §Messaging).
sealed class MessagingCommand extends Command {
  const MessagingCommand();
}

/// The GM sends [text] only to the aliases whose agent meets [condition]
/// (stat-gated broadcast, approved by R).
///
/// The GM's engine decides who qualifies; the UI never does. The condition
/// stays GM-only: recipients get the text, not why they got it.
final class BroadcastToQualifying extends MessagingCommand {
  /// Creates the command.
  const BroadcastToQualifying({
    required this.text,
    required this.condition,
    this.actor = const GmActor(),
  });

  /// The message.
  final String text;

  /// Who receives it.
  final Condition condition;

  @override
  final Actor actor;

  @override
  bool operator ==(Object other) =>
      other is BroadcastToQualifying &&
      other.text == text &&
      other.condition == condition &&
      other.actor == actor;

  @override
  int get hashCode =>
      Object.hash(BroadcastToQualifying, text, condition, actor);

  @override
  String toString() => 'BroadcastToQualifying("$text", $condition)';
}
