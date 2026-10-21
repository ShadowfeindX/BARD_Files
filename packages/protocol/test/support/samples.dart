import 'package:engine/engine.dart';

const vale = EntityId('e1');
const valeAlias = AliasId('al_vale');
const quinnAlias = AliasId('al_quinn');

/// One realistic command of every kind; the key is its wire `type`.
final Map<String, Command> sampleCommands = {
  'startOperation': const StartOperation(
    operationId: 'op_01J8Z3',
    settings: OperationSettings(autoConfirmConsequences: true),
  ),
  'createAgent': CreateAgent(
    name: 'Agent Vale',
    attributes: {'STR': 1, 'END': 2, 'WIL': 2, 'LCK': 3},
    skills: {'firearms': 'proficient'},
    ownerAlias: valeAlias,
  ),
  'requestAction': const RequestAction(
    entity: vale,
    description: 'Shoot the lock',
    suggestedSkill: 'firearms',
    actor: AliasActor(valeAlias),
  ),
  'declineRequest': const DeclineRequest(
    request: RequestId('r1'),
    reason: 'Not now',
  ),
  'requireCheck': RequireCheck(
    entity: vale,
    skill: 'firearms',
    difficulty: const CategoryDifficulty('C'),
    modifiers: const [CheckModifier('Cover', -2)],
    request: const RequestId('r1'),
    visibility: AliasesOnly({valeAlias, quinnAlias}),
  ),
  'resolveCheck': const ResolveCheck(check: CheckId('c1')),
  'applyCondition': const ApplyCondition(
    entity: vale,
    condition: 'bleeding',
    check: CheckId('c1'),
  ),
  'clearCondition': const ClearCondition(
    entity: vale,
    condition: 'bleeding',
    visibility: GmOnly(),
  ),
  'applyDamage': const ApplyDamage(
    entity: vale,
    amount: 4,
    check: CheckId('c1'),
  ),
  'applySanityLoss': const ApplySanityLoss(entity: vale, amount: 3),
  'sendPhoneMessage': const SendPhoneMessage(
    from: PhoneAlias(valeAlias),
    to: PhoneNpc(EntityId('e3')),
    text: 'Who goes there?',
    actor: AliasActor(valeAlias),
  ),
  'broadcastToQualifying': BroadcastToQualifying(
    text: 'A low groaning voice.',
    condition: Compare(CompareOp.lt, Attr('WIL'), Const(3)),
  ),
};

final _spec = CheckSpec(
  entity: vale,
  attribute: 'DEX',
  skill: 'firearms',
  category: 'C',
  dc: 10,
  modifiers: const [CheckModifier('Cover', -2)],
  request: const RequestId('r1'),
);

/// The breakdown of a check with an exploded primary die and a proficiency
/// die.
final sampleBreakdown = CheckBreakdown(
  primary: DiceTerm(
    sides: 6,
    explode: true,
    rolls: [
      DieRoll([6, 3]),
    ],
  ),
  attribute: 'DEX',
  attributeScore: 2,
  skill: 'firearms',
  tier: 'proficient',
  proficiency: DiceTerm(
    sides: 4,
    explode: null,
    rolls: [
      DieRoll([2]),
    ],
  ),
  modifiers: const [CheckModifier('Cover', -2)],
);

/// One realistic event of every kind; the key is its wire `type`.
final Map<String, Event> sampleEvents = {
  'operationStarted': const OperationStarted(
    operationId: 'op_01J8Z3',
    engineVersion: '1.0.0-dev.1',
    packRef: PackRef(
      id: 'example-core',
      version: '0.0.1',
      contentHash: 'sha256:00ff',
    ),
    settings: OperationSettings(),
    actor: GmActor(),
  ),
  'agentCreated': AgentCreated(
    entity: vale,
    name: 'Agent Vale',
    attributes: {'STR': 1, 'END': 2, 'WIL': 2, 'LCK': 3},
    skills: {'firearms': 'proficient'},
    ownerAlias: valeAlias,
    actor: const GmActor(),
    visibility: const Public(),
  ),
  'actionRequested': ActionRequested(
    request: const RequestId('r1'),
    entity: vale,
    description: 'Shoot the lock',
    suggestedSkill: 'firearms',
    actor: const AliasActor(valeAlias),
    visibility: AliasesOnly({valeAlias}),
  ),
  'requestDeclined': const RequestDeclined(
    request: RequestId('r1'),
    reason: 'Not now',
    actor: GmActor(),
    visibility: Public(),
  ),
  'checkRequired': CheckRequired(
    check: const CheckId('c1'),
    spec: _spec,
    actor: const GmActor(),
    visibility: const Public(),
  ),
  'checkResolved': CheckResolved(
    check: const CheckId('c1'),
    spec: _spec,
    breakdown: sampleBreakdown,
    outcome: CheckOutcome.success,
    draws: DrawRange(0, 3),
    actor: const GmActor(),
    visibility: const Public(),
  ),
  'conditionApplied': const ConditionApplied(
    entity: vale,
    condition: 'bleeding',
    overriddenFrom: 'stunned',
    check: CheckId('c1'),
    actor: GmActor(),
    visibility: Public(),
  ),
  'conditionCleared': const ConditionCleared(
    entity: vale,
    condition: 'bleeding',
    actor: GmActor(),
    visibility: Public(),
  ),
  'damageApplied': const DamageApplied(
    entity: vale,
    amount: 3,
    overriddenFrom: 4,
    check: CheckId('c1'),
    actor: GmActor(),
    visibility: Public(),
  ),
  'sanityLost': const SanityLost(
    entity: vale,
    amount: 2,
    actor: GmActor(),
    visibility: Redacted(),
  ),
  'broadcastEvaluated': BroadcastEvaluated(
    text: 'A low groaning voice.',
    condition: Compare(CompareOp.lt, Attr('WIL'), Const(3)),
    candidates: const [
      BroadcastCandidate(
        alias: valeAlias,
        entity: vale,
        result: ConditionResult(passed: true, left: 2, right: 3),
      ),
      BroadcastCandidate(
        alias: quinnAlias,
        entity: EntityId('e2'),
        result: null,
      ),
    ],
    actor: const GmActor(),
  ),
  'phoneMessageSent': PhoneMessageSent(
    from: const PhoneNpc(EntityId('e3')),
    to: const PhoneAlias(valeAlias),
    text: 'Go away.',
    actor: const GmActor(),
    visibility: AliasesOnly({valeAlias}),
  ),
  'broadcastDelivered': BroadcastDelivered(
    text: 'A low groaning voice.',
    actor: const GmActor(),
    visibility: AliasesOnly({valeAlias, quinnAlias}),
  ),
};
