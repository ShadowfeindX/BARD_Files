import 'package:engine/engine.dart';
import 'package:protocol/protocol.dart' show Hello, RefusalReason;
import 'package:session/session.dart';

/// The Handler's agent id when this machine hosts.
const String hostGmAgentId = 'gm';

/// Who joins a LAN host (04 §Authorization, LAN): the join code is checked
/// by the transport before a link opens, so a `hello` that arrives has
/// already shown it. The agent and alias it names are taken as given; the
/// GM's id is never accepted from a link.
class LanVerifier implements IdentityVerifier {
  /// Creates the verifier.
  const LanVerifier();

  @override
  Future<Principal?> verify(Hello hello) async {
    final alias = hello.aliasId;
    if (hello.agentId.isEmpty || hello.agentId == hostGmAgentId) return null;
    if (alias == null || alias.isEmpty) return null;
    return Principal(agentId: hello.agentId, aliasId: alias);
  }
}

/// Who may play which alias on a LAN host.
///
/// A player joins with an agent code: the alias of an agent the Handler
/// added. An unknown code is refused as not invited. The first machine to
/// join with a code keeps it for as long as the host runs; another machine
/// with the same code is refused as locked.
class LanAdmission implements Admission {
  /// Creates the admission over [knownAliases], read at each join.
  LanAdmission(this.knownAliases);

  /// The aliases that own an agent right now.
  final Set<String> Function() knownAliases;

  final Map<String, String> _claimedBy = {};

  @override
  RefusalReason? check(Principal who) {
    if (who.isGm) return null;
    final alias = who.aliasId;
    if (alias == null || !knownAliases().contains(alias)) {
      return RefusalReason.notInvited;
    }
    final holder = _claimedBy.putIfAbsent(alias, () => who.agentId);
    return holder == who.agentId ? null : RefusalReason.aliasLocked;
  }
}

/// What a player may send over a link: action requests and phone messages,
/// always as their own alias (checked by [DefaultAuthorizer]), and an action
/// request only for the agent that alias owns.
const Authorizer lanAuthorizer = LanAuthorizer();

/// The rules behind [lanAuthorizer].
class LanAuthorizer implements Authorizer {
  /// Creates the rules.
  const LanAuthorizer();

  static const _base = DefaultAuthorizer(playerMay: _playerMay);

  static bool _playerMay(Command command) =>
      command is RequestAction || command is SendPhoneMessage;

  @override
  String? deny(Principal who, Command command, EpisodeState state) {
    final denied = _base.deny(who, command, state);
    if (denied != null || who.isGm) return denied;
    // The engine checks only that the entity exists, so without this a
    // player could file requests for another player's agent, or probe the
    // ids of GM-only entities.
    if (command is RequestAction) {
      final owner = state.stores
          .get(Identity.componentType, command.entity)
          ?.ownerAlias;
      if (owner?.value != who.aliasId) {
        return 'You can only make requests for your own agent.';
      }
    }
    return null;
  }
}
