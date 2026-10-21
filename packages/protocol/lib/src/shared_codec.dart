import 'package:engine/engine.dart';
import 'package:protocol_envelope/protocol_envelope.dart';

import 'json_read.dart';

/// Wire shape version of the commands and events in this package. A decoder
/// reads shapes up to this number and refuses newer ones (03 §Envelope:
/// "a versioned JSON shape"). Fields added within a major are optional, so
/// older frames keep decoding (01 §Compatibility decoding within a major).
const int shapeVersion = 1;

/// Thrown for a command or event `type` this version does not know, for
/// example one added by a later minor. The session decides whether to skip or
/// refuse it.
class UnknownTypeException extends ProtocolFormatException {
  /// Creates the exception for [type].
  UnknownTypeException(this.type, String family)
    : super('unknown $family type "$type"');

  /// The unrecognised `type` string.
  final String type;
}

/// Deepest nesting a command or event may have. Real formulas are a handful
/// of levels deep; the limit stops hostile input from overflowing the stack
/// in the recursive term and condition decoders.
const int maxJsonDepth = 64;

/// Throws [ProtocolFormatException] when [json] nests deeper than
/// [maxJsonDepth]. Stops descending at the limit, so it is safe on input of
/// any depth.
void checkJsonDepth(Object? json, [int depth = 0]) {
  if (depth > maxJsonDepth) {
    throw ProtocolFormatException('nested deeper than $maxJsonDepth levels');
  }
  if (json is Map) {
    for (final value in json.values) {
      checkJsonDepth(value, depth + 1);
    }
  } else if (json is List) {
    for (final value in json) {
      checkJsonDepth(value, depth + 1);
    }
  }
}

/// [map] with its keys in sorted order, so equal values always encode to the
/// same text.
Map<String, V> sortedKeys<V>(Map<String, V> map) => {
  for (final key in map.keys.toList()..sort()) key: map[key] as V,
};

/// Checks the `v` field of a command or event.
void checkShapeVersion(JsonMap json) {
  final v = json.integer('v');
  if (v < 1 || v > shapeVersion) {
    throw ProtocolFormatException(
      'shape version $v is not supported (this build reads 1 to '
      '$shapeVersion)',
    );
  }
}

/// Encodes the actor as JSON.
JsonMap encodeActor(Actor actor) => switch (actor) {
  GmActor() => {'kind': 'gm'},
  AliasActor(:final alias) => {'kind': 'alias', 'alias': alias.value},
};

/// Decodes the actor from JSON; throws [ProtocolFormatException] when malformed.
Actor decodeActor(JsonMap json) => switch (json.string('kind')) {
  'gm' => const GmActor(),
  'alias' => AliasActor(AliasId(json.string('alias'))),
  final other => throw ProtocolFormatException('unknown actor kind "$other"'),
};

/// Encodes the phone party as JSON.
JsonMap encodeParty(PhoneParty party) => switch (party) {
  PhoneGm() => {'kind': 'gm'},
  PhoneAlias(:final alias) => {'kind': 'alias', 'alias': alias.value},
  PhoneNpc(:final entity) => {'kind': 'npc', 'entity': entity.value},
};

/// Decodes the phone party from JSON; throws [ProtocolFormatException] when malformed.
PhoneParty decodeParty(JsonMap json) => switch (json.string('kind')) {
  'gm' => const PhoneGm(),
  'alias' => PhoneAlias(AliasId(json.string('alias'))),
  'npc' => PhoneNpc(EntityId(json.string('entity'))),
  final other => throw ProtocolFormatException(
    'unknown phone party kind "$other"',
  ),
};

/// Encodes the visibility as JSON.
JsonMap encodeVisibility(Visibility visibility) => switch (visibility) {
  Public() => {'kind': 'public'},
  GmOnly() => {'kind': 'gmOnly'},
  Redacted() => {'kind': 'redacted'},
  AliasesOnly(:final aliases) => {
    'kind': 'aliases',
    // Sorted so the same event always encodes to the same text.
    'aliases': ([for (final a in aliases) a.value]..sort()),
  },
};

/// Decodes the visibility from JSON; throws [ProtocolFormatException] when malformed.
Visibility decodeVisibility(JsonMap json) => switch (json.string('kind')) {
  'public' => const Public(),
  'gmOnly' => const GmOnly(),
  'redacted' => const Redacted(),
  'aliases' => decodeAliasesOnly(json),
  final other => throw ProtocolFormatException(
    'unknown visibility kind "$other"',
  ),
};

