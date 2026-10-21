import '../actor.dart';
import '../checks/check_types.dart';
import '../commands/commands.dart';
import '../components/components.dart';
import '../decision.dart';
import '../events/events.dart';
import '../expr/evaluate.dart';
import '../expr/expr.dart';
import '../ids.dart';
import '../pack/rules_pack.dart';
import '../rng.dart';
import '../state/operation_state.dart';
import '../state/pending_state.dart';
import '../visibility.dart';

/// Action requests and skill checks (rulebook §2, §5).
///
/// The engine records who acts but does not check that an alias owns the
/// entity it acts for: authorization is the session's job (04 §The
/// operation loop).
///
/// A check totals `primary die + attribute + proficiency dice + modifiers`
/// and compares it with the DC: at or above is a success, short by no more
/// than the pack's margin is a partial success, otherwise a failure. Fumbles
/// (G1), Luck advantage (G2), assistance and opposed checks are not built.
///
/// Draw-count invariant (Opus gate): every command is fully validated before
/// the first die is rolled, so a rejection never consumes a draw. A resolved
/// check records the draw range it used.
final class CheckSystem {
  /// Creates the system for [pack].
  const CheckSystem(this.pack);

  /// The pack the engine is bound to.
  final RulesPack pack;

  /// Decides a [CheckCommand].
  Decision decide(
    OperationState state,
    CheckCommand command,
    Rng rng,
    IdSource ids,
  ) => switch (command) {
    RequestAction() => _request(state, command, ids),
    DeclineRequest() => _decline(state, command),
    RequireCheck() => _require(state, command, rng, ids),
    ResolveCheck() => _resolveCommand(state, command, rng),
  };

  /// Applies a [CheckEvent].
  OperationState evolve(OperationState state, CheckEvent event) {
    final pending = state.pending;
    return switch (event) {
      ActionRequested() => state.copyWith(
        pending: pending.copyWith(
          requests: pending.requests.put(
            event.request,
            PendingRequest(
              entity: event.entity,
              description: event.description,
              suggestedSkill: event.suggestedSkill,
              visibility: event.visibility,
            ),
          ),
        ),
      ),
      RequestDeclined() => state.copyWith(
        pending: pending.copyWith(
          requests: pending.requests.remove(event.request),
        ),
      ),
      CheckRequired() => state.copyWith(
        pending: pending.copyWith(
          checks: pending.checks.put(
            event.check,
            PendingCheck(event.spec, event.visibility),
          ),
          requests: switch (event.spec.request) {
            null => pending.requests,
            final request => pending.requests.remove(request),
          },
        ),
      ),
      CheckResolved() => state.copyWith(
        pending: pending.copyWith(checks: pending.checks.remove(event.check)),
      ),
    };
  }

  Decision _request(OperationState state, RequestAction command, IdSource ids) {
    if (!state.stores.has(Identity.componentType, command.entity)) {
      return _unknownEntity(command.entity);
    }
    if (command.description.trim().isEmpty) {
      return const Rejected(
        Rejection(RejectionCode.invalidValue, 'The description is empty.'),
      );
    }
    final skill = command.suggestedSkill;
    if (skill != null && pack.skill(skill) == null) {
      return _unknownSkill(skill);
    }
    return Accepted([
      ActionRequested(
        request: RequestId(ids.next().value),
        entity: command.entity,
        description: command.description,
        suggestedSkill: skill,
        actor: command.actor,
        // Proposed: a request is between the GM and the player who sent it.
        visibility: switch (command.actor) {
          AliasActor(:final alias) => AliasesOnly({alias}),
          GmActor() => const GmOnly(),
        },
      ),
    ]);
  }

  Decision _decline(OperationState state, DeclineRequest command) {
    final request = state.pending.requests[command.request];
    if (request == null) return _unknownRequest(command.request);
    return Accepted([
      RequestDeclined(
        request: command.request,
        reason: command.reason,
        actor: command.actor,
        visibility: request.visibility,
      ),
    ]);
  }

