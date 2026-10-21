import 'package:engine/engine.dart';

import 'identity.dart';

/// Rejection codes the session itself produces (Proposed names), beside the engine's
/// `RejectionCode` names (carried in the `rejected` message's `code`).
abstract final class SessionRejection {
  /// The sender may not issue this command.
  static const unauthorized = 'unauthorized';

  /// The request body could not be decoded.
  static const malformed = 'malformed';

  /// The sender has not completed a `hello`.
  static const notAdmitted = 'notAdmitted';
}

/// Decides who may send what (04 §Authorization). Session rules, not engine
/// rules: the engine records the actor but never checks it.
abstract interface class Authorizer {
  /// Null to allow, or why [who] may not issue [command].
  String? deny(Principal who, Command command, OperationState state);
}

/// The default rules: the GM may issue any command; a player may issue only
/// commands that name their own alias as actor and that [playerMay] allows.
final class DefaultAuthorizer implements Authorizer {
  /// Creates the rules. [playerMay] lists the commands players can send;
  /// with none given, players can send nothing (the engine has no player
  /// commands yet: they arrive with the checks system).
  const DefaultAuthorizer({this.playerMay = _none});

  /// Whether players may send [command] at all.
  final bool Function(Command command) playerMay;

  static bool _none(Command _) => false;

  @override
  String? deny(Principal who, Command command, OperationState state) {
    if (who.isGm) return null;
    final alias = who.aliasId;
    final actor = command.actor;
    if (alias == null || actor is! AliasActor || actor.alias.value != alias) {
      return 'Commands must name your own alias as actor.';
    }
    if (!playerMay(command)) return 'Players cannot send this command.';
    return null;
  }
}
