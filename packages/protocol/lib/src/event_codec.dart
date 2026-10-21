import 'package:engine/engine.dart';
import 'package:protocol_envelope/protocol_envelope.dart';

import 'json_read.dart';
import 'shared_codec.dart';

/// Encodes an engine [Event] as JSON for an `events` message or a log line.
///
/// The encoding is 1:1 with the full event: the stored log, the GM and the
/// fixtures carry everything, including `BroadcastDelivered`'s recipient
/// list. Who may receive an event, and what a player's copy leaves out, is
/// decided by the session's per-perspective projection (04 §Perspectives),
/// not here.
JsonMap encodeEvent(Event event) {
  final body = switch (event) {
    OperationStarted(
      :final operationId,
      :final engineVersion,
      :final packRef,
      :final settings,
    ) =>
      (
        'operationStarted',
        {
          'operationId': operationId,
          'engineVersion': engineVersion,
          'packRef': encodePackRef(packRef),
          'settings': encodeSettings(settings),
        },
      ),
    AgentCreated(
      :final entity,
      :final name,
      :final attributes,
      :final skills,
      :final ownerAlias,
    ) =>
      (
        'agentCreated',
        {
          'entity': entity.value,
          'name': name,
          'attributes': attributes.asMap(),
          'skills': skills.asMap(),
          'ownerAlias': ownerAlias?.value,
        },
      ),
    ActionRequested(
      :final request,
      :final entity,
      :final description,
      :final suggestedSkill,
    ) =>
      (
        'actionRequested',
        {
          'request': request.value,
          'entity': entity.value,
          'description': description,
          'suggestedSkill': suggestedSkill,
        },
      ),
    RequestDeclined(:final request, :final reason) => (
      'requestDeclined',
      {'request': request.value, 'reason': reason},
    ),
    CheckRequired(:final check, :final spec) => (
      'checkRequired',
      {'check': check.value, 'spec': encodeSpec(spec)},
    ),
    CheckResolved(
      :final check,
      :final spec,
      :final breakdown,
      :final outcome,
      :final draws,
      :final source,
      :final enteredBy,
    ) =>
      (
        'checkResolved',
        {
          'check': check.value,
          'spec': encodeSpec(spec),
          'breakdown': encodeBreakdown(breakdown),
          'outcome': outcome.name,
          'draws': encodeDraws(draws),
          'source': source.name,
          'enteredBy': enteredBy == null ? null : encodeActor(enteredBy),
        },
      ),
    ConditionApplied(
      :final entity,
      :final condition,
      :final overriddenFrom,
      :final check,
    ) =>
      (
        'conditionApplied',
        {
          'entity': entity.value,
          'condition': condition,
          'overriddenFrom': overriddenFrom,
          'check': check?.value,
        },
      ),
    ConditionCleared(:final entity, :final condition) => (
      'conditionCleared',
      {'entity': entity.value, 'condition': condition},
    ),
    DamageApplied(
      :final entity,
      :final amount,
      :final overriddenFrom,
      :final check,
    ) =>
      (
        'damageApplied',
        {
          'entity': entity.value,
          'amount': amount,
          'overriddenFrom': overriddenFrom,
          'check': check?.value,
        },
      ),
    SanityLost(
      :final entity,
      :final amount,
      :final overriddenFrom,
      :final check,
    ) =>
      (
        'sanityLost',
        {
          'entity': entity.value,
          'amount': amount,
          'overriddenFrom': overriddenFrom,
          'check': check?.value,
        },
      ),
    BroadcastEvaluated(:final text, :final condition, :final candidates) => (
      'broadcastEvaluated',
      {
        'text': text,
        'condition': encodeCondition(condition),
        'candidates': [
          for (final c in candidates)
            {
              'alias': c.alias.value,
              'entity': c.entity.value,
              'result': c.result == null
                  ? null
                  : {
                      'passed': c.result!.passed,
                      'left': c.result!.left,
                      'right': c.result!.right,
                    },
            },
        ],
      },
    ),
    BroadcastDelivered(:final text) => ('broadcastDelivered', {'text': text}),
  };
  return {
    'v': shapeVersion,
    'type': body.$1,
    'actor': encodeActor(event.actor),
    'visibility': encodeVisibility(event.visibility),
    ...body.$2,
  };
}

