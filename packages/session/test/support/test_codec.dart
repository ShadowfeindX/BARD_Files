import 'package:engine/engine.dart' hide Visibility;
import 'package:engine/engine.dart' as eng show Visibility;
import 'package:protocol/protocol.dart';

/// A throwaway [EngineCodec] for the commands and events that exist today
/// (`StartOperation`, `CreateAgent`, `OperationStarted`, `AgentCreated`).
/// The real codecs and their fixtures are row 6 in `protocol`.
final class TestCodec implements EngineCodec {
  /// Creates the codec.
  const TestCodec();

  @override
  JsonMap encodeCommand(Command command) => switch (command) {
    StartOperation() => {
      'type': 'StartOperation',
      'operationId': command.operationId,
      'settings': _settings(command.settings),
      'actor': _actor(command.actor),
    },
    CreateAgent() => {
      'type': 'CreateAgent',
      'name': command.name,
      'attributes': command.attributes.asMap(),
      'skills': command.skills.asMap(),
      'owner': command.ownerAlias?.value,
      'actor': _actor(command.actor),
    },
    ApplyDamage() => {
      'type': 'ApplyDamage',
      'entity': command.entity.value,
      'amount': command.amount,
      'visibility': _visibility(command.visibility),
      'actor': _actor(command.actor),
    },
    _ => throw UnsupportedError('TestCodec: $command'),
  };

  @override
  Command decodeCommand(JsonMap json) => switch (json['type']) {
    'StartOperation' => StartOperation(
      operationId: json['operationId']! as String,
      settings: _readSettings(json['settings']! as Map<String, Object?>),
      actor: _readActor(json['actor']),
    ),
    'CreateAgent' => CreateAgent(
      name: json['name']! as String,
      attributes: Map<String, int>.from(json['attributes']! as Map),
      skills: Map<String, String>.from(json['skills']! as Map),
      ownerAlias: json['owner'] == null
          ? null
          : AliasId(json['owner']! as String),
      actor: _readActor(json['actor']),
    ),
    'ApplyDamage' => ApplyDamage(
      entity: EntityId(json['entity']! as String),
      amount: json['amount']! as int,
      visibility: _readVisibility(json['visibility']),
      actor: _readActor(json['actor']),
    ),
    final other => throw ProtocolFormatException('unknown command $other'),
  };

  @override
  JsonMap encodeEvent(Event event) => switch (event) {
    OperationStarted() => {
      'type': 'OperationStarted',
      'operationId': event.operationId,
      'engineVersion': event.engineVersion,
      'pack': [
        event.packRef.id,
        event.packRef.version,
        event.packRef.contentHash,
      ],
      'settings': _settings(event.settings),
      'actor': _actor(event.actor),
      'visibility': _visibility(event.visibility),
    },
    AgentCreated() => {
      'type': 'AgentCreated',
      'entity': event.entity.value,
      'name': event.name,
      'attributes': event.attributes.asMap(),
      'skills': event.skills.asMap(),
      'owner': event.ownerAlias?.value,
      'actor': _actor(event.actor),
      'visibility': _visibility(event.visibility),
    },
    DamageApplied() => {
      'type': 'DamageApplied',
      'entity': event.entity.value,
      'amount': event.amount,
      'overriddenFrom': event.overriddenFrom,
      'actor': _actor(event.actor),
      'visibility': _visibility(event.visibility),
    },
    _ => throw UnsupportedError('TestCodec: $event'),
  };

  @override
  Event decodeEvent(JsonMap json) => switch (json['type']) {
    'OperationStarted' => OperationStarted(
      operationId: json['operationId']! as String,
      engineVersion: json['engineVersion']! as String,
      packRef: PackRef(
        id: (json['pack']! as List)[0] as String,
        version: (json['pack']! as List)[1] as String,
        contentHash: (json['pack']! as List)[2] as String,
      ),
      settings: _readSettings(json['settings']! as Map<String, Object?>),
      actor: _readActor(json['actor']),
      visibility: _readVisibility(json['visibility']),
    ),
    'AgentCreated' => AgentCreated(
      entity: EntityId(json['entity']! as String),
      name: json['name']! as String,
      attributes: Map<String, int>.from(json['attributes']! as Map),
      skills: Map<String, String>.from(json['skills']! as Map),
      ownerAlias: json['owner'] == null
          ? null
          : AliasId(json['owner']! as String),
      actor: _readActor(json['actor']),
      visibility: _readVisibility(json['visibility']),
    ),
    'DamageApplied' => DamageApplied(
      entity: EntityId(json['entity']! as String),
      amount: json['amount']! as int,
      overriddenFrom: json['overriddenFrom'] as int?,
      actor: _readActor(json['actor']),
      visibility: _readVisibility(json['visibility']),
    ),
    final other => throw ProtocolFormatException('unknown event $other'),
  };

  @override
  JsonMap encodeState(OperationState state) => {
    'started': state.started,
    'entities': state.stores.entities.length,
  };

  @override
  OperationState decodeState(JsonMap json) => throw UnsupportedError(
    'The host replays events; it never decodes state.',
  );

  static JsonMap _settings(OperationSettings s) => {
    'autoResolveChecks': s.autoResolveChecks,
    'autoConfirmConsequences': s.autoConfirmConsequences,
    'autoApplyEngineUpdates': s.autoApplyEngineUpdates,
    'autoApplyPackUpdates': s.autoApplyPackUpdates,
  };

  static OperationSettings _readSettings(Map<String, Object?> j) =>
      OperationSettings(
        autoResolveChecks: j['autoResolveChecks']! as bool,
        autoConfirmConsequences: j['autoConfirmConsequences']! as bool,
        autoApplyEngineUpdates: j['autoApplyEngineUpdates']! as bool,
        autoApplyPackUpdates: j['autoApplyPackUpdates']! as bool,
      );

  static Object _actor(Actor a) => switch (a) {
    GmActor() => 'gm',
    AliasActor(:final alias) => 'alias:${alias.value}',
  };

  static Actor _readActor(Object? j) {
    final text = j! as String;
    return text == 'gm'
        ? const GmActor()
        : AliasActor(AliasId(text.substring('alias:'.length)));
  }

  static Object _visibility(eng.Visibility v) => switch (v) {
    Public() => 'public',
    GmOnly() => 'gm',
    Redacted() => 'redacted',
    AliasesOnly(:final aliases) => [for (final a in aliases) a.value],
  };

  static eng.Visibility _readVisibility(Object? j) => switch (j) {
    'public' => const Public(),
    'gm' => const GmOnly(),
    'redacted' => const Redacted(),
    List() => AliasesOnly({for (final a in j) AliasId(a as String)}),
    _ => throw const ProtocolFormatException('bad visibility'),
  };
}
