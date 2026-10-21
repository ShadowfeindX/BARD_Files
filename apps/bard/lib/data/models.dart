import 'package:ui_kit/ui_kit.dart';

/// Display data for one agent, as the service reports it. Vitals are read
/// models supplied by the service; nothing here is computed in the UI.
class AgentSheet {
  /// Creates a sheet.
  const AgentSheet({
    required this.id,
    required this.name,
    required this.attributes,
    required this.health,
    required this.sanity,
  });

  /// Stable id used in commands.
  final String id;

  /// Alias name shown in panels.
  final String name;

  /// Attribute key to score, in display order.
  final Map<String, int> attributes;

  /// Current Health, from the read model.
  final int health;

  /// Current Sanity, from the read model.
  final int sanity;
}

/// Where an action request stands.
enum RequestStatus {
  /// Waiting for the GM.
  pending,

  /// A check was required and resolved.
  resolved,

  /// The GM declined it.
  declined,
}

/// A player's request to act, as shown in the GM queue.
class ActionRequestItem {
  /// Creates a request item.
  const ActionRequestItem({
    required this.id,
    required this.agentId,
    required this.agentName,
    required this.description,
    required this.status,
  });

  /// Request id used in commands.
  final String id;

  /// Requesting agent's id.
  final String agentId;

  /// Requesting agent's name.
  final String agentName;

  /// What the player wants to do.
  final String description;

  /// Current status.
  final RequestStatus status;
}

/// A consequence held for GM review before the player sees it (F2).
class ReviewItem {
  /// Creates a review item.
  const ReviewItem({
    required this.id,
    required this.agentName,
    required this.label,
    required this.amount,
    this.originalAmount,
  });

  /// Review id used in commands.
  final String id;

  /// Affected agent's name.
  final String agentName;

  /// What the consequence is, for example `Sanity loss`.
  final String label;

  /// Current (possibly edited) amount.
  final int amount;

  /// The amount first proposed, when the GM edited it.
  final int? originalAmount;
}

/// A line in a perspective log.
sealed class LogEntry {
  const LogEntry();
}

/// Narrated text.
class TextEntry extends LogEntry {
  /// Creates a text line. [gmNote] marks private GM notes for styling.
  const TextEntry(this.text, {this.gmNote = false});

  /// The line.
  final String text;

  /// Whether this is a private GM note.
  final bool gmNote;
}

/// A resolved check shown with its dice breakdown.
class RollEntry extends LogEntry {
  /// Creates a roll line.
  const RollEntry(this.data);

  /// Display data for the breakdown widget.
  final DiceBreakdownData data;
}

/// A skill the GM can require a check for.
class SkillOption {
  /// Creates a skill option.
  const SkillOption({
    required this.id,
    required this.name,
    required this.attribute,
  });

  /// Skill id.
  final String id;

  /// Display name.
  final String name;

  /// Attribute key the check uses.
  final String attribute;
}

/// A DC category the GM can pick.
class DifficultyOption {
  /// Creates a difficulty option.
  const DifficultyOption({
    required this.key,
    required this.name,
    required this.dc,
  });

  /// Category key.
  final String key;

  /// Display name, for example `Cat-C`.
  final String name;

  /// Target number for the category.
  final int dc;
}
