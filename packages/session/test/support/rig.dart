import 'dart:async';

import 'package:engine/engine.dart';
import 'package:protocol/protocol.dart' hide PackPin, Rejected;
import 'package:session/session.dart';
import 'package:test/test.dart';

import 'test_codec.dart';
import 'test_pack.dart';

const gmIdentity = Principal(agentId: 'gm-agent', isGm: true);
const hostAddress = Address('host');

/// Verifies a hello by looking its `authProof` up in a table.
final class TableVerifier implements IdentityVerifier {
  TableVerifier(this.known);

  final Map<String, Principal> known;

  @override
  Future<Principal?> verify(Hello hello) async => known[hello.authProof];
}

/// An [Rng] that counts draws and lets a test waste some.
final class CountingRng implements Rng {
  CountingRng(this.drawCount);

  @override
  int drawCount;

  @override
  int rollDie(int sides) {
    drawCount++;
    return 1;
  }
}

/// A host, its store and network, and the players around it.
final class Rig {
  Rig._(this.network, this.store, this.verifier, this.admission);

  InMemoryNetwork network;
  final InMemoryEventStore store;
  final TableVerifier verifier;
  final RosterAdmission admission;
  late OperationHost host;
  late CountingRng rng;
  final List<OperationParticipant> participants = [];
  final List<Object> protocolErrors = [];

  static const codec = TestCodec();

  static Future<Rig> create({
    bool Function(Command)? playerMay,
    Map<String, Principal> identities = const {},
  }) async {
    final rig = Rig._(
      InMemoryNetwork(),
      InMemoryEventStore(),
      TableVerifier({
        'gm-agent': gmIdentity,
        'ann': const Principal(agentId: 'ann', aliasId: 'hall'),
        'bob': const Principal(agentId: 'bob', aliasId: 'vale'),
        ...identities,
      }),
      RosterAdmission()
        ..invite('ann', 'hall')
        ..invite('bob', 'vale'),
    );
    await rig.openHost(playerMay: playerMay);
    return rig;
  }

  Future<void> openHost({bool Function(Command)? playerMay}) async {
    host = await OperationHost.open(
      operationId: 'op1',
      gm: gmIdentity,
      engine: Engine(testPack()),
      codec: codec,
      store: store,
      verifier: verifier,
      admission: admission,
      authorizer: DefaultAuthorizer(
        playerMay: playerMay ?? (c) => c is CreateAgent,
      ),
      rngFactory: (draws) => rng = CountingRng(draws),
      onProtocolError: protocolErrors.add,
    );
    host.listen(network.host(hostAddress));
  }

  Future<OperationParticipant> join(
    String agentId,
    String aliasId, {
    String? proof,
  }) async {
    final player = OperationParticipant(
      operationId: 'op1',
      agentId: agentId,
      aliasId: aliasId,
      engine: Engine(testPack()),
      codec: codec,
      authProof: proof ?? agentId,
    );
    participants.add(player);
    await player.connect(await network.client().connect(hostAddress));
    await pumpEventQueue();
    return player;
  }

  Future<SubmitResult> start({OperationSettings? settings}) => host.submit(
    StartOperation(
      operationId: 'op1',
      settings: settings ?? const OperationSettings(),
    ),
  );

  CreateAgent agent(String name, {String? owner}) => CreateAgent(
    name: name,
    attributes: validScores(),
    ownerAlias: owner == null ? null : AliasId(owner),
    actor: owner == null ? const GmActor() : AliasActor(AliasId(owner)),
  );

  Future<void> close() async {
    for (final p in participants) {
      await p.close();
    }
    await host.close();
  }
}
