import 'package:flutter/material.dart';

import 'theme.dart';

/// How a resolved check ended, as shown by [DiceBreakdownView].
///
/// This mirrors the outcome the engine reports; the widget only displays it
/// and never decides one (07 §The app shell never affects outcomes).
enum CheckOutcomeKind {
  /// Total met or beat the DC.
  success,

  /// Partial success band, as defined by the pack.
  partial,

  /// Total fell short.
  failure,
}

/// One die in a roll chain.
class DieResult {
  /// Creates a die result. [exploded] marks a die that triggered another roll.
  const DieResult(this.value, {this.exploded = false});

  /// The face that came up.
  final int value;

  /// Whether this die exploded and added the next die in the chain.
  final bool exploded;
}

/// A named group of dice, for example the primary d6 chain or the proficiency
/// dice.
class DiceGroup {
  /// Creates a group of dice with a display [label].
  const DiceGroup({required this.label, required this.dice, this.subtotal});

  /// Name shown beside the dice, for example `Primary d6`.
  final String label;

  /// Dice in roll order.
  final List<DieResult> dice;

  /// Group total as computed by the engine; omitted from the display if null.
  final int? subtotal;
}

/// A named flat modifier, for example an attribute or a skill bonus.
class ModifierLine {
  /// Creates a modifier line.
  const ModifierLine(this.label, this.value);

  /// Name shown beside the value.
  final String label;

  /// Signed amount added to the total.
  final int value;
}

/// Plain display data for a resolved check. Built from the engine's
/// `CheckResolved` event by the app; `ui_kit` never imports the engine.
class DiceBreakdownData {
  /// Creates breakdown data. All numbers are supplied by the engine.
  const DiceBreakdownData({
    required this.title,
    required this.groups,
    required this.modifiers,
    required this.total,
    required this.outcome,
    this.dc,
    this.dcLabel,
  });

  /// Heading, for example the skill name.
  final String title;

  /// Dice groups in display order.
  final List<DiceGroup> groups;

  /// Flat modifiers in display order.
  final List<ModifierLine> modifiers;

  /// Final total, computed by the engine.
  final int total;

  /// Target number, when the check has one.
  final int? dc;

  /// DC category name, for example `Cat-F`, when known.
  final String? dcLabel;

  /// How the check ended.
  final CheckOutcomeKind outcome;
}

/// Shows how a check was rolled: dice chains, modifiers, total against DC and
/// the outcome.
class DiceBreakdownView extends StatelessWidget {
  /// Creates the breakdown for [data].
  const DiceBreakdownView({super.key, required this.data});

  /// What to display.
  final DiceBreakdownData data;

  /// Localized-free outcome text (strings move to the pack's `strings/` later).
  static String outcomeLabel(CheckOutcomeKind kind) => switch (kind) {
    CheckOutcomeKind.success => 'Success',
    CheckOutcomeKind.partial => 'Partial success',
    CheckOutcomeKind.failure => 'Failure',
  };

  static Color _outcomeColor(CheckOutcomeKind kind) => switch (kind) {
    CheckOutcomeKind.success => BardTheme.success,
    CheckOutcomeKind.partial => BardTheme.partial,
    CheckOutcomeKind.failure => BardTheme.failure,
  };

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final dcText = data.dc == null
        ? null
        : 'DC ${data.dc}${data.dcLabel == null ? '' : ' (${data.dcLabel})'}';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(data.title, style: text.titleMedium),
            const SizedBox(height: 8),
            for (final group in data.groups) _GroupRow(group: group),
            for (final mod in data.modifiers)
              _ValueRow(label: mod.label, value: _signed(mod.value)),
            const Divider(),
            Row(
              children: [
                Text('Total ${data.total}', style: text.titleLarge),
                if (dcText != null) ...[
                  const SizedBox(width: 12),
                  Text('vs $dcText', style: text.bodyLarge),
                ],
                const Spacer(),
                Chip(
                  label: Text(
                    outcomeLabel(data.outcome),
                    style: TextStyle(
                      color:
                          ThemeData.estimateBrightnessForColor(
                                _outcomeColor(data.outcome),
                              ) ==
                              Brightness.dark
                          ? Colors.white
                          : Colors.black,
                    ),
                  ),
                  backgroundColor: _outcomeColor(data.outcome),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _signed(int v) => v >= 0 ? '+$v' : '$v';
}

class _GroupRow extends StatelessWidget {
  const _GroupRow({required this.group});

  final DiceGroup group;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: Text(group.label)),
          Wrap(
            spacing: 4,
            children: [for (final die in group.dice) _DieChip(die: die)],
          ),
          const SizedBox(width: 8),
          if (group.subtotal != null) Text('= ${group.subtotal}'),
        ],
      ),
    );
  }
}

class _DieChip extends StatelessWidget {
  const _DieChip({required this.die});

  final DieResult die;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: die.exploded ? 'die ${die.value}, exploded' : 'die ${die.value}',
      child: ExcludeSemantics(
        child: Container(
          key: ValueKey(die.exploded ? 'die-exploded' : 'die'),
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            color: die.exploded
                ? scheme.tertiaryContainer
                : scheme.secondaryContainer,
            border: Border.all(color: scheme.outline),
          ),
          child: Text(die.exploded ? '${die.value}!' : '${die.value}'),
        ),
      ),
    );
  }
}

class _ValueRow extends StatelessWidget {
  const _ValueRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(value),
        ],
      ),
    );
  }
}