  Decision _require(
    OperationState state,
    RequireCheck command,
    Rng rng,
    IdSource ids,
  ) {
    final CheckSpec spec;
    switch (_spec(state, command)) {
      case _Invalid(:final rejection):
        return Rejected(rejection);
      case _Valid(:final value):
        spec = value;
    }
    final autoResolve = state.meta?.settings.autoResolveChecks ?? false;
    // Validate the roll before taking an id, so a rejection takes nothing.
    _Roll? roll;
    if (autoResolve) {
      switch (_prepareRoll(state, spec, rng)) {
        case _Invalid(:final rejection):
          return Rejected(rejection);
        case _Valid(:final value):
          roll = value;
      }
    }
    final check = CheckId(ids.next().value);
    final required = CheckRequired(
      check: check,
      spec: spec,
      actor: command.actor,
      visibility: command.visibility,
    );
    if (roll == null) return Accepted([required]);
    return Accepted([
      required,
      _roll(check, spec, roll, rng, command.actor, command.visibility),
    ]);
  }

  Decision _resolveCommand(
    OperationState state,
    ResolveCheck command,
    Rng rng,
  ) {
    final pending = state.pending.checks[command.check];
    if (pending == null) {
      return Rejected(
        Rejection(
          RejectionCode.unknownCheck,
          'No pending check "${command.check.value}".',
        ),
      );
    }
    final _Roll roll;
    switch (_prepareRoll(state, pending.spec, rng)) {
      case _Invalid(:final rejection):
        return Rejected(rejection);
      case _Valid(:final value):
        roll = value;
    }
    return Accepted([
      _roll(
        command.check,
        pending.spec,
        roll,
        rng,
        command.actor,
        pending.visibility,
      ),
    ]);
  }

  /// Builds the check's spec, or returns why it cannot be built.
  _Checked<CheckSpec> _spec(OperationState state, RequireCheck command) {
    if (pack.checkRules == null) {
      return const _Invalid(
        Rejection(RejectionCode.unavailable, 'The pack has no check rules.'),
      );
    }
    final scores = state.stores.get(Attributes.componentType, command.entity);
    if (scores == null) return _Invalid(_unknownEntity(command.entity).reason);
    final skillId = command.skill;
    final skill = skillId == null ? null : pack.skill(skillId);
    if (skillId != null && skill == null) {
      return _Invalid(_unknownSkill(skillId).reason);
    }
    final attribute = command.attribute ?? skill?.attribute;
    if (attribute == null) {
      return _Invalid(
        Rejection(
          RejectionCode.invalidValue,
          skill == null
              ? 'Name an attribute or a skill.'
              : '${skill.name} has no attribute set yet (pending D); '
                    'name the attribute.',
        ),
      );
    }
    if (pack.attribute(attribute) == null) {
      return _Invalid(
        Rejection(
          RejectionCode.unknownPackKey,
          'Unknown attribute "$attribute".',
        ),
      );
    }
    final dc = switch (command.difficulty) {
      CategoryDifficulty(:final category) =>
        pack.difficultyCategory(category)?.dc,
      FixedDifficulty(:final dc) => dc,
    };
    if (dc == null) {
      final category = (command.difficulty as CategoryDifficulty).category;
      return _Invalid(
        Rejection(
          RejectionCode.unknownPackKey,
          'Unknown difficulty category "$category".',
        ),
      );
    }
    for (final modifier in command.modifiers) {
      if (modifier.label.trim().isEmpty) {
        return const _Invalid(
          Rejection(
            RejectionCode.invalidValue,
            'Every modifier needs a label.',
          ),
        );
      }
    }
    final request = command.request;
    if (request != null && state.pending.requests[request] == null) {
      return _Invalid(_unknownRequest(request).reason);
    }
    return _Valid(
      CheckSpec(
        entity: command.entity,
        attribute: attribute,
        skill: skillId,
        category: switch (command.difficulty) {
          CategoryDifficulty(:final category) => category,
          FixedDifficulty() => null,
        },
        dc: dc,
        modifiers: command.modifiers,
        request: request,
      ),
    );
  }