/// Decodes an event from the JSON [encodeEvent] writes.
///
/// Throws [UnknownTypeException] for a `type` this build does not know and
/// [ProtocolFormatException] for anything malformed. Unknown extra fields are
/// ignored (additive changes within a major).
Event decodeEvent(Object? json) {
  final map = asMap(json, 'event');
  checkShapeVersion(map);
  final actor = decodeActor(map.object('actor'));
  final visibilityJson = map.object('visibility');
  return guarded('event', () {
    Visibility visibility() => decodeVisibility(visibilityJson);
    switch (map.string('type')) {
      case 'operationStarted':
        return OperationStarted(
          operationId: map.string('operationId'),
          engineVersion: map.string('engineVersion'),
          packRef: decodePackRef(map.object('packRef')),
          settings: decodeSettings(map.object('settings')),
          actor: actor,
          visibility: visibility(),
        );
      case 'agentCreated':
        final owner = map.optString('ownerAlias');
        return AgentCreated(
          entity: EntityId(map.string('entity')),
          name: map.string('name'),
          attributes: map.intMap('attributes'),
          skills: map.stringMap('skills'),
          ownerAlias: owner == null ? null : AliasId(owner),
          actor: actor,
          visibility: visibility(),
        );
      case 'actionRequested':
        return ActionRequested(
          request: RequestId(map.string('request')),
          entity: EntityId(map.string('entity')),
          description: map.string('description'),
          suggestedSkill: map.optString('suggestedSkill'),
          actor: actor,
          visibility: visibility(),
        );
      case 'requestDeclined':
        return RequestDeclined(
          request: RequestId(map.string('request')),
          reason: map.optString('reason'),
          actor: actor,
          visibility: visibility(),
        );
      case 'checkRequired':
        return CheckRequired(
          check: CheckId(map.string('check')),
          spec: decodeSpec(map.object('spec')),
          actor: actor,
          visibility: visibility(),
        );
      case 'checkResolved':
        final enteredBy = map.optObject('enteredBy');
        return CheckResolved(
          check: CheckId(map.string('check')),
          spec: decodeSpec(map.object('spec')),
          breakdown: decodeBreakdown(map.object('breakdown')),
          outcome: enumByName(CheckOutcome.values, map, 'outcome'),
          draws: decodeDraws(map.object('draws')),
          source: enumByName(RollSourceKind.values, map, 'source'),
          enteredBy: enteredBy == null ? null : decodeActor(enteredBy),
          actor: actor,
          visibility: visibility(),
        );
      case 'conditionApplied':
        return ConditionApplied(
          entity: EntityId(map.string('entity')),
          condition: map.string('condition'),
          overriddenFrom: map.optString('overriddenFrom'),
          check: optCheck(map, 'check'),
          actor: actor,
          visibility: visibility(),
        );
      case 'conditionCleared':
        return ConditionCleared(
          entity: EntityId(map.string('entity')),
          condition: map.string('condition'),
          actor: actor,
          visibility: visibility(),
        );
      case 'damageApplied':
        return DamageApplied(
          entity: EntityId(map.string('entity')),
          amount: map.integer('amount'),
          overriddenFrom: map.optInt('overriddenFrom'),
          check: optCheck(map, 'check'),
          actor: actor,
          visibility: visibility(),
        );
      case 'sanityLost':
        return SanityLost(
          entity: EntityId(map.string('entity')),
          amount: map.integer('amount'),
          overriddenFrom: map.optInt('overriddenFrom'),
          check: optCheck(map, 'check'),
          actor: actor,
          visibility: visibility(),
        );
      case 'broadcastEvaluated':
        return BroadcastEvaluated(
          text: map.string('text'),
          condition: decodeConditionField(map, 'condition'),
          candidates: [
            for (final c in map.objectList('candidates'))
              BroadcastCandidate(
                alias: AliasId(c.string('alias')),
                entity: EntityId(c.string('entity')),
                result: c.optObject('result') == null
                    ? null
                    : ConditionResult(
                        passed: c.object('result').boolean('passed'),
                        left: normalizeNumber(
                          c.object('result').number('left'),
                        ),
                        right: normalizeNumber(
                          c.object('result').number('right'),
                        ),
                      ),
              ),
          ],
          actor: actor,
        );
      case 'broadcastDelivered':
        return BroadcastDelivered(
          text: map.string('text'),
          actor: actor,
          visibility: decodeAliasesOnly(visibilityJson),
        );
      case final other:
        throw UnknownTypeException(other, 'event');
    }
  });
}
