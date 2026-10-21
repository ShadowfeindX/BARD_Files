import 'dart:convert';

import '../../equality.dart';
import '../../expr/expr.dart';
import '../../version.dart';
import '../files/advancement.dart';
import '../files/attributes.dart';
import '../files/conditions.dart';
import '../files/damage.dart';
import '../files/derived.dart';
import '../files/difficulty.dart';
import '../files/disorders.dart';
import '../files/items.dart';
import '../files/manifest.dart';
import '../files/npcs.dart';
import '../files/proficiency.dart';
import '../files/ranges.dart';
import '../files/sanity_events.dart';
import '../files/skills.dart';
import '../files/strings.dart';
import '../files/techniques.dart';
import '../files/threats.dart';
import '../files/vehicles.dart';
import '../rules_pack.dart';
import 'content_hash.dart';
import 'object_reader.dart';
import 'pack_issue.dart';

/// The outcome of [loadPack]: the pack when it is valid, and every issue.
final class PackLoadResult {
  /// Creates a result.
  PackLoadResult(this.pack, List<PackIssue> issues)
    : issues = List.unmodifiable(issues);

  /// The loaded pack, or `null` when there was any error.
  final RulesPack? pack;

  /// Errors and warnings, in the order found.
  final List<PackIssue> issues;

  /// The errors.
  Iterable<PackIssue> get errors => issues.where((i) => i.isError);

  /// The warnings.
  Iterable<PackIssue> get warnings => issues.where((i) => !i.isError);

  /// Whether the pack loaded.
  bool get ok => pack != null;

  @override
  bool operator ==(Object other) =>
      other is PackLoadResult &&
      other.pack == pack &&
      listEquals(other.issues, issues);

  @override
  int get hashCode => Object.hash(pack, Object.hashAll(issues));
}

/// Files a standalone pack must have, so the engine core can run on it.
const requiredPackFiles = [
  'manifest.json',
  'attributes.json',
  'proficiency.json',
  'skills.json',
  'derived.json',
  'difficulty.json',
];

/// Top-level files a pack may have, besides the folders in [packFolders].
const packFiles = {
  ...requiredPackFiles,
  'conditions.json',
  'disorders.json',
  'sanity_events.json',
  'damage.json',
  'vehicles.json',
  'ranges.json',
  'occult.json',
  'advancement.json',
  'threats.json',
};

/// Folders of a pack that hold one entry per `.json` file.
const packFolders = {'items', 'techniques', 'npcs', 'strings'};

/// Loads and validates a pack (02 §Loading and validation).
///
/// [files] maps each pack-relative path (`skills.json`, `items/pistol.json`)
/// to the file's text. The pack must already be stripped of authoring
/// annotations, since unknown keys are errors. Pure: reading the files is
/// the caller's job, so this runs on every platform.
///
/// Steps: read the manifest and check `engineApi`; parse every file with its
/// own parser; check cross-references; compute the content hash. Values that
/// are pending D are warnings, never errors. Every problem is collected, so
/// the author sees them all at once.
PackLoadResult loadPack(Map<String, String> files) {
  final log = IssueLog();
  final decoded = <String, Object?>{};
  for (final MapEntry(key: path, value: text) in files.entries) {
    if (!_isKnownFile(path)) {
      log.error(
        path,
        '',
        'Not a pack file. Expected one of: '
            '${packFiles.join(', ')}, or a .json file in '
            '${packFolders.map((f) => '$f/').join(', ')}.',
      );
      continue;
    }
    try {
      decoded[path] = jsonDecode(text);
    } on FormatException catch (e) {
      log.error(path, '', 'Not valid JSON: ${e.message}');
    }
  }
  for (final required in requiredPackFiles) {
    if (!files.containsKey(required)) {
      log.error(required, '', 'Missing required file.');
    }
  }

  final manifest = _read(log, decoded, 'manifest.json', parseManifest);
  if (manifest != null) _checkManifest(log, manifest);
  final major = manifest == null ? null : semverMajor(manifest.version);

  final parts = _Parts(log, decoded, major);
  final pack = parts.build(manifest);
  if (log.hasErrors || pack == null) return PackLoadResult(null, log.issues);
  _CrossCheck(log, pack).run();
  if (log.hasErrors) return PackLoadResult(null, log.issues);
  return PackLoadResult(pack, log.issues);
}

bool _isKnownFile(String path) {
  if (packFiles.contains(path)) return true;
  final slash = path.indexOf('/');
  return slash > 0 &&
      packFolders.contains(path.substring(0, slash)) &&
      !path.substring(slash + 1).contains('/') &&
      path.endsWith('.json') &&
      path.length > slash + 1 + '.json'.length;
}

