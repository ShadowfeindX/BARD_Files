import 'dart:io';

import 'package:yaml/yaml.dart';

/// How a dependency is declared in a pubspec.
enum DependencyKind {
  /// A hosted package with a version constraint (`name: 1.2.3`).
  hosted,

  /// A Dart or Flutter SDK dependency (`sdk: flutter`).
  sdk,

  /// A git, path or other non-hosted source.
  other,
}

/// One dependency entry of a pubspec.
class Dependency {
  /// Creates a dependency entry.
  const Dependency(this.name, this.kind, {this.constraint = ''});

  /// Package name.
  final String name;

  /// Declaration style.
  final DependencyKind kind;

  /// Version constraint text for hosted dependencies, empty otherwise.
  final String constraint;
}

/// A workspace member as read from its `pubspec.yaml`.
class Member {
  /// Creates a member.
  const Member({
    required this.name,
    required this.dir,
    required this.dependencies,
    required this.devDependencies,
  });

  /// Package name from the pubspec.
  final String name;

  /// Directory relative to the repository root, with forward slashes.
  final String dir;

  /// Entries under `dependencies`.
  final List<Dependency> dependencies;

  /// Entries under `dev_dependencies`.
  final List<Dependency> devDependencies;
}

/// Reads the members listed under `workspace:` in the root pubspec.
List<Member> readWorkspace(String root) {
  final rootDoc = loadYaml(File('$root/pubspec.yaml').readAsStringSync());
  final dirs = [for (final d in rootDoc['workspace'] as YamlList) '$d'];
  return [for (final dir in dirs) readMember(root, dir)];
}

/// Reads one member's pubspec.
Member readMember(String root, String dir) {
  final doc = loadYaml(File('$root/$dir/pubspec.yaml').readAsStringSync());
  return Member(
    name: doc['name'] as String,
    dir: dir,
    dependencies: _readSection(doc['dependencies']),
    devDependencies: _readSection(doc['dev_dependencies']),
  );
}

List<Dependency> _readSection(Object? section) {
  if (section is! YamlMap) return const [];
  return [
    for (final entry in section.entries)
      _readDependency('${entry.key}', entry.value),
  ];
}

Dependency _readDependency(String name, Object? value) {
  if (value is String) {
    return Dependency(name, DependencyKind.hosted, constraint: value);
  }
  if (value is YamlMap && value.containsKey('sdk')) {
    return Dependency(name, DependencyKind.sdk);
  }
  if (value is YamlMap && value.containsKey('hosted')) {
    return Dependency(
      name,
      DependencyKind.hosted,
      constraint: '${value['version'] ?? 'any'}',
    );
  }
  return Dependency(name, DependencyKind.other);
}

/// Finds every `pubspec.yaml` under [root] outside generated or ignored
/// folders, as directories relative to [root].
List<String> findPubspecDirs(String root) {
  const skip = {'.dart_tool', 'build', '.git', 'ephemeral', 'node_modules'};
  final found = <String>[];
  for (final entity in Directory(root).listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('pubspec.yaml')) continue;
    final relative = entity.path
        .substring(root.length + 1)
        .replaceAll(r'\', '/');
    final parts = relative.split('/');
    if (parts.any(skip.contains)) continue;
    final dir = parts.take(parts.length - 1).join('/');
    found.add(dir.isEmpty ? '.' : dir);
  }
  return found..sort();
}
