import 'dart:convert';
import 'dart:io';

import 'package:bard_tool/dependency_rules.dart';
import 'package:bard_tool/workspace.dart';

/// Checks the layering in `docs/architecture/00-overview.md#dependency-rules`.
///
/// Run from the repository root after `flutter pub get`:
/// `dart run tool/bin/check_dependency_rules.dart`.
Future<void> main() async {
  final members = readWorkspace('.');
  final problems = [
    ...checkLayerRules(members),
    ...checkUnlistedPubspecs(findPubspecDirs('.'), members),
    ...await _functionsGraphProblems(),
  ];
  if (problems.isEmpty) {
    stdout.writeln('Dependency rules: ${members.length} members OK');
    return;
  }
  problems.forEach(stderr.writeln);
  exitCode = 1;
}

/// Resolved-graph check: `apps/functions` must not reach the engine.
Future<List<String>> _functionsGraphProblems() async {
  final result = await Process.run('dart', [
    'pub',
    'deps',
    '--json',
  ], workingDirectory: 'apps/functions');
  if (result.exitCode != 0) {
    return ['apps/functions: dart pub deps failed: ${result.stderr}'];
  }
  final graph = jsonDecode(result.stdout as String) as Map<String, dynamic>;
  final edges = <String, List<String>>{};
  for (final entry in graph['packages'] as List<dynamic>) {
    final package = entry as Map<String, dynamic>;
    edges[package['name'] as String] = [
      for (final d in package['dependencies'] as List<dynamic>) '$d',
    ];
  }
  return checkFunctionsGraph(edges);
}