T? _read<T>(
  IssueLog log,
  Map<String, Object?> decoded,
  String file,
  T? Function(ObjectReader reader) parse,
) {
  if (!decoded.containsKey(file)) return null;
  final reader = ObjectReader.root(log, file, decoded[file]);
  if (reader == null) return null;
  final result = parse(reader);
  reader.finish();
  return result;
}

void _checkManifest(IssueLog log, PackManifest manifest) {
  if (manifest.engineApi != engineApi) {
    log.error(
      'manifest.json',
      'engineApi',
      'This pack targets engine API ${manifest.engineApi}; this engine is '
          '$engineApi.',
    );
  }
  if (manifest.requires.isNotEmpty) {
    log.error(
      'manifest.json',
      'requires',
      'Packs that build on other packs are not supported yet.',
    );
  }
}

/// Parses every file except the manifest and assembles the pack.
final class _Parts {
  _Parts(this.log, this.decoded, this.major);

  final IssueLog log;
  final Map<String, Object?> decoded;
  final int? major;

  T? read<T>(String file, T? Function(ObjectReader r) parse) =>
      _read(log, decoded, file, parse);

  List<T> folder<T>(String folder, T? Function(ObjectReader r) parse) {
    final paths = decoded.keys.where((p) => p.startsWith('$folder/')).toList()
      ..sort();
    return [
      for (final path in paths)
        if (read(path, parse) case final T entry) entry,
    ];
  }

  RulesPack? build(PackManifest? manifest) {
    final attributes = read(
      'attributes.json',
      (r) => parseAttributes(r, major),
    );
    final proficiency = read(
      'proficiency.json',
      (r) => parseProficiency(r, major),
    );
    final skills = read('skills.json', (r) => parseSkills(r, major));
    final derived = read('derived.json', (r) => parseDerived(r, major));
    final difficulty = read(
      'difficulty.json',
      (r) => parseDifficulty(r, major),
    );
    final conditions = read(
      'conditions.json',
      (r) => parseConditions(r, major),
    );
    final disorders = read('disorders.json', (r) => parseDisorders(r, major));
    final sanity = read(
      'sanity_events.json',
      (r) => parseSanityEvents(r, major),
    );
    final damage = read('damage.json', (r) => parseDamage(r, major));
    final vehicles = read('vehicles.json', (r) => parseVehicles(r, major));
    final ranges = read('ranges.json', (r) => parseRanges(r, major));
    final advancement = read(
      'advancement.json',
      (r) => parseAdvancement(r, major),
    );
    final threats = read('threats.json', (r) => parseThreats(r, major));
    final items = folder('items', (r) => parseItem(r, major));
    final techniques = folder('techniques', (r) => parseTechnique(r, major));
    final npcs = folder('npcs', (r) => parseNpc(r, major));
    final strings = folder('strings', parseStrings);
    final occult = decoded['occult.json'];
    if (decoded.containsKey('occult.json')) {
      // The occult system is pending D as a whole (C5/G6, F3 part 1): the file
      // is carried along unvalidated and nothing reads it.
      log.pendingD('occult.json', '');
    }

    final creation = attributes?.creation;
    if (manifest == null ||
        attributes == null ||
        creation == null ||
        proficiency == null ||
        skills == null ||
        derived == null ||
        difficulty == null) {
      return null;
    }
    return RulesPack(
      ref: PackRef(
        id: manifest.id,
        version: manifest.version,
        contentHash: computeContentHash(decoded),
      ),
      manifest: manifest,
      attributes: attributes.attributes,
      attributeCreation: creation,
      advancementCap: attributes.advancementCap,
      proficiencyTiers: proficiency.tiers,
      proficiencyCreation: proficiency.creation,
      skillCategories: skills.categories,
      skills: skills.skills,
      derived: derived,
      difficultyCategories: difficulty.categories,
      checkRules: difficulty.checkRules,
      conditions: conditions ?? const [],
      disorders: disorders,
      sanityEvents: sanity ?? const [],
      damageCategories: damage ?? const [],
      vehiclePerformance: vehicles?.performance ?? const [],
      vehicleDurability: vehicles?.durability ?? const [],
      rangeBands: ranges ?? const [],
      advancementCosts: advancement ?? const [],
      humanThreats: threats?.human ?? const [],
      supernaturalThreats: threats?.supernatural ?? const [],
      items: items,
      techniques: techniques,
      npcs: npcs,
      strings: {for (final s in strings) s.language: s},
      occultPending: occult,
      pendingPaths: {
        for (final issue in log.issues)
          if (issue.pendingD)
            issue.path.isEmpty ? issue.file : '${issue.file}: ${issue.path}',
      },
    );
  }
}