  /// Checks everything a roll needs, without drawing.
  _Checked<_Roll> _prepareRoll(OperationState state, CheckSpec spec, Rng rng) {
    final expected = state.rng.drawCount;
    if (rng.drawCount != expected) {
      return _Invalid(
        Rejection(
          RejectionCode.rngOutOfSync,
          'The RNG is at draw ${rng.drawCount} but the operation is at '
          'draw $expected.',
        ),
      );
    }
    final scores = state.stores.get(Attributes.componentType, spec.entity);
    final score = scores?[spec.attribute];
    if (scores == null || score == null) {
      return _Invalid(
        Rejection(
          RejectionCode.invalidValue,
          '${spec.entity.value} has no ${spec.attribute} score.',
        ),
      );
    }
    final skill = spec.skill;
    final tier = skill == null
        ? null
        : state.stores.get(Skills.componentType, spec.entity)?[skill];
    final tierDef = tier == null ? null : pack.proficiencyTier(tier);
    if (tier != null && tierDef == null) {
      return _Invalid(
        Rejection(
          RejectionCode.unknownPackKey,
          'Unknown proficiency tier "$tier".',
        ),
      );
    }
    final primary = pack.checkRules!.primaryDie;
    final bonus = tierDef?.bonus;
    // Every value the expressions read must be present before the first
    // draw, or a failed evaluation would consume draws (draw-count
    // invariant).
    for (final expr in [primary, ?bonus]) {
      // A division by zero depends on the faces, so it could only show up
      // after drawing. Check dice may not divide. (A result too large for
      // every platform is the one failure left after the first draw; with
      // real dice it cannot happen, and `Engine.decide` guards it.)
      if (_divides(expr)) {
        return const _Invalid(
          Rejection(
            RejectionCode.evaluationFailed,
            'Check dice may not divide.',
          ),
        );
      }
      if (expr.varKeys.isNotEmpty) {
        return const _Invalid(
          Rejection(
            RejectionCode.evaluationFailed,
            'Check dice may not read var values.',
          ),
        );
      }
      final missing = expr.attributeKeys.difference(scores.scores.keys.toSet());
      if (missing.isNotEmpty) {
        return _Invalid(
          Rejection(
            RejectionCode.evaluationFailed,
            '${spec.entity.value} has no score for ${missing.join(', ')}.',
          ),
        );
      }
    }
    return _Valid(
      _Roll(
        scores: scores.scores.asMap(),
        score: score,
        tier: tier,
        primary: primary,
        bonus: bonus,
      ),
    );
  }

  CheckResolved _roll(
    CheckId check,
    CheckSpec spec,
    _Roll roll,
    Rng rng,
    Actor actor,
    Visibility visibility,
  ) {
    final start = rng.drawCount;
    final primary = evaluate(roll.primary, attributes: roll.scores, rng: rng);
    final bonus = roll.bonus;
    final proficiency = bonus == null
        ? null
        : evaluate(bonus, attributes: roll.scores, rng: rng);
    final breakdown = CheckBreakdown(
      primary: primary,
      attribute: spec.attribute,
      attributeScore: roll.score,
      skill: spec.skill,
      tier: roll.tier,
      proficiency: proficiency,
      modifiers: spec.modifiers,
    );
    return CheckResolved(
      check: check,
      spec: spec,
      breakdown: breakdown,
      outcome: _outcome(breakdown.total, spec.dc),
      draws: DrawRange(start, rng.drawCount),
      actor: actor,
      visibility: visibility,
    );
  }

  CheckOutcome _outcome(num total, int dc) {
    if (total >= dc) return CheckOutcome.success;
    if (dc - total <= pack.checkRules!.partialSuccessWithin) {
      return CheckOutcome.partialSuccess;
    }
    return CheckOutcome.failure;
  }

  Rejected _unknownEntity(EntityId entity) => Rejected(
    Rejection(RejectionCode.unknownEntity, 'No entity "${entity.value}".'),
  );

  Rejected _unknownSkill(String skill) => Rejected(
    Rejection(RejectionCode.unknownPackKey, 'Unknown skill "$skill".'),
  );

  Rejected _unknownRequest(RequestId request) => Rejected(
    Rejection(
      RejectionCode.unknownRequest,
      'No open request "${request.value}".',
    ),
  );
}

/// What a validated roll needs.
final class _Roll {
  const _Roll({
    required this.scores,
    required this.score,
    required this.tier,
    required this.primary,
    required this.bonus,
  });

  final Map<String, num> scores;
  final int score;
  final String? tier;
  final Expr primary;
  final Expr? bonus;
}

/// A validation result: the value, or why there is none.
sealed class _Checked<T> {
  const _Checked();
}

final class _Valid<T> extends _Checked<T> {
  const _Valid(this.value);

  final T value;
}

final class _Invalid<T> extends _Checked<T> {
  const _Invalid(this.rejection);

  final Rejection rejection;
}

/// Whether [expr] divides anywhere.
bool _divides(Expr expr) => switch (expr) {
  Op(op: OpKind.div) => true,
  Op(:final args) => args.any(_divides),
  Sum(:final terms) => terms.any(_divides),
  KeepHighest(:final pool) => pool.any(_divides),
  Const() || Attr() || Var() || Dice() => false,
};
