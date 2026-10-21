import 'workspace.dart';

/// Which packages one workspace layer may import.
///
/// Mirrors the table in `docs/architecture/00-overview.md#dependency-rules`;
/// change both together.
class LayerRule {
  /// Creates a rule.
  const LayerRule({
    this.allowed = const {},
    this.flutterSdk = false,
    this.devOnly = const {},
  });

  /// Packages allowed under `dependencies` (and `dev_dependencies`).
  final Set<String> allowed;

  /// Whether `sdk: flutter` is allowed under `dependencies`.
  final bool flutterSdk;

  /// Extra packages allowed under `dev_dependencies` only.
  final Set<String> devOnly;
}

/// Packages any member may use in `dev_dependencies` (analysis and tests).
const toolingDev = {'flutter_lints', 'test', 'flutter_test'};

const _appPackages = {
  'session',
  'protocol',
  'engine',
  'backend',
  'ui_kit',
  'content_core',
  'signals_flutter',
  'go_router',
  'app_links',
};

/// Rules keyed by member directory.
const layerRules = <String, LayerRule>{
  'apps/bard': LayerRule(allowed: _appPackages, flutterSdk: true),
  'apps/companion': LayerRule(allowed: _appPackages, flutterSdk: true),
  'apps/functions': LayerRule(
    allowed: {'protocol_envelope', 'firebase_functions', 'firebase_admin_sdk'},
  ),
  'packages/ui_kit': LayerRule(allowed: {'signals_flutter'}, flutterSdk: true),
  'packages/backend': LayerRule(
    allowed: {
      'session',
      'protocol',
      'firebase_dart',
      'hive',
      'flutter_secure_storage',
      'firebase_core',
      'cloud_firestore',
      // Decision 3 of the implementation plan (R, 2026-10-21): the sembast
      // EventStore lives in `backend`.
      'sembast',
      'sembast_web',
    },
    flutterSdk: true,
  ),
  'packages/session': LayerRule(allowed: {'protocol', 'engine', 'xrandom'}),
  'packages/protocol': LayerRule(allowed: {'protocol_envelope', 'engine'}),
  'packages/protocol_envelope': LayerRule(),
  'packages/engine': LayerRule(),
  'packages/migrator': LayerRule(devOnly: {'engine'}),
  'packages/content_core': LayerRule(),
  'tool': LayerRule(allowed: {'yaml'}),
};

/// Checks every member against [layerRules]; returns one message per breach.
List<String> checkLayerRules(
  List<Member> members, {
  Map<String, LayerRule> rules = layerRules,
}) {
  final problems = <String>[];
  for (final member in members) {
    final rule = rules[member.dir];
    if (rule == null) {
      problems.add(
        '${member.dir}: no dependency rule defined; add it to '
        'tool/lib/dependency_rules.dart and 00-overview.md',
      );
      continue;
    }
    _checkSection(problems, member, member.dependencies, rule, dev: false);
    _checkSection(problems, member, member.devDependencies, rule, dev: true);
  }
  return problems;
}

void _checkSection(
  List<String> problems,
  Member member,
  List<Dependency> deps,
  LayerRule rule, {
  required bool dev,
}) {
  final section = dev ? 'dev_dependencies' : 'dependencies';
  final allowed = {
    ...rule.allowed,
    if (dev) ...rule.devOnly,
    if (dev) ...toolingDev,
  };
  for (final dep in deps) {
    if (dep.kind == DependencyKind.sdk) {
      final ok = dev || rule.flutterSdk;
      if (!ok) {
        problems.add(
          '${member.dir}: $section lists sdk dependency "${dep.name}" but '
          'this layer is pure Dart',
        );
      }
      continue;
    }
    if (!allowed.contains(dep.name)) {
      problems.add(
        '${member.dir}: $section lists "${dep.name}", which this layer may '
        'not depend on',
      );
    }
  }
}

/// Packages that must never appear in the resolved graph of `apps/functions`
/// (F4: it depends only on `protocol_envelope`).
const forbiddenForFunctions = {'engine', 'protocol'};

/// Returns the forbidden package names reachable from `functions`.
///
/// [graph] maps each package name to its direct dependencies, as printed by
/// `dart pub deps --json`. In a workspace that output lists every member, so
/// the check walks from `functions` instead of scanning all names.
List<String> checkFunctionsGraph(Map<String, List<String>> graph) {
  final reached = <String>{};
  final pending = ['functions'];
  while (pending.isNotEmpty) {
    final name = pending.removeLast();
    if (!reached.add(name)) continue;
    pending.addAll(graph[name] ?? const []);
  }
  return [
    for (final name in forbiddenForFunctions)
      if (reached.contains(name))
        'apps/functions: resolved graph contains "$name" (F4)',
  ];
}

/// Pubspecs deliberately outside the workspace.
///
/// `firebase/rtdb_rules_test` is a standalone emulator check run by
/// `firebase/run_rtdb_rules_test.sh`; it has its own pubspec on purpose.
const standaloneDirs = {'firebase/rtdb_rules_test'};

/// Reports pubspecs under the repository that are not workspace members.
List<String> checkUnlistedPubspecs(
  List<String> pubspecDirs,
  List<Member> members,
) {
  final listed = {for (final m in members) m.dir, '.', ...standaloneDirs};
  return [
    for (final dir in pubspecDirs)
      if (!listed.contains(dir))
        '$dir: pubspec.yaml is not listed under workspace: in the root pubspec',
  ];
}
