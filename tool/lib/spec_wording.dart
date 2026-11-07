import 'dart:io';

/// One wording pattern that must not appear in the spec chapters.
class WordingRule {
  /// Creates a rule.
  const WordingRule(this.name, this.pattern);

  /// Short name printed with each finding.
  final String name;

  /// The text that breaks the rule.
  final String pattern;
}

/// Decision and provenance wording that chapters 00 to 08, the developer
/// guide and `docs/ui-kit.md` must not contain.
///
/// These pages describe how the application works. Rulings, with their
/// dates, owners and reasons, live only in
/// `docs/architecture/decision-record.md`, and open items in 09 and 10,
/// which this check does not read. The patterns catch the common forms
/// only; review still reads for the rest.
const wordingRules = [
  WordingRule(
    'decision attribution',
    r'\b(R|D|R and D),? ([Rr]uled|[Aa]greed|[Aa]pproved|[Dd]ecided|[Ss]ettled|[Cc]onfirmed|[Cc]hose)\b',
  ),
  WordingRule(
    'decision attribution',
    r'\b([Rr]uled|[Aa]greed|[Aa]pproved|[Dd]ecided|[Ss]ettled|[Cc]onfirmed|[Cc]hosen),? by (R|D|R and D)\b',
  ),
  WordingRule('decision attribution', r'\((R|D|R and D)\)'),
  WordingRule('dated decision', r'\b(R|D|R and D), 20\d\d-\d\d-\d\d'),
  WordingRule(
    'dated decision',
    r'\b([Rr]uled|[Aa]greed|[Aa]pproved|[Ss]ettled|[Dd]ecided|[Cc]onfirmed) on 20\d\d-\d\d-\d\d',
  ),
  WordingRule('ruling reference', r"\b(R|D)'s (ruling|decision|answer)"),
  WordingRule(
    'status label',
    r'\((Fixed|Ruled|Settled|Approved)\)|\*\*(Fixed|Ruled|Settled|Approved)\.?\*\*',
  ),
  WordingRule(
    'decision history',
    r'\b(earlier|previous|original) (proposal|ruling|decision)s?\b',
  ),
  WordingRule(
    'review narrative',
    r'\b[Gg]ate review\b|\b[Tt]he review (found|recommends)\b',
  ),
];

final _compiledRules = [
  for (final rule in wordingRules) (rule.name, RegExp(rule.pattern)),
];

/// The files the check reads, relative to [root], sorted.
///
/// Throws a [StateError] when [root] has no `docs/architecture` or
/// `docs/developer-guide` folder, so a run outside the repository root
/// fails clearly instead of passing.
List<String> specWordingFiles(String root) {
  for (final dir in ['docs/architecture', 'docs/developer-guide']) {
    if (!Directory('$root/$dir').existsSync()) {
      throw StateError('$root/$dir not found; run from the repository root');
    }
  }
  final files = <String>[];
  final chapter = RegExp(r'^0[0-8]-.*\.md$');
  for (final entry in Directory('$root/docs/architecture').listSync()) {
    final name = entry.uri.pathSegments.last;
    if (entry is File && chapter.hasMatch(name)) {
      files.add('docs/architecture/$name');
    }
  }
  for (final entry in Directory('$root/docs/developer-guide').listSync()) {
    final name = entry.uri.pathSegments.last;
    if (entry is File && name.endsWith('.md')) {
      files.add('docs/developer-guide/$name');
    }
  }
  if (File('$root/docs/ui-kit.md').existsSync()) files.add('docs/ui-kit.md');
  return files..sort();
}

/// Returns one `path:line: rule: text` finding per line of [text] that
/// matches a rule. Fenced code blocks (opened with three backticks) are
/// skipped, since examples there are data, not prose. A fence left open at
/// the end of the file is reported, because it would hide everything after
/// it.
List<String> checkSpecWording(String path, String text) {
  final findings = <String>[];
  var inFence = false;
  final lines = text.split('\n');
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    if (line.trimLeft().startsWith('```')) {
      inFence = !inFence;
      continue;
    }
    if (inFence) continue;
    for (final (name, pattern) in _compiledRules) {
      final match = pattern.firstMatch(line);
      if (match != null) {
        findings.add('$path:${i + 1}: $name: "${match[0]}"');
      }
    }
  }
  if (inFence) findings.add('$path:${lines.length}: unclosed code fence');
  return findings;
}
