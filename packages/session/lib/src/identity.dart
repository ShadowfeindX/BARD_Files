import 'package:protocol/protocol.dart';

/// Who is on the other end of a link, as verified by the host (never as
/// claimed by the sender: 04 §Authorization).
final class Principal {
  /// Creates a verified identity.
  const Principal({
    required this.agentId,
    this.aliasId,
    this.isGm = false,
    this.isAnonymous = false,
  });

  /// The account profile.
  final String agentId;

  /// The alias this agent plays in the operation; null for the GM.
  final String? aliasId;

  /// Whether this is the operation's GM.
  final bool isGm;

  /// Whether the agent is an anonymous guest (clearance 0).
  final bool isAnonymous;
}

/// Verifies what a `hello` claims. Backed by Firebase Auth in network play
/// (the `authProof`), by the join code on a LAN, and by a table in tests.
abstract interface class IdentityVerifier {
  /// The verified identity, or null when the proof does not hold.
  ///
  /// The `kind` in the hello is advisory: anonymous status comes from the
  /// verified identity, never from the sender's word.
  Future<Principal?> verify(Hello hello);
}

/// Decides who may join (the `notInvited`, `aliasLocked`, `banned` and
/// `anonymousAliasLimit` refusals).
abstract interface class Admission {
  /// The refusal reason, or null to admit [who].
  RefusalReason? check(Principal who);
}

/// [Admission] from lists the GM maintains, held in memory.
final class RosterAdmission implements Admission {
  final Map<String, Set<String>> _invited = {};
  final Set<String> _banned = {};
  final Set<String> _lockedAliases = {};
  final Map<String, String> _anonymousAlias = {};

  /// Invites [agentId] to play as [aliasId].
  void invite(String agentId, String aliasId) =>
      _invited.putIfAbsent(agentId, () => {}).add(aliasId);

  /// Bans [agentId].
  void ban(String agentId) => _banned.add(agentId);

  /// Marks [aliasId] as locked to another campaign or operation.
  void lockAlias(String aliasId) => _lockedAliases.add(aliasId);

  @override
  RefusalReason? check(Principal who) {
    if (_banned.contains(who.agentId)) return RefusalReason.banned;
    if (who.isGm) return null;
    final alias = who.aliasId;
    if (alias == null || !(_invited[who.agentId]?.contains(alias) ?? false)) {
      return RefusalReason.notInvited;
    }
    if (_lockedAliases.contains(alias)) return RefusalReason.aliasLocked;
    if (who.isAnonymous) {
      // Anonymous accounts have exactly one alias (06 §Account model).
      final first = _anonymousAlias.putIfAbsent(who.agentId, () => alias);
      if (first != alias) return RefusalReason.anonymousAliasLimit;
    }
    return null;
  }
}
