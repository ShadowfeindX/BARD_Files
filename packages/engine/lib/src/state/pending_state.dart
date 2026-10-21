import '../checks/check_types.dart';
import '../ids.dart';
import '../immutable_map.dart';
import '../visibility.dart';

/// An action a player asked to take, waiting for the GM.
final class PendingRequest {
  /// Creates a pending request.
  const PendingRequest({
    required this.entity,
    required this.description,
    this.suggestedSkill,
    required this.visibility,
  });

  /// The entity that wants to act.
  final EntityId entity;

  /// What the player wants to do, in their words.
  final String description;

  /// The pack skill id the player suggests, if any.
  final String? suggestedSkill;

  /// Who saw the request.
  final Visibility visibility;

  @override
  bool operator ==(Object other) =>
      other is PendingRequest &&
      other.entity == entity &&
      other.description == description &&
      other.suggestedSkill == suggestedSkill &&
      other.visibility == visibility;

  @override
  int get hashCode =>
      Object.hash(entity, description, suggestedSkill, visibility);

  @override
  String toString() =>
      'PendingRequest(${entity.value}, "$description", $suggestedSkill)';
}

/// A required check that has not resolved yet.
final class PendingCheck {
  /// Creates a pending check.
  const PendingCheck(this.spec, this.visibility);

  /// What the GM asked for.
  final CheckSpec spec;

  /// Who sees the check and its result.
  final Visibility visibility;

  @override
  bool operator ==(Object other) =>
      other is PendingCheck &&
      other.spec == spec &&
      other.visibility == visibility;

  @override
  int get hashCode => Object.hash(spec, visibility);

  @override
  String toString() => 'PendingCheck($spec, $visibility)';
}

/// Open action requests and checks awaiting the GM (01 §State `pending`).
final class PendingState {
  /// Nothing pending.
  const PendingState.empty()
    : requests = const ImmutableMap.empty(),
      checks = const ImmutableMap.empty();

  /// Creates a pending state from its parts.
  const PendingState({required this.requests, required this.checks});

  /// Open action requests by id.
  final ImmutableMap<RequestId, PendingRequest> requests;

  /// Required checks not yet resolved, by id.
  final ImmutableMap<CheckId, PendingCheck> checks;

  /// Returns a copy with the given parts replaced.
  PendingState copyWith({
    ImmutableMap<RequestId, PendingRequest>? requests,
    ImmutableMap<CheckId, PendingCheck>? checks,
  }) => PendingState(
    requests: requests ?? this.requests,
    checks: checks ?? this.checks,
  );

  @override
  bool operator ==(Object other) =>
      other is PendingState &&
      other.requests == requests &&
      other.checks == checks;

  @override
  int get hashCode => Object.hash(requests, checks);

  @override
  String toString() =>
      'PendingState(requests: ${requests.asMap()}, checks: ${checks.asMap()})';
}
