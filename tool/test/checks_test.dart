import 'package:bard_tool/dependency_rules.dart';
import 'package:bard_tool/pin_check.dart';
import 'package:bard_tool/workspace.dart';
import 'package:test/test.dart';

Member member(
  String dir, {
  List<Dependency> deps = const [],
  List<Dependency> dev = const [],
}) => Member(
  name: dir.split('/').last,
  dir: dir,
  dependencies: deps,
  devDependencies: dev,
);

Dependency hosted(String name, [String constraint = '1.0.0']) =>
    Dependency(name, DependencyKind.hosted, constraint: constraint);

void main() {
  group('layer rules', () {
    test('an allowed dependency passes', () {
      final m = member('packages/session', deps: [hosted('engine', 'any')]);
      expect(checkLayerRules([m]), isEmpty);
    });

    test('the engine may not import the protocol', () {
      final m = member('packages/engine', deps: [hosted('protocol', 'any')]);
      expect(checkLayerRules([m]), hasLength(1));
    });

    test('migrator may use the engine only in dev_dependencies', () {
      final dev = member('packages/migrator', dev: [hosted('engine', 'any')]);
      final prod = member('packages/migrator', deps: [hosted('engine', 'any')]);
      expect(checkLayerRules([dev]), isEmpty);
      expect(checkLayerRules([prod]), hasLength(1));
    });

    test('a pure layer may not depend on the Flutter SDK', () {
      final m = member(
        'packages/engine',
        deps: [const Dependency('flutter', DependencyKind.sdk)],
      );
      expect(checkLayerRules([m]), hasLength(1));
    });

    test('tooling is allowed in dev_dependencies only', () {
      final dev = member('packages/engine', dev: [hosted('test')]);
      final prod = member('packages/engine', deps: [hosted('test')]);
      expect(checkLayerRules([dev]), isEmpty);
      expect(checkLayerRules([prod]), hasLength(1));
    });

    test('a member without a rule is reported', () {
      expect(checkLayerRules([member('packages/new_thing')]), hasLength(1));
    });

    test('functions may not reach the engine or protocol transitively', () {
      final bad = {
        'functions': ['protocol_envelope', 'session'],
        'session': ['engine'],
        'engine': <String>[],
      };
      final good = {
        'functions': ['protocol_envelope'],
        'protocol': ['engine'], // in the workspace, but not reachable
      };
      expect(checkFunctionsGraph(bad), hasLength(1));
      expect(checkFunctionsGraph(good), isEmpty);
    });

    test('pubspecs outside the workspace list are reported', () {
      final listed = [member('packages/engine')];
      expect(
        checkUnlistedPubspecs(['.', 'packages/engine', 'packages/x'], listed),
        hasLength(1),
      );
    });
  });

  group('exact pins', () {
    test('exact versions and workspace members pass', () {
      final a = member('packages/engine');
      final b = member(
        'packages/session',
        deps: [hosted('engine', 'any'), hosted('xrandom', '0.7.2')],
      );
      expect(checkExactPins([a, b]), isEmpty);
    });

    test('caret, range and any on external packages fail', () {
      final m = member(
        'apps/bard',
        deps: [
          hosted('go_router', '^18.1.1'),
          hosted('hive', '>=2.0.0 <3.0.0'),
        ],
        dev: [hosted('test', 'any')],
      );
      expect(checkExactPins([m]), hasLength(3));
    });

    test('git and path sources fail', () {
      final m = member(
        'packages/session',
        deps: [const Dependency('xrandom', DependencyKind.other)],
      );
      expect(checkExactPins([m]), hasLength(1));
    });

    test('SDK dependencies are skipped', () {
      final m = member(
        'apps/bard',
        deps: [const Dependency('flutter', DependencyKind.sdk)],
      );
      expect(checkExactPins([m]), isEmpty);
    });
  });
}
