import 'dart:io';

/// The app source folders the check reads, relative to the repository root.
const uiFolders = ['apps/bard/lib/ui'];

final _directive = RegExp(r'''^\s*(import|export)\s+['"]([^'"]+)['"]''');

/// Every Dart file under [uiFolders], relative to [root], sorted.
///
/// Throws a [StateError] when a folder is missing, so a run outside the
/// repository root fails clearly instead of passing.
List<String> uiLayeringFiles(String root) {
  final files = <String>[];
  for (final folder in uiFolders) {
    final dir = Directory('$root/$folder');
    if (!dir.existsSync()) {
      throw StateError('$root/$folder not found; run from the repository root');
    }
    for (final entry in dir.listSync(recursive: true)) {
      if (entry is File && entry.path.endsWith('.dart')) {
        files.add(entry.path.substring(root.length + 1).replaceAll(r'\', '/'));
      }
    }
  }
  return files..sort();
}

/// Returns one `path:line: uri` finding for each `data/services` import or
/// export in [text], unless [path] is a view model.
///
/// Views and panels under `lib/ui` show state and pass on intents; they
/// read the episode through their view model, and shared types through
/// `data/models.dart`. Only a `*_view_model.dart` may call a service.
List<String> checkUiLayering(String path, String text) {
  if (path.endsWith('_view_model.dart')) return const [];
  final findings = <String>[];
  final lines = text.split('\n');
  for (var i = 0; i < lines.length; i++) {
    final match = _directive.firstMatch(lines[i]);
    if (match != null && match[2]!.contains('data/services/')) {
      findings.add('$path:${i + 1}: ${match[2]}');
    }
  }
  return findings;
}