/// Decodes the aliases only from JSON; throws [ProtocolFormatException] when malformed.
AliasesOnly decodeAliasesOnly(JsonMap json) {
  if (json.string('kind') != 'aliases') {
    throw const ProtocolFormatException('visibility must list aliases');
  }
  final aliases = {
    for (final a in json.list('aliases'))
      AliasId(
        a is String
            ? a
            : throw const ProtocolFormatException('aliases must be strings'),
      ),
  };
  return guarded('visibility', () => AliasesOnly(aliases));
}

/// Encodes the settings as JSON.
JsonMap encodeSettings(OperationSettings s) => {
  'autoResolveChecks': s.autoResolveChecks,
  'autoConfirmConsequences': s.autoConfirmConsequences,
  'autoApplyEngineUpdates': s.autoApplyEngineUpdates,
  'autoApplyPackUpdates': s.autoApplyPackUpdates,
};

/// Settings added later decode to their defaults when absent.
OperationSettings decodeSettings(JsonMap json) {
  const defaults = OperationSettings();
  return OperationSettings(
    autoResolveChecks: json.boolOr(
      'autoResolveChecks',
      defaults.autoResolveChecks,
    ),
    autoConfirmConsequences: json.boolOr(
      'autoConfirmConsequences',
      defaults.autoConfirmConsequences,
    ),
    autoApplyEngineUpdates: json.boolOr(
      'autoApplyEngineUpdates',
      defaults.autoApplyEngineUpdates,
    ),
    autoApplyPackUpdates: json.boolOr(
      'autoApplyPackUpdates',
      defaults.autoApplyPackUpdates,
    ),
  );
}

/// Encodes the pack ref as JSON.
JsonMap encodePackRef(PackRef ref) => {
  'id': ref.id,
  'version': ref.version,
  'contentHash': ref.contentHash,
};

/// Decodes the pack ref from JSON; throws [ProtocolFormatException] when malformed.
PackRef decodePackRef(JsonMap json) => PackRef(
  id: json.string('id'),
  version: json.string('version'),
  contentHash: json.string('contentHash'),
);

/// Encodes the difficulty as JSON.
JsonMap encodeDifficulty(Difficulty d) => switch (d) {
  CategoryDifficulty(:final category) => {
    'kind': 'category',
    'category': category,
  },
  FixedDifficulty(:final dc) => {'kind': 'fixed', 'dc': dc},
};

/// Decodes the difficulty from JSON; throws [ProtocolFormatException] when malformed.
Difficulty decodeDifficulty(JsonMap json) => switch (json.string('kind')) {
  'category' => CategoryDifficulty(json.string('category')),
  'fixed' => FixedDifficulty(json.integer('dc')),
  final other => throw ProtocolFormatException(
    'unknown difficulty kind "$other"',
  ),
};

/// Encodes the modifier as JSON.
JsonMap encodeModifier(CheckModifier m) => {'label': m.label, 'value': m.value};

/// Decodes the modifier from JSON; throws [ProtocolFormatException] when malformed.
CheckModifier decodeModifier(JsonMap json) =>
    CheckModifier(json.string('label'), json.integer('value'));

/// Encodes the modifiers as JSON.
List<JsonMap> encodeModifiers(List<CheckModifier> list) => [
  for (final m in list) encodeModifier(m),
];

/// Decodes the modifiers from JSON; throws [ProtocolFormatException] when malformed.
List<CheckModifier> decodeModifiers(JsonMap json, String key) => [
  for (final m in json.objectList(key)) decodeModifier(m),
];

/// Encodes the spec as JSON.
JsonMap encodeSpec(CheckSpec s) => {
  'entity': s.entity.value,
  'attribute': s.attribute,
  'skill': s.skill,
  'category': s.category,
  'dc': s.dc,
  'modifiers': encodeModifiers(s.modifiers),
  'request': s.request?.value,
};

/// Decodes the spec from JSON; throws [ProtocolFormatException] when malformed.
CheckSpec decodeSpec(JsonMap json) => CheckSpec(
  entity: EntityId(json.string('entity')),
  attribute: json.string('attribute'),
  skill: json.optString('skill'),
  category: json.optString('category'),
  dc: json.integer('dc'),
  modifiers: decodeModifiers(json, 'modifiers'),
  request: optRequest(json, 'request'),
);

/// An optional request id; `null` when absent.
RequestId? optRequest(JsonMap json, String key) {
  final id = json.optString(key);
  return id == null ? null : RequestId(id);
}

/// An optional check id; `null` when absent.
CheckId? optCheck(JsonMap json, String key) {
  final id = json.optString(key);
  return id == null ? null : CheckId(id);
}

/// Encodes the draws as JSON.
JsonMap encodeDraws(DrawRange r) => {'start': r.start, 'end': r.end};

