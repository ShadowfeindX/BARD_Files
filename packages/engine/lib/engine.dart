/// The B.A.R.D. Files game engine: pure Dart, Dart SDK only.
///
/// Turns commands into events (`Engine.decide`) and events into state
/// (`Engine.evolve`). See `docs/architecture/01-engine.md`.
library;

export 'src/actor.dart';
export 'src/commands/commands.dart';
export 'src/components/components.dart';
export 'src/decision.dart';
export 'src/engine.dart';
export 'src/events/events.dart';
export 'src/expr/evaluate.dart';
export 'src/expr/expr.dart';
export 'src/expr/expr_json.dart';
export 'src/expr/vars.dart';
export 'src/ids.dart';
export 'src/immutable_map.dart';
export 'src/pack/rules_pack.dart';
export 'src/rng.dart';
export 'src/state/component_stores.dart';
export 'src/state/operation_state.dart';
export 'src/version.dart';
export 'src/visibility.dart';
