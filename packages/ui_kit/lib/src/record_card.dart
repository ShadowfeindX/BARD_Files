import 'package:flutter/material.dart';

import 'theme/bard_tokens.dart';

/// One label/value row of a [RecordCard] table.
class RecordRow {
  /// Creates a row.
  const RecordRow(this.label, this.value, {this.valueKey});

  /// Left cell.
  final String label;

  /// Right cell.
  final String value;

  /// Key of the value text, for tests and automation.
  final Key? valueKey;
}

/// A titled label/value table of a [RecordCard].
class RecordSection {
  /// Creates a section. [tags] are shown as text tags under the rows.
  const RecordSection({
    required this.label,
    this.rows = const [],
    this.tags = const [],
    this.emptyText,
  });

  /// Table heading.
  final String label;

  /// Label/value rows.
  final List<RecordRow> rows;

  /// Text tags, for example condition names.
  final List<String> tags;

  /// Shown when there are no rows and no tags.
  final String? emptyText;
}

/// A record card (synthesis 3.3): a header and label/value tables whose label
/// cells use the `labelCell` token. The app supplies every word; the card
/// invents none.
class RecordCard extends StatelessWidget {
  /// Creates a card.
  const RecordCard({
    super.key,
    required this.title,
    this.recordLine,
    required this.sections,
  });

  /// Name in the header.
  final String title;

  /// Optional line under the name.
  final String? recordLine;

  /// Tables, in order.
  final List<RecordSection> sections;

  @override
  Widget build(BuildContext context) {
    final tokens = BardTokens.of(context);
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.all(4),
      child: Material(
        color: tokens.window,
        shape: Border.all(color: tokens.windowEdge),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              color: tokens.windowRaised,
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: text.titleMedium),
                  if (recordLine != null)
                    Text(
                      recordLine!,
                      style: text.bodySmall?.copyWith(color: tokens.inkMuted),
                    ),
                ],
              ),
            ),
            for (final section in sections) _Section(section: section),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.section});

  final RecordSection section;

  @override
  Widget build(BuildContext context) {
    final tokens = BardTokens.of(context);
    final text = Theme.of(context).textTheme;
    final empty = section.rows.isEmpty && section.tags.isEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Divider(height: 1, color: tokens.rule),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: Text(
            section.label.toUpperCase(),
            style: text.labelMedium?.copyWith(color: tokens.inkMuted),
          ),
        ),
        for (final row in section.rows)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 120,
                  color: tokens.labelCell,
                  padding: const EdgeInsets.all(6),
                  child: Text(row.label),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Text(row.value, key: row.valueKey),
                  ),
                ),
              ],
            ),
          ),
        if (section.tags.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final tag in section.tags)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: tokens.labelCell,
                      border: Border.all(color: tokens.rule),
                    ),
                    child: Text(tag),
                  ),
              ],
            ),
          ),
        if (empty && section.emptyText != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Text(
              section.emptyText!,
              style: text.bodyMedium?.copyWith(color: tokens.inkMuted),
            ),
          ),
      ],
    );
  }
}
