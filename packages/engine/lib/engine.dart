/// The B.A.R.D. Files game engine: pure Dart, Dart SDK only.
///
/// Turns commands into events (`Engine.decide`) and events into state
/// (`Engine.evolve`). See `docs/architecture/01-engine.md`.
library;

export 'src/actor.dart';
export 'src/checks/check_types.dart';
export 'src/commands/commands.dart';
export 'src/components/components.dart';
export 'src/decision.dart';
export 'src/engine.dart';
export 'src/deprecation.dart';
export 'src/pack/files/advancement.dart' hide parseAdvancement;
export 'src/pack/files/attributes.dart' hide parseAttributes, AttributesFile;
export 'src/pack/files/conditions.dart' hide parseConditions;
export 'src/pack/files/damage.dart' hide parseDamage;
export 'src/pack/files/derived.dart' hide parseDerived;
export 'src/pack/files/difficulty.dart' hide parseDifficulty, DifficultyFile;
export 'src/pack/files/disorders.dart' hide parseDisorders;
export 'src/pack/files/items.dart' hide parseItem;
export 'src/pack/files/manifest.dart' hide parseManifest;
export 'src/pack/files/npcs.dart' hide parseNpc;
export 'src/pack/files/proficiency.dart' hide parseProficiency, ProficiencyFile;
export 'src/pack/files/ranges.dart' hide parseRanges;
export 'src/pack/files/sanity_events.dart' hide parseSanityEvents;
export 'src/pack/files/skills.dart' hide parseSkills, SkillsFile;
export 'src/pack/files/strings.dart' hide parseStrings;
export 'src/pack/files/techniques.dart' hide parseTechnique;
export 'src/pack/files/threats.dart' hide parseThreats, ThreatsFile;
export 'src/pack/files/vehicles.dart' hide parseVehicles, VehiclesFile;
export 'src/pack/load/content_hash.dart';
export 'src/pack/load/pack_issue.dart';
export 'src/pack/load/pack_loader.dart';
export 'src/pack/load/pending.dart';
export 'src/events/events.dart';
export 'src/expr/evaluate.dart';
export 'src/expr/expr.dart';
export 'src/expr/expr_json.dart';
export 'src/expr/vars.dart';
export 'src/ids.dart';
export 'src/immutable_map.dart';
export 'src/pack/rules_pack.dart';
export 'src/narrator/narrator.dart';
export 'src/read_models/derived_stats.dart';
export 'src/rng.dart';
export 'src/state/component_stores.dart';
export 'src/state/operation_state.dart';
export 'src/state/pending_state.dart';
export 'src/version.dart';
export 'src/visibility.dart';