/// Decodes the draws from JSON; throws [ProtocolFormatException] when malformed.
DrawRange decodeDraws(JsonMap json) => guarded(
  'draws',
  () => DrawRange(json.integer('start'), json.integer('end')),
);

/// Encodes the breakdown as JSON.
JsonMap encodeBreakdown(CheckBreakdown b) => {
  'primary': encodeTerm(b.primary),
  'attribute': b.attribute,
  'attributeScore': b.attributeScore,
  'skill': b.skill,
  'tier': b.tier,
  'proficiency': b.proficiency == null ? null : encodeTerm(b.proficiency!),
  'modifiers': encodeModifiers(b.modifiers),
};

/// Decodes the breakdown from JSON; throws [ProtocolFormatException] when malformed.
CheckBreakdown decodeBreakdown(JsonMap json) {
  final proficiency = json.optObject('proficiency');
  return CheckBreakdown(
    primary: decodeTerm(json.object('primary')),
    attribute: json.string('attribute'),
    attributeScore: json.integer('attributeScore'),
    skill: json.optString('skill'),
    tier: json.optString('tier'),
    proficiency: proficiency == null ? null : decodeTerm(proficiency),
    modifiers: decodeModifiers(json, 'modifiers'),
  );
}

/// Encodes an evaluated formula tree, with every die face (01 §Dice and
/// checks: the log stores resolved results, so history never changes).
JsonMap encodeTerm(Term term) => switch (term) {
  ConstTerm(:final value) => {'type': 'const', 'value': value},
  AttrTerm(:final key, :final value) => {
    'type': 'attr',
    'key': key,
    'value': value,
  },
  VarTerm(:final key, :final value) => {
    'type': 'var',
    'key': key,
    'value': value,
  },
  DiceTerm(:final sides, :final explode, :final rolls) => {
    'type': 'dice',
    'sides': sides,
    'explode': explode,
    'rolls': [for (final roll in rolls) roll.faces],
  },
  SumTerm(:final terms) => {
    'type': 'sum',
    'terms': [for (final t in terms) encodeTerm(t)],
  },
  KeepHighestTerm(:final options, :final kept) => {
    'type': 'keepHighest',
    'options': [for (final t in options) encodeTerm(t)],
    'kept': kept,
  },
  OpTerm(:final op, :final args, :final value) => {
    'type': 'op',
    'op': op.name,
    'args': [for (final t in args) encodeTerm(t)],
    'value': value,
  },
};

/// Decodes the term from JSON; throws [ProtocolFormatException] when malformed.
Term decodeTerm(JsonMap json) => guarded('term', () {
  switch (json.string('type')) {
    case 'const':
      return ConstTerm(normalizeNumber(json.number('value')));
    case 'attr':
      return AttrTerm(
        json.string('key'),
        normalizeNumber(json.number('value')),
      );
    case 'var':
      return VarTerm(json.string('key'), normalizeNumber(json.number('value')));
    case 'dice':
      final sides = json.integer('sides');
      if (sides < 1) throw const ProtocolFormatException('sides must be >= 1');
      return DiceTerm(
        sides: sides,
        explode: json.optBool('explode'),
        rolls: [
          for (final roll in json.list('rolls'))
            DieRoll([
              for (final face in roll is List<Object?> ? roll : const [])
                face is int && face >= 1 && face <= sides
                    ? face
                    : throw const ProtocolFormatException(
                        'die faces must be integers from 1 to sides',
                      ),
            ]),
        ],
      );
    case 'sum':
      final terms = [for (final t in json.objectList('terms')) decodeTerm(t)];
      if (terms.isEmpty) {
        throw const ProtocolFormatException('sum needs at least one term');
      }
      return SumTerm(terms);
    case 'keepHighest':
      final options = [
        for (final t in json.objectList('options')) decodeTerm(t),
      ];
      final kept = [
        for (final i in json.list('kept'))
          i is int && i >= 0 && i < options.length
              ? i
              : throw const ProtocolFormatException(
                  'kept must index into options',
                ),
      ];
      return KeepHighestTerm(options: options, kept: kept);
    case 'op':
      final op = enumByName(OpKind.values, json, 'op');
      final args = [for (final t in json.objectList('args')) decodeTerm(t)];
      if (args.length < op.minArgs ||
          (op.maxArgs != null && args.length > op.maxArgs!)) {
        throw ProtocolFormatException(
          '${op.name} has the wrong argument count',
        );
      }
      return OpTerm(op, args, normalizeNumber(json.number('value')));
    case final other:
      throw ProtocolFormatException('unknown term type "$other"');
  }
});

/// A condition from the engine's own JSON form, with errors as
/// [ProtocolFormatException].
Condition decodeConditionField(JsonMap json, String key) =>
    guarded(key, () => decodeCondition(json.object(key)));