/// Cross-file and cross-entry checks on a parsed pack (02 §Loading and
/// validation, step 4).
final class _CrossCheck {
  _CrossCheck(this.log, this.pack);

  final IssueLog log;
  final RulesPack pack;

  late final attributeKeys = {for (final a in pack.attributes) a.key};
  late final damageKeys = {for (final d in pack.damageCategories) d.key};

  void run() {
    _contentHash();
    _unique('attributes.json', 'attributes', pack.attributes.map((a) => a.key));
    _unique(
      'proficiency.json',
      'tiers',
      pack.proficiencyTiers.map((t) => t.key),
    );
    _unique(
      'skills.json',
      'categories',
      pack.skillCategories.map((c) => c.key),
    );
    _unique('skills.json', 'skills', pack.skills.map((s) => s.id));
    _unique('derived.json', 'derived', pack.derived.map((d) => d.key));
    _unique(
      'difficulty.json',
      'categories',
      pack.difficultyCategories.map((c) => c.key),
    );
    _unique('conditions.json', 'conditions', pack.conditions.map((c) => c.id));
    _unique(
      'sanity_events.json',
      'events',
      pack.sanityEvents.map((e) => e.key),
    );
    _unique(
      'damage.json',
      'categories',
      pack.damageCategories.map((d) => d.key),
    );
    _unique('ranges.json', 'bands', pack.rangeBands.map((b) => b.key));
    _unique(
      'advancement.json',
      'costs',
      pack.advancementCosts.map((c) => c.key),
    );
    _unique('items/', 'id', pack.items.map((i) => i.id));
    _unique('techniques/', 'id', pack.techniques.map((t) => t.id));
    _unique('npcs/', 'id', pack.npcs.map((n) => n.id));
    _attributes();
    _proficiency();
    _skills();
    _formulas();
    _checkRules();
    _disorders();
    _damageRefs();
    _npcs();
    _replacements();
  }

  void _contentHash() {
    final written = pack.manifest?.contentHash;
    if (written != null && written != pack.ref.contentHash) {
      log.error(
        'manifest.json',
        'contentHash',
        'Does not match the content (computed ${pack.ref.contentHash}).',
      );
    }
  }

  void _unique(String file, String list, Iterable<String> keys) {
    final seen = <String>{};
    for (final key in keys) {
      if (!seen.add(key)) log.error(file, list, 'Duplicate key "$key".');
    }
  }

  void _attributes() {
    final creation = pack.attributeCreation;
    final cap = pack.advancementCap;
    if (cap != null && cap < creation.maxPerAttribute) {
      log.error(
        'attributes.json',
        'advancementCap',
        'Is below the creation maximum (${creation.maxPerAttribute}).',
      );
    }
    if (pack.strings.isEmpty) return;
    for (final attribute in pack.attributes) {
      final key = attribute.descriptionKey;
      if (key == null) continue;
      for (final strings in pack.strings.values) {
        if (!strings.entries.containsKey(key)) {
          log.warning(
            'strings/${strings.language}.json',
            '',
            'No text for "$key" (description of ${attribute.key}).',
          );
        }
      }
    }
  }

  void _proficiency() {
    final tiers = {for (final t in pack.proficiencyTiers) t.key};
    for (final key in pack.proficiencyCreation?.counts.keys ?? <String>[]) {
      if (!tiers.contains(key)) {
        log.error(
          'proficiency.json',
          'creation.$key',
          'Unknown proficiency tier.',
        );
      }
    }
  }

  void _skills() {
    final categories = {for (final c in pack.skillCategories) c.key};
    for (final skill in pack.skills) {
      final category = skill.category;
      if (category != null && !categories.contains(category)) {
        log.error(
          'skills.json',
          'skills[${skill.id}].category',
          'Unknown skill category "$category".',
        );
      }
      _attribute(
        'skills.json',
        'skills[${skill.id}].attribute',
        skill.attribute,
      );
    }
  }

  void _formulas() {
    void check(String file, String path, Expr? expr) {
      for (final key in expr?.attributeKeys ?? const <String>{}) {
        if (!attributeKeys.contains(key)) {
          log.error(file, path, 'Unknown attribute "$key".');
        }
      }
    }

    for (final d in pack.derived) {
      check('derived.json', 'derived[${d.key}].formula', d.formula);
    }
    for (final t in pack.proficiencyTiers) {
      check('proficiency.json', 'tiers[${t.key}].bonus', t.bonus);
    }
    for (final c in pack.advancementCosts) {
      check('advancement.json', 'costs[${c.key}].xp', c.xp);
      check('advancement.json', 'costs[${c.key}].grants', c.grants);
    }
    final rules = pack.checkRules;
    if (rules != null) {
      check('difficulty.json', 'checkRules.primaryDie', rules.primaryDie);
      check(
        'difficulty.json',
        'checkRules.assistance.bonus',
        rules.assistanceBonus,
      );
    }
  }

