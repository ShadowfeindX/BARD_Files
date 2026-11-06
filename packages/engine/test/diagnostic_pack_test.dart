@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';

import 'package:engine/engine.dart';
import 'package:test/test.dart';

import 'support/provisional_pack.dart';

/// The generated diagnostic pack (example and diagnostic content, never part
/// of the final demo): it must load, be labelled PLACEHOLDER everywhere, and
/// add no rule, stat or value beyond the core pack it sits on. Needs
/// `bash tool/build_diagnostic_pack.sh` first; `tool/check_all.sh` runs it.
void main() {
  final root = Directory('../content_core/assets/generated/diagnostic-demo');
  if (!root.existsSync()) {
    throw StateError(
      'The diagnostic pack is missing. Run '
      '`bash tool/build_diagnostic_pack.sh` from the repository root first.',
    );
  }
  final files = <String, String>{
    for (final entity in root.listSync(recursive: true))
      if (entity is File && entity.path.endsWith('.json'))
        entity.path.substring(root.path.length + 1).replaceAll(r'\', '/'):
            jsonEncode(jsonDecode(entity.readAsStringSync())),
  };
  final result = loadPack(files);
  final pack = result.pack!;
  final core = loadPack(provisionalPackFiles()).pack!;

  test('loads with no errors', () {
    expect(result.errors, isEmpty);
  });

  test('is not presented as D\'s official content', () {
    expect(pack.ref.id, 'diagnostic-demo');
    expect(pack.manifest!.publisher, isNot('bard-official'));
    expect(pack.manifest!.tier, isNot(PackTier.core));
    expect(pack.manifest!.name, contains('PLACEHOLDER'));
  });

  test('adds NPCs and nothing else to the rules', () {
    expect(pack.skills, core.skills);
    expect(pack.attributes, core.attributes);
    expect(pack.derived, core.derived);
    expect(pack.difficultyCategories, core.difficultyCategories);
    expect(pack.conditions, core.conditions);
    expect(pack.sanityEvents, core.sanityEvents);
    expect(pack.damageCategories, core.damageCategories);
    expect(pack.humanThreats, core.humanThreats);
    expect(pack.items, core.items);
    expect(pack.npcs.length, core.npcs.length + 3);
  });

  test('every added name and line is marked PLACEHOLDER', () {
    final coreNpcs = core.npcs.map((n) => n.id).toSet();
    final added = pack.npcs.where((n) => !coreNpcs.contains(n.id));
    expect(added, hasLength(3));
    for (final npc in added) {
      expect(npc.name, startsWith('PLACEHOLDER'), reason: npc.id);
      expect(npc.description, startsWith('PLACEHOLDER'), reason: npc.id);
      expect(npc.attributes, isNull, reason: 'no invented stats: ${npc.id}');
    }
    final coreStrings = core.strings['en']!.entries;
    final added0 = pack.strings['en']!.entries.entries.where(
      (e) => !coreStrings.containsKey(e.key),
    );
    expect(added0, isNotEmpty);
    for (final MapEntry(:key, :value) in added0) {
      expect(key, startsWith('demo.'));
      expect(value, contains('PLACEHOLDER'), reason: key);
    }
  });

  test('the scripted beats use skills, difficulties and rows that exist', () {
    for (final skill in ['persuasion', 'research', 'stealth', 'insight']) {
      expect(pack.skill(skill), isNotNull, reason: skill);
    }
    for (final category in ['D', 'C']) {
      expect(pack.difficultyCategory(category), isNotNull, reason: category);
    }
    for (final condition in ['bleeding', 'stunned']) {
      expect(pack.condition(condition), isNotNull, reason: condition);
    }
    final entity = pack.sanityEvents.singleWhere(
      (e) => e.key == 'minor_supernatural_entity',
    );
    expect([entity.min, entity.max], [2, 3]);
  });
}
