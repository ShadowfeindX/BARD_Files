part of 'commands.dart';

/// Commands handled by `OperationSystem`: the operation's lifecycle.
sealed class OperationCommand extends Command {
  const OperationCommand();
}

/// Starts an operation on the engine's pack. Must be the first command.
final class StartOperation extends OperationCommand {
  /// Creates a start command.
  const StartOperation({
    required this.operationId,
    this.settings = const OperationSettings(),
    this.actor = const GmActor(),
  });

  /// The operation's id, chosen outside the engine.
  final String operationId;

  /// Initial GM settings.
  final OperationSettings settings;

  @override
  final Actor actor;

  @override
  bool operator ==(Object other) =>
      other is StartOperation &&
      other.operationId == operationId &&
      other.settings == settings &&
      other.actor == actor;

  @override
  int get hashCode => Object.hash(StartOperation, operationId, settings, actor);

  @override
  String toString() => 'StartOperation($operationId, $settings, by $actor)';
}