  void _checkRules() {
    final rules = pack.checkRules;
    if (rules == null) return;
    _attribute(
      'difficulty.json',
      'checkRules.luckAdvantage.extraPrimaryDiceFrom',
      rules.luckAdvantageAttribute,
    );
    final categories = {for (final c in pack.difficultyCategories) c.key};
    if (!categories.contains(rules.assistanceGateCategory)) {
      log.error(
        'difficulty.json',
        'checkRules.assistance.gateCategory',
        'Unknown difficulty category "${rules.assistanceGateCategory}".',
      );
    }
  }

  void _disorders() {
    final table = pack.disorders;
    if (table == null) return;
    _attribute(
      'disorders.json',
      'disorderCheck.attribute',
      table.check.attribute,
    );
    _unique('disorders.json', 'table', table.rows.map((r) => '${r.roll}'));
  }

  void _damageRefs() {
    for (final band in pack.rangeBands) {
      for (final key in band.notWithDamageCategories) {
        _damage(
          'ranges.json',
          'bands[${band.key}].notWithDamageCategories',
          key,
        );
      }
    }
    for (final item in pack.items) {
      final key = item.damageCategory;
      if (key != null) _damage('items/${item.id}.json', 'damageCategory', key);
    }
    for (final threat in pack.supernaturalThreats) {
      _damage(
        'threats.json',
        'supernatural[${threat.classKey}].damage.category',
        threat.damage.category,
      );
    }
  }

  void _npcs() {
    final classes = {
      for (final h in pack.humanThreats) 'human:${h.classKey}',
      for (final s in pack.supernaturalThreats) 'supernatural:${s.classKey}',
    };
    for (final npc in pack.npcs) {
      if (!classes.contains(npc.threatClass)) {
        log.error(
          'npcs/${npc.id}.json',
          'threatClass',
          'Unknown threat class "${npc.threatClass}".',
        );
      }
      for (final key in npc.attributes?.keys ?? const <String>[]) {
        _attribute('npcs/${npc.id}.json', 'attributes.$key', key);
      }
    }
  }

  /// Each `replacedBy` of the form `kind:id` must name an existing entry.
  void _replacements() {
    final ids = <String, Set<String>>{
      'attribute': attributeKeys,
      'skill': {for (final s in pack.skills) s.id},
      'condition': {for (final c in pack.conditions) c.id},
      'item': {for (final i in pack.items) i.id},
      'technique': {for (final t in pack.techniques) t.id},
      'npc': {for (final n in pack.npcs) n.id},
    };
    void check(String file, String path, String? replacedBy) {
      final colon = replacedBy?.indexOf(':') ?? -1;
      if (replacedBy == null || colon < 0) return;
      final kind = replacedBy.substring(0, colon);
      final id = replacedBy.substring(colon + 1);
      final known = ids[kind];
      if (known == null) {
        log.error(file, path, 'Unknown kind "$kind" in replacedBy.');
      } else if (!known.contains(id)) {
        log.error(file, path, 'replacedBy names a missing $kind "$id".');
      }
    }

    for (final s in pack.skills) {
      check(
        'skills.json',
        'skills[${s.id}].deprecated',
        s.deprecated?.replacedBy,
      );
    }
    for (final a in pack.attributes) {
      check(
        'attributes.json',
        'attributes[${a.key}].deprecated',
        a.deprecated?.replacedBy,
      );
    }
    for (final c in pack.conditions) {
      check(
        'conditions.json',
        'conditions[${c.id}].deprecated',
        c.deprecated?.replacedBy,
      );
    }
    for (final i in pack.items) {
      check('items/${i.id}.json', 'deprecated', i.deprecated?.replacedBy);
    }
    for (final t in pack.techniques) {
      check('techniques/${t.id}.json', 'deprecated', t.deprecated?.replacedBy);
    }
    for (final n in pack.npcs) {
      check('npcs/${n.id}.json', 'deprecated', n.deprecated?.replacedBy);
    }
  }

  void _attribute(String file, String path, String? key) {
    if (key != null && !attributeKeys.contains(key)) {
      log.error(file, path, 'Unknown attribute "$key".');
    }
  }

  void _damage(String file, String path, String key) {
    if (!damageKeys.contains(key)) {
      log.error(file, path, 'Unknown damage category "$key".');
    }
  }
}
