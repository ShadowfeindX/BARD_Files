import 'package:engine/engine.dart';
import 'package:test/test.dart';

import 'support/decisions.dart';
import 'support/table.dart';
import 'support/test_pack.dart';

void main() {
  const hallAlias = AliasId('alias-hall');
  const hall = EntityId('e2');
  final wilBelow3 = Compare(CompareOp.lt, Attr('WIL'), Const(3));

  /// Vale (WIL 2) and Hall (WIL 3), each played by an alias, and a
  /// GM-controlled NPC (WIL 1).
  Table table() {
    final t = Table();
    t.run(
      CreateAgent(
        name: 'Hall',
        attributes: {...validScores(), 'WIL': 3},
        ownerAlias: hallAlias,
      ),
    );
    t.run(
      CreateAgent(name: 'Watcher', attributes: {...validScores(), 'WIL': 1}),
    );
    return t;
  }

  test('only qualifying aliases receive the text', () {
    final t = table();
    final events = t.run(
      BroadcastToQualifying(
        text: 'A low groaning voice is heard nearby.',
        condition: wilBelow3,
      ),
    );
    final evaluated = events[0] as BroadcastEvaluated;
    final delivered = events[1] as BroadcastDelivered;
    expect(evaluated.visibility, const GmOnly());
    expect(evaluated.candidates, [
      const BroadcastCandidate(
        alias: Table.valeAlias,
        entity: Table.vale,
        result: ConditionResult(passed: true, left: 2, right: 3),
      ),
      const BroadcastCandidate(
        alias: hallAlias,
        entity: hall,
        result: ConditionResult(passed: false, left: 3, right: 3),
      ),
    ]);
    expect(delivered.visibility, AliasesOnly({Table.valeAlias}));
    expect(delivered.text, 'A low groaning voice is heard nearby.');
  });

  test('the condition never reaches players', () {
    final t = table();
    final narrator = Narrator(t.engine.pack);
    final events = t.run(
      BroadcastToQualifying(text: 'Whispers.', condition: wilBelow3),
    );
    for (final event in events) {
      final player = narrator.narrate(t.state, event).player;
      if (event.visibility is GmOnly) {
        expect(player, isNull);
      } else {
        expect(event, isA<BroadcastDelivered>());
        expect(player, isNot(contains('WIL')));
      }
    }
    // The delivered event carries only the text and its recipients.
    expect(
      events.last,
      BroadcastDelivered(
        text: 'Whispers.',
        actor: const GmActor(),
        visibility: AliasesOnly({Table.valeAlias}),
      ),
    );
  });

  test('an alias with several agents qualifies if any of them passes', () {
    final t = table();
    t.run(
      CreateAgent(
        name: 'Hall (second)',
        attributes: {...validScores(), 'WIL': 1},
        ownerAlias: hallAlias,
      ),
    );
    final evaluated =
        t.run(BroadcastToQualifying(text: 'x', condition: wilBelow3)).first
            as BroadcastEvaluated;
    expect(evaluated.candidates.where((c) => c.alias == hallAlias).length, 2);
    expect(evaluated.recipients, {Table.valeAlias, hallAlias});
  });

  test('when nobody qualifies only the GM record is written', () {
    final t = table();
    final events = t.run(
      BroadcastToQualifying(
        text: 'Silence.',
        condition: Compare(CompareOp.gt, Attr('WIL'), Const(5)),
      ),
    );
    expect(events.single, isA<BroadcastEvaluated>());
    expect((events.single as BroadcastEvaluated).recipients, isEmpty);
  });

  test('an agent without the score does not qualify', () {
    final t = table();
    final scores = Map.of(validScores())..remove('WIL');
    t.state = t.state.copyWith(
      stores: t.state.stores.put(Table.vale, Attributes(scores)),
    );
    final candidates = t.engine.broadcastPreview(t.state, wilBelow3);
    expect(candidates.first.result, isNull);
    expect(candidates.first.qualifies, isFalse);
  });

  test('the GM preview matches what the broadcast records', () {
    final t = table();
    final preview = t.engine.broadcastPreview(t.state, wilBelow3);
    final evaluated =
        t.run(BroadcastToQualifying(text: 'x', condition: wilBelow3)).first
            as BroadcastEvaluated;
    expect(evaluated.candidates, preview);
  });

  test('a broadcast does not change state', () {
    final t = table();
    final before = t.state;
    t.run(BroadcastToQualifying(text: 'x', condition: wilBelow3));
    expect(t.state, before);
  });

  test('rejections', () {
    final t = table();
    expect(
      rejection(
        t.decide(BroadcastToQualifying(text: ' ', condition: wilBelow3)),
      ),
      RejectionCode.invalidValue,
    );
    expect(
      rejection(
        t.decide(
          BroadcastToQualifying(
            text: 'x',
            condition: Compare(CompareOp.lt, Attr('OCC'), Const(3)),
          ),
        ),
      ),
      RejectionCode.unknownPackKey,
    );
  });

  test('narration', () {
    final t = table();
    final narrator = Narrator(t.engine.pack);
    final events = t.run(
      BroadcastToQualifying(text: 'Whispers.', condition: wilBelow3),
    );
    final evaluated = narrator.narrate(t.state, events[0]);
    expect(
      evaluated.gm,
      'Broadcast "Whispers." where WIL < 3: to Vale (1 of 2).',
    );
    expect(evaluated.player, isNull);
    final delivered = narrator.narrate(t.state, events[1]);
    expect(delivered.gm, 'Message to Vale: "Whispers."');
    expect(delivered.player, '"Whispers."');
  });
}
