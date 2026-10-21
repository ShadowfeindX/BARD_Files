/// The event narrator (01 §Responsibilities, P12): plain-text log lines per
/// perspective.
///
/// Wording is English and built in for now. The pack's `strings/` has no
/// narration templates yet ("future work" in the provisional pack), so
/// moving the wording there is a later change. Names come from the pack and
/// the state. Line shapes are Proposed.
library;

import '../checks/check_types.dart';
import '../components/components.dart';
import '../events/events.dart';
import '../expr/evaluate.dart';
import '../ids.dart';
import '../pack/rules_pack.dart';
import '../state/operation_state.dart';
import '../visibility.dart';

/// The log lines for one event.
///
/// The session turns these into its per-audience variants using the event's
/// visibility: the GM always reads [gm]; players the event is visible to read
/// [player]; for a [Redacted] event every player reads [redacted].
final class Narration {
  /// Creates a narration.
  const Narration({required this.gm, this.player, this.redacted});

  /// The GM's line.
  final String gm;

  /// The line for players who may see the event, or `null` when none may.
  final String? player;

  /// The line players read for a [Redacted] event, else `null`.
  final String? redacted;

  @override
  bool operator ==(Object other) =>
      other is Narration &&
      other.gm == gm &&
      other.player == player &&
      other.redacted == redacted;

  @override
  int get hashCode => Object.hash(gm, player, redacted);

  @override
  String toString() =>
      'Narration(gm: $gm, player: $player, '
      'redacted: $redacted)';
}

/// Turns events into [Narration]s for one pack.
///
/// Pure. Every event kind has a case (an exhaustive switch, 04 §Every event
/// kind has a narrator), so adding an event without a narrator does not
/// compile.
final class Narrator {
  /// Creates a narrator for [pack].
  const Narrator(this.pack);

  /// The pack whose names are used.
  final RulesPack pack;

  /// Narrates [event]. [state] is the state the event applies to (before or
  /// after it; only names are read from it).
  ///
  /// A GM edit made in review (`overriddenFrom`) is in the GM's line only;
  /// players read the final value (Proposed: F2 does not say players see
  /// edits).
  Narration narrate(OperationState state, Event event) {
    final gm = _text(state, event, forGm: true);
    final player = _text(state, event, forGm: false);
    return switch (event.visibility) {
      Public() || AliasesOnly() => Narration(gm: gm, player: player),
      GmOnly() => Narration(gm: gm),
      Redacted() => Narration(gm: gm, redacted: _redacted(event)),
    };
  }

  String _text(OperationState state, Event event, {required bool forGm}) {
    String was(Object? original) => forGm && original != null
        ? ' (changed by the Handler from $original)'
        : '';
    return switch (event) {
      OperationStarted() =>
        'The operation began (pack ${event.packRef.id} '
            '${event.packRef.version}).',
      AgentCreated() => 'Agent ${event.name} joined the operation.',
      ActionRequested() =>
        '${_name(state, event.entity)} asks to act: "${event.description}"'
            '${event.suggestedSkill == null ? '' : ' (suggests ${_skill(event.suggestedSkill!)})'}.',
      RequestDeclined() =>
        'The Handler declined the request'
            '${event.reason == null ? '' : ': ${event.reason}'}.',
      CheckRequired() =>
        '${_name(state, event.spec.entity)} must make a '
            '${_checkName(event.spec)} check against ${_dc(event.spec)}.',
      CheckResolved() => _resolved(state, event),
      DamageApplied() =>
        '${_name(state, event.entity)} takes ${event.amount} damage'
            '${was(event.overriddenFrom)}.',
      SanityLost() =>
        '${_name(state, event.entity)} loses ${event.amount} Sanity'
            '${was(event.overriddenFrom)}.',
      ConditionApplied() =>
        '${_name(state, event.entity)} is now ${_condition(event.condition)}'
            '${was(event.overriddenFrom == null ? null : _condition(event.overriddenFrom!))}.',
      ConditionCleared() =>
        '${_name(state, event.entity)} is no longer '
            '${_condition(event.condition)}.',
    };
  }

  String _resolved(OperationState state, CheckResolved event) {
    final b = event.breakdown;
    final parts = [
      'die ${_faces(b.primary)}',
      '${_attribute(b.attribute)} ${b.attributeScore}',
      if (b.proficiency case final bonus?) '${_tier(b.tier)} ${_faces(bonus)}',
      for (final m in b.modifiers)
        '${m.label} ${m.value < 0 ? m.value : '+${m.value}'}',
    ];
    return '${_name(state, event.spec.entity)} rolled '
        '${_checkName(event.spec)}: ${parts.join(', ')} = ${b.total} '
        'against ${_dc(event.spec)}, ${_outcome(event.outcome)}.';
  }

  /// The line players read when the GM rolls or acts in secret.
  String _redacted(Event event) => switch (event) {
    CheckRequired() || CheckResolved() => 'The Handler rolled something.',
    _ => 'Something happened out of sight.',
  };

  String _name(OperationState state, EntityId entity) =>
      state.stores.get(Identity.componentType, entity)?.name ?? entity.value;

  String _checkName(CheckSpec spec) => switch (spec.skill) {
    null => _attribute(spec.attribute),
    final skill => '${_skill(skill)} (${_attribute(spec.attribute)})',
  };

  String _dc(CheckSpec spec) => switch (spec.category) {
    null => 'DC ${spec.dc}',
    final category =>
      'DC ${spec.dc} (${pack.difficultyCategory(category)?.name ?? category})',
  };

  String _attribute(String key) => pack.attribute(key)?.name ?? key;

  String _skill(String id) => pack.skill(id)?.name ?? id;

  String _tier(String? key) =>
      key == null ? 'bonus' : pack.proficiencyTier(key)?.name ?? key;

  String _condition(String id) => pack.condition(id)?.name ?? id;

  /// Every face of a term's dice, explosions joined with `+`, for example
  /// `6+2` for an exploding die. Terms without dice show their value.
  String _faces(Term term) => switch (term) {
    DiceTerm(:final rolls) => rolls.map((r) => r.faces.join('+')).join(' '),
    _ => '${term.value}',
  };

  String _outcome(CheckOutcome outcome) => switch (outcome) {
    CheckOutcome.success => 'success',
    CheckOutcome.partialSuccess => 'partial success',
    CheckOutcome.failure => 'failure',
  };
}
