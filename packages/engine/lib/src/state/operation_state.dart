import '../pack/rules_pack.dart';
import 'component_stores.dart';
import 'pending_state.dart';

/// Per-operation GM settings, stored in operation meta.
final class OperationSettings {
  /// Creates settings. Defaults: engine updates automatic and pack updates
  /// manual (02 §Operations pin packs); auto-resolve and auto-confirm off
  /// (Proposed defaults).
  const OperationSettings({
    this.autoResolveChecks = false,
    this.autoConfirmConsequences = false,
    this.autoApplyEngineUpdates = true,
    this.autoApplyPackUpdates = false,
  });

  /// `RequireCheck` rolls at once instead of waiting for the GM to resolve
  /// (01 §Commands and events).
  final bool autoResolveChecks;

  /// Held consequence batches are confirmed without waiting for the GM
  /// (F2 review gate, applied by the session).
  final bool autoConfirmConsequences;

  /// Engine updates within a major apply automatically.
  final bool autoApplyEngineUpdates;

  /// Pack updates apply without the GM choosing when.
  final bool autoApplyPackUpdates;

  @override
  bool operator ==(Object other) =>
      other is OperationSettings &&
      other.autoResolveChecks == autoResolveChecks &&
      other.autoConfirmConsequences == autoConfirmConsequences &&
      other.autoApplyEngineUpdates == autoApplyEngineUpdates &&
      other.autoApplyPackUpdates == autoApplyPackUpdates;

  @override
  int get hashCode => Object.hash(
    autoResolveChecks,
    autoConfirmConsequences,
    autoApplyEngineUpdates,
    autoApplyPackUpdates,
  );

  @override
  String toString() =>
      'OperationSettings(autoResolve: $autoResolveChecks, '
      'autoConfirm: $autoConfirmConsequences, '
      'engineUpdates: $autoApplyEngineUpdates, '
      'packUpdates: $autoApplyPackUpdates)';
}

/// Who the operation is and what it runs on.
final class OperationMeta {
  /// Creates operation meta.
  const OperationMeta({
    required this.operationId,
    required this.engineVersion,
    required this.packRef,
    required this.settings,
  });

  /// The operation's id, chosen outside the engine.
  final String operationId;

  /// Engine version that started the operation.
  final String engineVersion;

  /// The pinned pack.
  final PackRef packRef;

  /// GM settings.
  final OperationSettings settings;

  @override
  bool operator ==(Object other) =>
      other is OperationMeta &&
      other.operationId == operationId &&
      other.engineVersion == engineVersion &&
      other.packRef == packRef &&
      other.settings == settings;

  @override
  int get hashCode =>
      Object.hash(operationId, engineVersion, packRef, settings);

  @override
  String toString() =>
      'OperationMeta($operationId, engine $engineVersion, $packRef, $settings)';
}

/// How far the operation's RNG has been drawn.
///
/// Rolling events record the draw range they used; folding them advances
/// [drawCount]. The seed itself is GM-only and is held by the session's RNG
/// adapter, never in state that is broadcast (01 §RNG).
final class RngState {
  /// Creates an RNG state.
  const RngState({this.drawCount = 0});

  /// Draws consumed by every rolling event so far.
  final int drawCount;

  @override
  bool operator ==(Object other) =>
      other is RngState && other.drawCount == drawCount;

  @override
  int get hashCode => drawCount.hashCode;

  @override
  String toString() => 'RngState(drawCount: $drawCount)';
}

/// The whole state of one operation: a fold of its events (01 §State).
///
/// Immutable. The encounter part listed in 01 §State is added with the
/// combat system.
final class OperationState {
  /// The state before any event: not started, no entities.
  const OperationState.initial()
    : meta = null,
      stores = const ComponentStores.empty(),
      pending = const PendingState.empty(),
      rng = const RngState();

  /// Creates a state from its parts.
  const OperationState({
    required this.meta,
    required this.stores,
    this.pending = const PendingState.empty(),
    required this.rng,
  });

  /// Operation meta, or `null` before `OperationStarted`.
  final OperationMeta? meta;

  /// ECS stores.
  final ComponentStores stores;

  /// Open action requests and checks.
  final PendingState pending;

  /// RNG draw position.
  final RngState rng;

  /// Whether `OperationStarted` has been applied.
  bool get started => meta != null;

  /// Returns a copy with the given parts replaced.
  OperationState copyWith({
    OperationMeta? meta,
    ComponentStores? stores,
    PendingState? pending,
    RngState? rng,
  }) => OperationState(
    meta: meta ?? this.meta,
    stores: stores ?? this.stores,
    pending: pending ?? this.pending,
    rng: rng ?? this.rng,
  );

  @override
  bool operator ==(Object other) =>
      other is OperationState &&
      other.meta == meta &&
      other.stores == stores &&
      other.pending == pending &&
      other.rng == rng;

  @override
  int get hashCode => Object.hash(meta, stores, pending, rng);

  @override
  String toString() => 'OperationState($meta, $stores, $pending, $rng)';
}
