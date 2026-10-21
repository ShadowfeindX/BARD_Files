part of 'events.dart';

/// Events applied by `OperationSystem`.
sealed class OperationEvent extends Event {
  const OperationEvent();
}

/// The operation started: the genesis event of every log.
final class OperationStarted extends OperationEvent {
  /// Creates the event.
  const OperationStarted({
    required this.operationId,
    required this.engineVersion,
    required this.packRef,
    required this.settings,
    required this.actor,
    this.visibility = const Public(),
  });

  /// The operation's id.
  final String operationId;

  /// Engine version that started the operation.
  final String engineVersion;

  /// The pinned pack.
  final PackRef packRef;

  /// Initial GM settings.
  final OperationSettings settings;

  @override
  final Actor actor;

  @override
  final Visibility visibility;

  @override
  bool operator ==(Object other) =>
      other is OperationStarted &&
      other.operationId == operationId &&
      other.engineVersion == engineVersion &&
      other.packRef == packRef &&
      other.settings == settings &&
      other.actor == actor &&
      other.visibility == visibility;

  @override
  int get hashCode => Object.hash(
    OperationStarted,
    operationId,
    engineVersion,
    packRef,
    settings,
    actor,
    visibility,
  );

  @override
  String toString() =>
      'OperationStarted($operationId, engine $engineVersion, $packRef)';
}
