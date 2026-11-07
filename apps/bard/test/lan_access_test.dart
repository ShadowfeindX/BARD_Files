import 'package:bard/data/lan_access.dart';
import 'package:engine/engine.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:protocol/protocol.dart' show RefusalReason;
import 'package:session/session.dart';

void main() {
  const vale = Principal(agentId: 'p-1', aliasId: 'vale');
  final state = EpisodeState.initial().copyWith(
    stores: const ComponentStores.empty()
        .put(
          const EntityId('e1'),
          const Identity(
            name: 'Agent Vale',
            kind: EntityKind.agent,
            ownerAlias: AliasId('vale'),
          ),
        )
        .put(
          const EntityId('e2'),
          const Identity(
            name: 'Agent Quill',
            kind: EntityKind.agent,
            ownerAlias: AliasId('quill'),
          ),
        )
        .put(
          const EntityId('e3'),
          const Identity(name: 'Mara', kind: EntityKind.npc),
        ),
  );

  RequestAction request(String entity) => RequestAction(
    entity: EntityId(entity),
    description: 'Look around.',
    actor: const AliasActor(AliasId('vale')),
  );

  group('lanAuthorizer', () {
    test('a player may request for their own agent', () {
      expect(lanAuthorizer.deny(vale, request('e1'), state), isNull);
    });

    test('a player may not request for another agent or an NPC', () {
      expect(lanAuthorizer.deny(vale, request('e2'), state), isNotNull);
      expect(lanAuthorizer.deny(vale, request('e3'), state), isNotNull);
      expect(lanAuthorizer.deny(vale, request('e9'), state), isNotNull);
    });

    test('a player may not act as another alias or send GM commands', () {
      final asQuill = RequestAction(
        entity: const EntityId('e2'),
        description: 'Look around.',
        actor: const AliasActor(AliasId('quill')),
      );
      expect(lanAuthorizer.deny(vale, asQuill, state), isNotNull);
      expect(
        lanAuthorizer.deny(
          vale,
          const DeclineRequest(request: RequestId('r1')),
          state,
        ),
        isNotNull,
      );
    });
  });

  group('LanAdmission', () {
    test('admits a known code once per machine', () {
      final admission = LanAdmission(() => {'vale'});
      expect(admission.check(vale), isNull);
      expect(admission.check(vale), isNull);
      expect(
        admission.check(const Principal(agentId: 'p-2', aliasId: 'vale')),
        RefusalReason.aliasLocked,
      );
      expect(
        admission.check(const Principal(agentId: 'p-1', aliasId: 'quill')),
        RefusalReason.notInvited,
      );
    });
  });
}
