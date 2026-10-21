import 'package:engine/engine.dart';
import 'package:test/test.dart';

void main() {
  group('ImmutableMap', () {
    test('put and remove return new maps and leave the original', () {
      final a = ImmutableMap.of({'x': 1});
      final b = a.put('y', 2);
      final c = b.remove('x');
      expect(a.asMap(), {'x': 1});
      expect(b.asMap(), {'x': 1, 'y': 2});
      expect(c.asMap(), {'y': 2});
      expect(identical(a.remove('missing'), a), isTrue);
    });

    test('value equality ignores insertion order', () {
      expect(
        ImmutableMap.of({'a': 1, 'b': 2}),
        ImmutableMap.of({'b': 2, 'a': 1}),
      );
      expect(
        ImmutableMap.of({'a': 1, 'b': 2}).hashCode,
        ImmutableMap.of({'b': 2, 'a': 1}).hashCode,
      );
      expect(ImmutableMap.of({'a': 1}), isNot(ImmutableMap.of({'a': 2})));
    });

    test('its map view cannot be changed', () {
      expect(
        () => ImmutableMap.of({'a': 1}).asMap()['b'] = 2,
        throwsUnsupportedError,
      );
    });
  });

  group('ComponentStores', () {
    const e1 = EntityId('e1');
    const e2 = EntityId('e2');
    final identity = const Identity(name: 'Hall', kind: EntityKind.agent);
    final attrs = Attributes({'STR': 2});

    test('typed get, has and all', () {
      final stores = const ComponentStores.empty()
          .put(e1, identity)
          .put(e1, attrs)
          .put(e2, attrs);
      expect(stores.get(Identity.componentType, e1), identity);
      expect(stores.get(Attributes.componentType, e2), attrs);
      expect(stores.get(Identity.componentType, e2), isNull);
      expect(stores.has(Attributes.componentType, e1), isTrue);
      expect(stores.all(Attributes.componentType).keys, [e1, e2]);
      expect(stores.entities, {e1, e2});
    });

    test('put replaces a component of the same type', () {
      final stores = const ComponentStores.empty()
          .put(e1, attrs)
          .put(e1, Attributes({'STR': 3}));
      expect(stores.get(Attributes.componentType, e1)!['STR'], 3);
    });

    test('removing everything compares equal to empty', () {
      final stores = const ComponentStores.empty()
          .put(e1, identity)
          .put(e1, attrs);
      expect(stores.removeEntity(e1), const ComponentStores.empty());
      expect(
        stores
            .remove(Identity.componentType, e1)
            .remove(Attributes.componentType, e1),
        const ComponentStores.empty(),
      );
    });

    test('changes never touch the original', () {
      final before = const ComponentStores.empty().put(e1, identity);
      before.put(e2, attrs).removeEntity(e1);
      expect(before.get(Identity.componentType, e1), identity);
      expect(before.entities, {e1});
    });
  });

  test('component type keys are unique and registered', () {
    expect(componentTypes.keys, ['identity', 'attributes', 'skills']);
    for (final entry in componentTypes.entries) {
      expect(entry.value.typeKey, entry.key);
    }
  });

  test('Visibility', () {
    const a = AliasId('a');
    const b = AliasId('b');
    expect(const Public().visibleTo(a), isTrue);
    expect(const GmOnly().visibleTo(a), isFalse);
    expect(AliasesOnly({a}).visibleTo(a), isTrue);
    expect(AliasesOnly({a}).visibleTo(b), isFalse);
    expect(AliasesOnly({a, b}), AliasesOnly({b, a}));
    expect(() => AliasesOnly({}), throwsArgumentError);
  });
}
