import 'package:engine/engine.dart';
import 'package:protocol_envelope/protocol_envelope.dart';

import 'json_read.dart';
import 'shared_codec.dart';

/// Encodes an engine [Command] as JSON for the `request` message body.
///
/// Every command carries `v` (shape version), `type` (a stable name, the
/// class name in lower camel case), the `actor` and its own fields. Hand
/// written, no code generation (P6).
JsonMap encodeCommand(Command command) {
  final body = switch (command) {
    StartOperation(:final operationId, :final settings) => (
      'startOperation',
      {'operationId': operationId, 'settings': encodeSettings(settings)},
    ),
    CreateAgent(
      :final name,
      :final attributes,
      :final skills,
      :final ownerAlias,
    ) =>
      (
        'createAgent',
        {
          'name': name,
          'attributes': attributes.asMap(),
          'skills': skills.asMap(),
          'ownerAlias': ownerAlias?.value,
        },
      ),
    RequestAction(:final entity, :final description, :final suggestedSkill) => (
      'requestAction',
      {
        'entity': entity.value,
        'description': description,
        'suggestedSkill': suggestedSkill,
      },
    ),
    DeclineRequest(:final request, :final reason) => (
      'declineRequest',
      {'request': request.value, 'reason': reason},
    ),
    RequireCheck(
      :final entity,
      :final attribute,
      :final skill,
      :final difficulty,
      :final modifiers,
      :final request,
      :final visibility,
    ) =>
      (
        'requireCheck',
        {
          'entity': entity.value,
          'attribute': attribute,
          'skill': skill,
          'difficulty': encodeDifficulty(difficulty),
          'modifiers': encodeModifiers(modifiers),
          'request': request?.value,
          'visibility': encodeVisibility(visibility),
        },
      ),
    ResolveCheck(:final check) => ('resolveCheck', {'check': check.value}),
    ApplyCondition(
      :final entity,
      :final condition,
      :final check,
      :final visibility,
    ) =>
      (
        'applyCondition',
        {
          'entity': entity.value,
          'condition': condition,
          'check': check?.value,
          'visibility': encodeVisibility(visibility),
        },
      ),
    ClearCondition(:final entity, :final condition, :final visibility) => (
      'clearCondition',
      {
        'entity': entity.value,
        'condition': condition,
        'visibility': encodeVisibility(visibility),
      },
    ),
    ApplyDamage(
      :final entity,
      :final amount,
      :final check,
      :final visibility,
    ) =>
      (
        'applyDamage',
        {
          'entity': entity.value,
          'amount': amount,
          'check': check?.value,
          'visibility': encodeVisibility(visibility),
        },
      ),
    ApplySanityLoss(
      :final entity,
      :final amount,
      :final check,
      :final visibility,
    ) =>
      (
        'applySanityLoss',
        {
          'entity': entity.value,
          'amount': amount,
          'check': check?.value,
          'visibility': encodeVisibility(visibility),
        },
      ),
    BroadcastToQualifying(:final text, :final condition) => (
      'broadcastToQualifying',
      {'text': text, 'condition': encodeCondition(condition)},
    ),
  };
  return {
    'v': shapeVersion,
    'type': body.$1,
    'actor': encodeActor(command.actor),
    ...body.$2,
  };
}

/// Decodes a command from the JSON [encodeCommand] writes.
///
/// Throws [UnknownTypeException] for a `type` this build does not know and
/// [ProtocolFormatException] for anything malformed. Unknown extra fields are
/// ignored (additive changes within a major).
Command decodeCommand(Object? json) {
  final map = asMap(json, 'command');
  checkShapeVersion(map);
  final actor = decodeActor(map.object('actor'));
  return guarded('command', () {
    switch (map.string('type')) {
      case 'startOperation':
        return StartOperation(
          operationId: map.string('operationId'),
          settings: decodeSettings(map.object('settings')),
          actor: actor,
        );
      case 'createAgent':
        final owner = map.optString('ownerAlias');
        return CreateAgent(
          name: map.string('name'),
          attributes: map.intMap('attributes'),
          skills: map.stringMap('skills'),
          ownerAlias: owner == null ? null : AliasId(owner),
          actor: actor,
        );
      case 'requestAction':
        return RequestAction(
          entity: EntityId(map.string('entity')),
          description: map.string('description'),
          suggestedSkill: map.optString('suggestedSkill'),
          actor: actor,
        );
      case 'declineRequest':
        return DeclineRequest(
          request: RequestId(map.string('request')),
          reason: map.optString('reason'),
          actor: actor,
        );
      case 'requireCheck':
        return RequireCheck(
          entity: EntityId(map.string('entity')),
          attribute: map.optString('attribute'),
          skill: map.optString('skill'),
          difficulty: decodeDifficulty(map.object('difficulty')),
          modifiers: decodeModifiers(map, 'modifiers'),
          request: optRequest(map, 'request'),
          visibility: decodeVisibility(map.object('visibility')),
          actor: actor,
        );
      case 'resolveCheck':
        return ResolveCheck(check: CheckId(map.string('check')), actor: actor);
      case 'applyCondition':
        return ApplyCondition(
          entity: EntityId(map.string('entity')),
          condition: map.string('condition'),
          check: optCheck(map, 'check'),
          visibility: decodeVisibility(map.object('visibility')),
          actor: actor,
        );
      case 'clearCondition':
        return ClearCondition(
          entity: EntityId(map.string('entity')),
          condition: map.string('condition'),
          visibility: decodeVisibility(map.object('visibility')),
          actor: actor,
        );
      case 'applyDamage':
        return ApplyDamage(
          entity: EntityId(map.string('entity')),
          amount: map.integer('amount'),
          check: optCheck(map, 'check'),
          visibility: decodeVisibility(map.object('visibility')),
          actor: actor,
        );
      case 'applySanityLoss':
        return ApplySanityLoss(
          entity: EntityId(map.string('entity')),
          amount: map.integer('amount'),
          check: optCheck(map, 'check'),
          visibility: decodeVisibility(map.object('visibility')),
          actor: actor,
        );
      case 'broadcastToQualifying':
        return BroadcastToQualifying(
          text: map.string('text'),
          condition: decodeConditionField(map, 'condition'),
          actor: actor,
        );
      case final other:
        throw UnknownTypeException(other, 'command');
    }
  });
}
