import 'package:engine/engine.dart' hide Visibility;
import 'package:ui_kit/ui_kit.dart';

import '../models.dart';

/// Turns engine state and events into the panels' display data. Shared by
/// the host's service and a joined player's service, so both show an agent,
/// a roll and a phone thread the same way.
class EpisodeProjection {
  /// Creates a projection over [pack].
  const EpisodeProjection(this.pack);

  /// The rules pack whose names are shown.
  final RulesPack pack;

  /// The text a player reads for a redacted entry when no narrated line is
  /// at hand.
  static const String redactedLine = 'The Handler did something.';

  /// Every agent in [state] that an alias owns.
  List<AgentSheet> agents(EpisodeState state) {
    final stats = DerivedStats(pack);
    return [
      for (final e in state.stores.all(Identity.componentType).entries)
        if (e.value.ownerAlias != null) sheet(state, stats, e.key, e.value),
    ];
  }

  /// The sheet of agent [id], whose identity is [who].
  AgentSheet sheet(
    EpisodeState state,
    DerivedStats stats,
    EntityId id,
    Identity who,
  ) {
    final vitals = stats.vitals(state, id);
    final scores = state.stores.get(Attributes.componentType, id)?.scores;
    final active = state.stores.get(Conditions.componentType, id)?.ids;
    return AgentSheet(
      id: who.ownerAlias!.value,
      name: who.name,
      attributes: scores?.asMap() ?? const {},
      health: vitals?.health.toInt() ?? 0,
      sanity: vitals?.sanity.toInt() ?? 0,
      conditions: [
        for (final c in active ?? const <String>{})
          ConditionOption(id: c, name: pack.condition(c)?.name ?? c),
      ],
    );
  }

  /// The entity whose identity [alias] owns in [state].
  EntityId? entityOf(EpisodeState state, String alias) => state.stores
      .all(Identity.componentType)
      .entries
      .where((e) => e.value.ownerAlias == AliasId(alias))
      .firstOrNull
      ?.key;

  /// The log entry for a readable [event]: a roll breakdown for a resolved
  /// check, otherwise [text] (null shows nothing). A delivered whisper is
  /// marked for a player.
  LogEntry? entry(
    Event event,
    String? text,
    EpisodeState state, {
    required bool forPlayer,
  }) {
    if (event is CheckResolved) return RollEntry(breakdown(event, state));
    if (text == null) return null;
    return TextEntry(text, whisper: event is BroadcastDelivered && forPlayer);
  }

  /// The dice breakdown of a resolved check.
  DiceBreakdownData breakdown(CheckResolved event, EpisodeState state) {
    final b = event.breakdown;
    final spec = event.spec;
    final name = state.stores.get(Identity.componentType, spec.entity)?.name;
    final skillName = spec.skill == null
        ? null
        : pack.skills.where((s) => s.id == spec.skill).firstOrNull?.name;
    DiceGroup group(String label, Term term) => DiceGroup(
      label: label,
      dice: [
        if (term is DiceTerm)
          for (final roll in term.rolls)
            for (var i = 0; i < roll.faces.length; i++)
              DieResult(roll.faces[i], exploded: i < roll.faces.length - 1),
      ],
      subtotal: term.value.toInt(),
    );
    final proficiency = b.proficiency;
    return DiceBreakdownData(
      title: '${name ?? '?'}: ${skillName ?? b.attribute}',
      groups: [
        group('Primary d6', b.primary),
        if (proficiency != null) group('Proficiency', proficiency),
      ],
      modifiers: [
        ModifierLine(b.attribute, b.attributeScore),
        for (final m in b.modifiers) ModifierLine(m.label, m.value),
      ],
      total: b.total.toInt(),
      dc: spec.dc,
      dcLabel: pack.difficultyCategories
          .where((d) => d.key == spec.category)
          .firstOrNull
          ?.name,
      outcome: switch (event.outcome) {
        CheckOutcome.success => CheckOutcomeKind.success,
        CheckOutcome.partialSuccess => CheckOutcomeKind.partial,
        CheckOutcome.failure => CheckOutcomeKind.failure,
      },
    );
  }

  // --- phone -------------------------------------------------------------

  /// Thread ids name the counterpart: `gm` for the Handler, `alias:<id>` for
  /// an agent's alias, `npc:<entity>` for an NPC.
  PhoneParty partyOf(String threadId) => switch (threadId) {
    'gm' => const PhoneGm(),
    _ when threadId.startsWith('npc:') => PhoneNpc(
      EntityId(threadId.substring('npc:'.length)),
    ),
    _ => PhoneAlias(AliasId(threadId.substring('alias:'.length))),
  };

  /// The thread id of [party].
  String threadOf(PhoneParty party) => switch (party) {
    PhoneGm() => 'gm',
    PhoneAlias(:final alias) => 'alias:${alias.value}',
    PhoneNpc(:final entity) => 'npc:${entity.value}',
  };

  /// The Handler's threads: one per agent, holding the messages between the
  /// Handler and that alias. Messages between agents show in the GM log.
  List<PhoneThreadData> gmThreads(List<Event> log, Map<String, String> names) {
    final byAlias = <String, List<PhoneMessageData>>{};
    for (final c in phoneConversations(log)) {
      final alias = switch ((c.a, c.b)) {
        (PhoneAlias(:final alias), PhoneGm()) ||
        (PhoneGm(), PhoneAlias(:final alias)) => alias.value,
        _ => null,
      };
      if (alias == null) continue;
      byAlias[alias] = [
        for (final m in c.messages)
          PhoneMessageData(text: m.text, fromMe: m.from is PhoneGm),
      ];
    }
    return [
      for (final MapEntry(key: alias, value: name) in names.entries)
        PhoneThreadData(
          id: 'alias:$alias',
          title: name,
          messages: byAlias[alias] ?? const [],
        ),
    ];
  }

  /// The title of a thread with an NPC whose name the player cannot see.
  static const String unknownNumber = 'Unknown number';

  /// A player's threads: the Handler, then every other agent, then every
  /// NPC that has messaged this player, from the events this player may
  /// see.
  ///
  /// An NPC's thread is titled with its name only when [state] (the
  /// player's own view) holds the NPC's identity; NPCs the Handler adds are
  /// GM-only, so today a player sees [unknownNumber].
  List<PhoneThreadData> playerThreads(
    List<Event> visible,
    String alias,
    Map<String, String> names, {
    EpisodeState? state,
  }) {
    final me = PhoneAlias(AliasId(alias));
    final byThread = {
      for (final c in phoneConversations(visible, viewer: AliasId(alias)))
        threadOf(c.b): [
          for (final m in c.messages)
            PhoneMessageData(text: m.text, fromMe: m.from == me),
        ],
    };
    return [
      PhoneThreadData(
        id: 'gm',
        title: 'The Handler',
        messages: byThread['gm'] ?? const [],
      ),
      for (final MapEntry(key: other, value: name) in names.entries)
        if (other != alias)
          PhoneThreadData(
            id: 'alias:$other',
            title: name,
            messages: byThread['alias:$other'] ?? const [],
          ),
      for (final MapEntry(key: id, value: messages) in byThread.entries)
        if (id.startsWith('npc:'))
          PhoneThreadData(
            id: id,
            title:
                state?.stores
                    .get(
                      Identity.componentType,
                      EntityId(id.substring('npc:'.length)),
                    )
                    ?.name ??
                unknownNumber,
            messages: messages,
          ),
    ];
  }
}
