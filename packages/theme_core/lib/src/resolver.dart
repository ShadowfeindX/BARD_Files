import 'colour.dart';
import 'limits.dart';
import 'theme_document.dart';
import 'tokens.dart';
import 'variant.dart';

/// Where one resolved value came from.
enum TokenSource {
  /// The theme's own value.
  own,

  /// A base theme in the chain supplied it.
  inherited,

  /// Filled from the fallback built-in (07-apps.md, Value lookup, steps 3-4).
  fallback,
}

/// A complete token map for one theme and variant, plus what the resolver
/// found out on the way. Widgets only ever see [tokens].
class ResolvedTheme {
  /// Creates a resolved theme.
  const ResolvedTheme({
    required this.themeId,
    required this.variant,
    required this.tokens,
    required this.sources,
    required this.fallbackId,
    required this.availableVariants,
    this.missingBaseId,
    this.loop = false,
    this.depthExceeded = false,
  });

  /// The theme that was resolved.
  final String themeId;

  /// The variant that was looked up.
  final ThemeVariant variant;

  /// All tokens of the current token set; never partial.
  final Map<String, ThemeColor> tokens;

  /// Source of each value in [tokens].
  final Map<String, TokenSource> sources;

  /// The fallback built-in used for steps 3 and 4.
  final String fallbackId;

  /// Variants the theme can fully produce after fallback.
  final Set<ThemeVariant> availableVariants;

  /// Id of a base that is not installed, or null.
  final String? missingBaseId;

  /// Whether the theme is on, or leads into, a loop of bases.
  final bool loop;

  /// Whether the chain was longer than the depth safeguard.
  final bool depthExceeded;

  /// Whether the chain was cut short, so fallback values stand in for a base.
  bool get chainBroken => missingBaseId != null || loop || depthExceeded;

  /// Tokens no theme in an intact chain supplied, so the fallback filled
  /// them: the theme is outdated for them (T4). Empty when the chain is
  /// broken, which has its own notice.
  List<String> get outdatedTokens => chainBroken
      ? const []
      : [
          for (final e in sources.entries)
            if (e.value == TokenSource.fallback) e.key,
        ];

  /// Text parts for the "lacks colours added in version X" notice: the
  /// distinct token-set labels of [outdatedTokens].
  List<String> get outdatedSince => {
    for (final name in outdatedTokens)
      tokenSetVersionLabel(tokenNamed(name)!.tokenSet),
  }.toList();
}

/// Turns (theme, variant) into a complete token map: own value, base chain,
/// fallback built-in's variant, fallback built-in's `normal`
/// (07-apps.md, Resolving a theme). Documents are looked up by id, built-ins
/// first, so a custom theme can never shadow a built-in.
class ThemeResolver {
  /// Creates a resolver. [builtIns] must contain Manila and Night Desk, the
  /// last-resort fallbacks.
  ThemeResolver({
    required Iterable<ThemeDocument> builtIns,
    Iterable<ThemeDocument> custom = const [],
    this.limits = const ThemeLimits(),
  }) : _builtIns = {for (final d in builtIns) d.id: d},
       _custom = {for (final d in custom) d.id: d} {
    assert(
      _builtIns.containsKey(BuiltInIds.manila) &&
          _builtIns.containsKey(BuiltInIds.nightDesk),
      'Manila and Night Desk must be built-ins',
    );
    _loopMembers = _findLoopMembers();
  }

  /// Safeguards applied while following chains.
  final ThemeLimits limits;

  final Map<String, ThemeDocument> _builtIns;
  final Map<String, ThemeDocument> _custom;
  late final Set<String> _loopMembers;

  /// The document with [id], or null.
  ThemeDocument? lookup(String id) => _builtIns[id] ?? _custom[id];

  /// Whether [id] names a built-in.
  bool isBuiltIn(String id) => _builtIns.containsKey(id);

  /// The installed custom themes.
  Iterable<ThemeDocument> get customThemes => _custom.values;

  /// A resolver like this one with [doc] installed as a custom theme,
  /// replacing the custom theme with the same id. Throws [ArgumentError] for
  /// a built-in id: a built-in is never replaced.
  ThemeResolver withTheme(ThemeDocument doc) {
    if (isBuiltIn(doc.id)) {
      throw ArgumentError.value(doc.id, 'doc', 'a built-in is never replaced');
    }
    return ThemeResolver(
      builtIns: _builtIns.values,
      custom: [
        for (final d in _custom.values)
          if (d.id != doc.id) d,
        doc,
      ],
      limits: limits,
    );
  }

  /// Ids of themes that sit on a loop of bases.
  Set<String> get loopMembers => _loopMembers;

  /// Whether pointing [themeId] at [baseId] would create a loop. A guard
  /// against corrupt data: the eligible-base rule (`base_rules.dart`) already
  /// rules loops out, so use `baseProblem` for the editor and for imports.
  bool wouldCreateLoop(String themeId, String baseId) {
    final seen = <String>{};
    String? current = baseId;
    while (current != null && seen.add(current)) {
      if (current == themeId) return true;
      current = lookup(current)?.base?.id;
    }
    return false;
  }

