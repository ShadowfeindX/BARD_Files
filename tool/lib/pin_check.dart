import 'workspace.dart';

final _exact = RegExp(r'^\d+\.\d+\.\d+(\+[0-9A-Za-z.\-]+)?$');

/// Fails every hosted dependency that is not an exact version (F5).
///
/// Workspace members refer to each other as `any` and are skipped, as are SDK
/// dependencies.
List<String> checkExactPins(List<Member> members) {
  final internal = {for (final m in members) m.name};
  final problems = <String>[];
  for (final member in members) {
    for (final dep in [...member.dependencies, ...member.devDependencies]) {
      if (dep.kind != DependencyKind.hosted) continue;
      if (internal.contains(dep.name)) continue;
      if (!_exact.hasMatch(dep.constraint)) {
        problems.add(
          '${member.dir}: "${dep.name}: ${dep.constraint}" is not an exact '
          'version',
        );
      }
    }
  }
  return problems;
}
