import 'package:engine/engine.dart';
import 'package:test/test.dart';

import 'support/decisions.dart';
import 'support/table.dart';
import 'support/test_pack.dart';

void main() {
  const hallAlias = AliasId('alias-hall');
  const watcher = EntityId('e3');
  const valeParty = PhoneAlias(Table.valeAlias);
  const hallParty = PhoneAlias(hallAlias);
  const gm = PhoneGm();
  const watcherParty = PhoneNpc(watcher);

  /// Vale (e1) and Hall (e2), each played by an alias, and the Watcher (e3),
  /// a GM-run entity with no owner.
  Table table() {
    final t = Table();
    t.run(
      CreateAgent(
        name: 'Hall',
        attributes: validScores(),
        ownerAlias: hallAlias,
      ),
    );
    t.run(CreateAgent(name: 'Watcher', attributes: validScores()));
    return t;
  }

  SendPhoneMessage send(
    PhoneParty from,
    PhoneParty to,
    String text, {
    Actor? actor,
  }) => SendPhoneMessage(
    from: from,
    to: to,
    text: text,
    actor:
        actor ??
        switch (from) {
          PhoneAlias(:final alias) => AliasActor(alias),
          _ => const GmActor(),
        },
  );

  group('who sees a message', () {
    test('a player to the Handler is seen by that player and the Handler', () {
      final event =
          table().run(send(valeParty, gm, 'Need backup')).single
              as PhoneMessageSent;
      expect(event.visibility, AliasesOnly({Table.valeAlias}));
      expect(event.text, 'Need backup');
    });

    test('a player to another player is seen by both', () {
      final event = table().run(send(valeParty, hallParty, 'Meet at 9')).single;
      expect(event.visibility, AliasesOnly({Table.valeAlias, hallAlias}));
    });

    test('a player to a GM-run entity reaches only the Handler', () {
      final event = table()
          .run(send(valeParty, watcherParty, 'Who goes there?'))
          .single;
      expect(event.visibility, AliasesOnly({Table.valeAlias}));
    });

    test('the Handler to a player, and as a GM-run entity', () {
      final t = table();
      final direct = t.run(send(gm, valeParty, 'Be careful')).single;
      final asNpc = t.run(send(watcherParty, valeParty, 'Go away')).single;
      expect(direct.visibility, AliasesOnly({Table.valeAlias}));
      expect(asNpc.visibility, AliasesOnly({Table.valeAlias}));
      expect((asNpc as PhoneMessageSent).from, watcherParty);
    });

    test('a message does not change state', () {
      final t = table();
      final before = t.state;
      t.run(send(valeParty, gm, 'hi'));
      expect(t.state, before);
    });
  });

  group('rejections', () {
    RejectionCode reject(Table t, SendPhoneMessage command) =>
        rejection(t.decide(command));

    test('empty and over-long text', () {
      final t = table();
      expect(reject(t, send(valeParty, gm, '  ')), RejectionCode.invalidValue);
      expect(
        reject(t, send(valeParty, gm, 'x' * (maxPhoneTextUnits + 1))),
        RejectionCode.invalidValue,
      );
      t.run(send(valeParty, gm, 'x' * maxPhoneTextUnits));
    });

    test('the cap counts UTF-16 code units, as the relay rules do', () {
      final t = table();
      // 1,001 emoji is 2,002 code units.
      expect(
        reject(t, send(valeParty, gm, '😀' * 1001)),
        RejectionCode.invalidValue,
      );
      t.run(send(valeParty, gm, '😀' * 1000));
    });

    test('a player cannot send as someone else or as the Handler', () {
      final t = table();
      const asVale = AliasActor(Table.valeAlias);
      expect(
        reject(t, send(hallParty, gm, 'x', actor: asVale)),
        RejectionCode.unavailable,
      );
      expect(
        reject(t, send(gm, hallParty, 'x', actor: asVale)),
        RejectionCode.unavailable,
      );
      expect(
        reject(t, send(watcherParty, hallParty, 'x', actor: asVale)),
        RejectionCode.unavailable,
      );
    });

    test('the Handler cannot send as a player', () {
      expect(
        reject(table(), send(valeParty, gm, 'x', actor: const GmActor())),
        RejectionCode.unavailable,
      );
    });

    test(
      'nobody messages themselves; the Handler side only reaches aliases',
      () {
        final t = table();
        expect(
          reject(t, send(valeParty, valeParty, 'x')),
          RejectionCode.invalidValue,
        );
        expect(
          reject(t, send(gm, watcherParty, 'x')),
          RejectionCode.invalidValue,
        );
        expect(
          reject(t, send(watcherParty, gm, 'x')),
          RejectionCode.invalidValue,
        );
        expect(reject(t, send(gm, gm, 'x')), RejectionCode.invalidValue);
      },
    );

    test('unknown aliases and entities', () {
      final t = table();
      const ghost = PhoneAlias(AliasId('alias-ghost'));
      expect(
        reject(t, send(valeParty, ghost, 'x')),
        RejectionCode.unknownEntity,
      );
      expect(reject(t, send(gm, ghost, 'x')), RejectionCode.unknownEntity);
      expect(
        reject(t, send(valeParty, const PhoneNpc(EntityId('e99')), 'x')),
        RejectionCode.unknownEntity,
      );
    });

    test('a player character is not a GM-run entity', () {
      // e1 is Vale, owned by an alias.
      expect(
        reject(table(), send(valeParty, const PhoneNpc(Table.vale), 'x')),
        RejectionCode.unknownEntity,
      );
    });

    test('an operation that has not started refuses', () {
      final t = Table();
      final fresh = t.engine.decide(
        const OperationState.initial(),
        send(valeParty, gm, 'x'),
        t.rng,
        t.ids,
      );
      expect(rejection(fresh), RejectionCode.notStarted);
    });
  });

  group('conversations', () {
    test('a player sees only their threads, with themselves as side a', () {
      final t = table();
      final log = [
        ...t.run(send(valeParty, gm, 'Need backup')),
        ...t.run(send(hallParty, gm, 'Me too')),
        ...t.run(send(gm, valeParty, 'On it')),
        ...t.run(send(valeParty, hallParty, 'Meet at 9')),
        ...t.run(send(watcherParty, valeParty, 'Boo')),
      ];
      final threads = phoneConversations(log, viewer: Table.valeAlias);
      expect(threads.map((c) => c.b), [gm, hallParty, watcherParty]);
      expect(threads.every((c) => c.a == valeParty), isTrue);
      expect(threads.first.messages, const [
        PhoneEntry(from: valeParty, text: 'Need backup'),
        PhoneEntry(from: gm, text: 'On it'),
      ]);
    });

    test('the Handler sees every thread, one per pair', () {
      final t = table();
      final log = [
        ...t.run(send(valeParty, gm, 'Need backup')),
        ...t.run(send(hallParty, gm, 'Me too')),
        ...t.run(send(gm, valeParty, 'On it')),
      ];
      final threads = phoneConversations(log);
      expect(threads, hasLength(2));
      expect(threads.first.messages.map((m) => m.text), [
        'Need backup',
        'On it',
      ]);
    });

    test('other events are ignored', () {
      final t = table();
      final log = [
        ...t.run(
          BroadcastToQualifying(
            text: 'x',
            condition: Compare(CompareOp.lt, Attr('WIL'), Const(9)),
          ),
        ),
      ];
      expect(phoneConversations(log), isEmpty);
    });
  });

  test('narration names the parties; the Handler is "the Handler"', () {
    final t = table();
    final narrator = Narrator(t.engine.pack);
    final toGm = t.run(send(valeParty, gm, 'Need backup')).single;
    final fromNpc = t.run(send(watcherParty, hallParty, 'Boo')).single;
    expect(
      narrator.narrate(t.state, toGm).gm,
      'Vale texts the Handler: "Need backup"',
    );
    expect(narrator.narrate(t.state, fromNpc).gm, 'Watcher texts Hall: "Boo"');
    expect(narrator.narrate(t.state, toGm).player, isNotNull);
  });
}