  Set<String> _findLoopMembers() {
    final members = <String>{};
    for (final start in {..._builtIns.keys, ..._custom.keys}) {
      final path = <String>[];
      String? current = start;
      while (current != null && !path.contains(current)) {
        path.add(current);
        current = lookup(current)?.base?.id;
      }
      if (current != null) {
        members.addAll(path.sublist(path.indexOf(current)));
      }
    }
    return members;
  }

  /// The chain from [id] up through its bases. The last entry is where the
  /// walk stopped; [_Chain] says why.
  _Chain _chain(String id) {
    final docs = <ThemeDocument>[];
    String? current = id;
    String? missing;
    var loop = false;
    while (current != null) {
      final doc = lookup(current);
      if (doc == null) {
        missing = current;
        break;
      }
      docs.add(doc);
      if (_loopMembers.contains(doc.id)) {
        loop = true; // a loop member resolves as if its base were missing
        break;
      }
      current = doc.base?.id;
      if (docs.length > limits.maxChainDepth + 1) {
        return _Chain([lookup(id)!], null, false, true);
      }
    }
    // A chain whose first document is itself missing is the caller's issue.
    return _Chain(docs, docs.isEmpty ? null : missing, loop, false);
  }

  /// The fallback built-in for [id] (07-apps.md, Fallback built-in).
  ThemeDocument fallbackFor(String id) {
    return _fallbackByLinks(id, <String>{}) ?? _byBrightness(id);
  }

  ThemeDocument _byBrightness(String id) {
    final brightness = lookup(id)?.brightness ?? ThemeBrightness.dark;
    return _builtIns[brightness == ThemeBrightness.dark
        ? BuiltInIds.nightDesk
        : BuiltInIds.manila]!;
  }

  ThemeDocument? _fallbackByLinks(String id, Set<String> seen) {
    if (!seen.add(id)) return null;
    final doc = lookup(id);
    if (doc == null) return null;
    if (isBuiltIn(id)) return doc;
    final chain = _chain(id);
    final root = chain.docs.last;
    if (isBuiltIn(root.id)) return root;
    if (!root.isDerived && root.copiedFrom != null) {
      return _fallbackByLinks(root.copiedFrom!, seen);
    }
    return null;
  }

  /// The variants [id] can fully produce after fallback. For a theme with a
  /// broken chain this adds the fallback built-in's variants.
  Set<ThemeVariant> availableVariants(String id) {
    final chain = _chain(id);
    final out = <ThemeVariant>{
      for (final doc in chain.docs) ...doc.ownVariants,
    };
    if (chain.broken || chain.docs.isEmpty) {
      out.addAll(fallbackFor(id).ownVariants);
    }
    return out;
  }

  /// Resolves [id] for [variant]. Throws [ArgumentError] if [id] is unknown.
  ResolvedTheme resolve(String id, ThemeVariant variant) {
    if (lookup(id) == null) {
      throw ArgumentError.value(id, 'id', 'unknown theme');
    }
    final chain = _chain(id);
    final fallback = fallbackFor(id);
    final tokens = <String, ThemeColor>{};
    final sources = <String, TokenSource>{};
    for (final token in themeTokens) {
      final name = token.name;
      ThemeColor? value;
      var source = TokenSource.own;
      for (var i = 0; i < chain.docs.length && value == null; i++) {
        value = chain.docs[i].mapFor(variant)?[name];
        source = i == 0 ? TokenSource.own : TokenSource.inherited;
      }
      if (value == null) {
        source = TokenSource.fallback;
        value =
            fallback.mapFor(variant)?[name] ??
            fallback.mapFor(ThemeVariant.normal)![name];
      }
      tokens[name] = value!;
      sources[name] = source;
    }
    return ResolvedTheme(
      themeId: id,
      variant: variant,
      tokens: Map.unmodifiable(tokens),
      sources: Map.unmodifiable(sources),
      fallbackId: fallback.id,
      availableVariants: availableVariants(id),
      missingBaseId: chain.missingBaseId,
      loop: chain.loop,
      depthExceeded: chain.depthExceeded,
    );
  }

  /// Writes [id] as a full, stand-alone theme: every variant it can produce,
  /// all tokens resolved, no `base`, the build's token set. A derived theme
  /// keeps its fallback by recording it as `copiedFrom`. Export uses this by
  /// default.
  ThemeDocument flatten(String id) {
    final doc = lookup(id);
    if (doc == null) throw ArgumentError.value(id, 'id', 'unknown theme');
    return ThemeDocument.full(
      id: doc.id,
      name: doc.name,
      brightness: doc.brightness,
      tokenSet: currentTokenSet,
      variants: {
        for (final v in ThemeVariant.values)
          if (availableVariants(id).contains(v)) v: resolve(id, v).tokens,
      },
      copiedFrom: doc.isDerived ? fallbackFor(id).id : doc.copiedFrom,
    );
  }
}

class _Chain {
  _Chain(this.docs, this.missingBaseId, this.loop, this.depthExceeded);

  final List<ThemeDocument> docs;
  final String? missingBaseId;
  final bool loop;
  final bool depthExceeded;

  bool get broken => missingBaseId != null || loop || depthExceeded;
}
