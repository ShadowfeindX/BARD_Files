/// Derived-stat read models (01 §Components: derived values are read
/// models, not stored fields).
library;

import '../components/components.dart';
import '../expr/evaluate.dart';
import '../ids.dart';
import '../pack/rules_pack.dart';
import '../state/operation_state.dart';

/// Derived-stat keys the engine itself reads. Proposed engine vocabulary:
/// a pack that names its Health and Sanity formulas differently gets no
/// [VitalsView].
abstract final class DerivedKeys {
  /// Maximum Health (rulebook: END × LCK).
  static const health = 'health';

  /// Maximum Sanity (rulebook: WIS × LCK).
  static const sanity = 'sanity';
}

/// An entity's Health and Sanity now: derived maximum minus what was lost.
final class VitalsView {
  /// Creates a view.
  const VitalsView({
    required this.maxHealth,
    required this.health,
    required this.maxSanity,
    required this.sanity,
  });

  /// Maximum Health.
  final num maxHealth;

  /// Current Health. Not clamped: it may go below 0.
  final num health;

  /// Maximum Sanity.
  final num maxSanity;

  /// Current Sanity. Not clamped: it may go below 0.
  final num sanity;

  @override
  bool operator ==(Object other) =>
      other is VitalsView &&
      other.maxHealth == maxHealth &&
      other.health == health &&
      other.maxSanity == maxSanity &&
      other.sanity == sanity;

  @override
  int get hashCode => Object.hash(maxHealth, health, maxSanity, sanity);

  @override
  String toString() =>
      'VitalsView(health $health/$maxHealth, sanity $sanity/$maxSanity)';
}

/// Computes derived stats from an entity's attributes with [pack]'s
/// formulas. Pure and cheap; nothing is cached or stored.
final class DerivedStats {
  /// Creates the read model for [pack].
  const DerivedStats(this.pack);

  /// The pack whose formulas are used.
  final RulesPack pack;

  /// Every derived stat of [entity] by key, in pack order.
  ///
  /// A stat whose formula cannot be evaluated for the entity (a missing
  /// score, a division by zero) is left out. Empty when the entity has no
  /// attributes.
  Map<String, num> of(OperationState state, EntityId entity) {
    final scores = state.stores.get(Attributes.componentType, entity)?.scores;
    if (scores == null) return const {};
    final attributes = scores.asMap();
    final result = <String, num>{};
    for (final stat in pack.derived) {
      try {
        result[stat.key] = evaluateFormula(
          stat.formula,
          attributes: attributes,
        );
      } on EvaluationException {
        continue;
      }
    }
    return result;
  }

  /// One derived stat of [entity], or `null` when it cannot be computed.
  num? value(OperationState state, EntityId entity, String key) =>
      of(state, entity)[key];

  /// [entity]'s Health and Sanity, or `null` when the pack has no
  /// [DerivedKeys.health] or [DerivedKeys.sanity] stat or the entity cannot
  /// compute them.
  VitalsView? vitals(OperationState state, EntityId entity) {
    final stats = of(state, entity);
    final maxHealth = stats[DerivedKeys.health];
    final maxSanity = stats[DerivedKeys.sanity];
    if (maxHealth == null || maxSanity == null) return null;
    final lost =
        state.stores.get(Vitals.componentType, entity) ?? const Vitals();
    return VitalsView(
      maxHealth: maxHealth,
      health: normalizeNumber(maxHealth - lost.damageTaken),
      maxSanity: maxSanity,
      sanity: normalizeNumber(maxSanity - lost.sanityLost),
    );
  }
}
