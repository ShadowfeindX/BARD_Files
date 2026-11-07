import 'dart:io';

/// The app source folders the check reads, relative to the repository root.
const uiFolders = ['apps/bard/lib/ui'];

/// The folders a view or panel may not reach, relative to `apps/bard/lib`:
/// the services, and the composition root that holds them.
const forbiddenFolders = ['data/services/', 'app/'];

// An import, export or part directive up to its semicolon. Comments are
// blanked first, so a directive inside one is not read.
final _directive = RegExp(r'\b(import|export|part)\b([^;]*);');
final _uri = RegExp(r'''['"]([^'"]+)['"]''');
final _comment = RegExp(r'//[^\n]*|/\*[\s\S]*?\*/');

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

/// Returns one `path:line: uri` finding for each directive in [text] that
/// reaches a [forbiddenFolders] folder, unless [path] is a view model.
///
/// Views and panels under `lib/ui` show state and pass on intents; they
/// read the episode through their view model, and shared types through
/// `data/models.dart`. Only a file named `*_view_model.dart` may call a
/// service. Every URI of a directive is read (conditional imports too), and
/// relative URIs are resolved against [path] first, so `./` and `../`
/// segments do not hide a target.
List<String> checkUiLayering(String path, String text) {
  if (path.endsWith('_view_model.dart')) return const [];
  final code = text.replaceAllMapped(
    _comment,
    (m) => m[0]!.replaceAll(RegExp(r'[^\n]'), ' '),
  );
  final findings = <String>[];
  for (final directive in _directive.allMatches(code)) {
    for (final uri in _uri.allMatches(directive[2]!)) {
      final target = uri[1]!;
      if (_isForbidden(path, target)) {
        // The URI's offset in group 2, which starts right after the keyword.
        final offset = directive.start + directive[1]!.length + uri.start;
        final line = '\n'.allMatches(code.substring(0, offset)).length + 1;
        findings.add('$path:$line: $target');
      }
    }
  }
  return findings;
}

bool _isForbidden(String path, String uri) {
  final String? inLib;
  if (uri.startsWith('package:bard/')) {
    inLib = _normalize(uri.substring('package:bard/'.length));
  } else if (uri.contains(':')) {
    inLib = null;
  } else {
    final dir = path.substring(0, path.lastIndexOf('/') + 1);
    final resolved = _normalize('$dir$uri');
    const lib = 'apps/bard/lib/';
    inLib = resolved.startsWith(lib) ? resolved.substring(lib.length) : null;
  }
  return inLib != null && forbiddenFolders.any(inLib.startsWith);
}

/// Resolves `.` and `..` segments of a `/`-separated path.
String _normalize(String path) {
  final out = <String>[];
  for (final segment in path.split('/')) {
    if (segment == '.' || segment.isEmpty) continue;
    if (segment == '..') {
      if (out.isNotEmpty) out.removeLast();
    } else {
      out.add(segment);
    }
  }
  return out.join('/');
}
