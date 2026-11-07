import 'resolver.dart';
import 'theme_document.dart';

/// Why a theme cannot take a given base (07-apps.md, Chain checks).
enum BaseProblem {
  /// No theme with that id is installed.
  notInstalled,

  /// The base is a custom theme that itself has a custom base, which would
  /// make a chain longer than two links.
  notEligible,

  /// The theme has dependants, so it may take only a built-in base or none.
  dependantsNeedBuiltIn,

  /// The theme would be its own base.
  loop,
}

/// What importing a derived theme file does about its base.
enum ImportBaseOutcome {
  /// The file is a full theme; it has no base.
  noBase,

  /// The base is installed and eligible.
  ok,

  /// The base is not installed and no theme already derives from the file's
  /// id. The theme is imported and flagged, and Flatten is offered.
  baseNotInstalled,

  /// The base is installed but not eligible, the file names itself as base,
  /// or themes already derive from the file's id and the base is not a
  /// built-in. Offer Flatten; if the player declines, the file is not
  /// imported.
  offerFlatten,
}

/// Why an import's Replace is refused.
enum ReplaceRefusal {
  /// The incoming base is installed but not eligible.
  baseNotEligible,

  /// The theme being replaced has dependants, so the incoming base must be a
  /// built-in or absent.
  dependantsNeedBuiltIn,

  /// The incoming theme names itself as base.
  loop,
}

/// The eligible-base rule (R, T15): only a built-in, a theme whose base is a
/// built-in, or a theme with no base can be a base. A chain is therefore at
/// most two links long. A theme that has dependants takes only a built-in
/// base or none.
///
/// The cycle check and the depth limit of [ThemeResolver] remain as guards
/// against corrupt data.
extension ThemeBaseRules on ThemeResolver {
  /// Whether the theme with [id] may be used as a base.
  bool isEligibleBase(String id) {
    final doc = lookup(id);
    if (doc == null) return false;
    if (isBuiltIn(id)) return true;
    final base = doc.base;
    return base == null || isBuiltIn(base.id);
  }

  /// The installed custom themes whose base is [id].
  List<ThemeDocument> dependantsOf(String id) => [
    for (final doc in customThemes)
      if (doc.base?.id == id) doc,
  ];

  /// The problem with giving [themeId] the base [baseId], or null when it is
  /// fine. A null [baseId] (no base) is always fine.
  BaseProblem? baseProblem(String themeId, String? baseId) {
    if (baseId == null) return null;
    if (baseId == themeId) return BaseProblem.loop;
    // Dependants come first so a base that is not installed is refused too
    // for a theme that others derive from.
    if (!isBuiltIn(baseId) && dependantsOf(themeId).isNotEmpty) {
      return BaseProblem.dependantsNeedBuiltIn;
    }
    if (lookup(baseId) == null) return BaseProblem.notInstalled;
    if (!isEligibleBase(baseId)) return BaseProblem.notEligible;
    return null;
  }

  /// The themes the editor offers as a base for [themeId]: built-ins first,
  /// then custom themes, in the order installed.
  List<ThemeDocument> eligibleBasesFor(String themeId) {
    final all = [
      for (final id in BuiltInIds.all)
        if (lookup(id) != null) lookup(id)!,
      ...customThemes,
    ];
    return [
      for (final doc in all)
        if (doc.id != themeId && baseProblem(themeId, doc.id) == null) doc,
    ];
  }

  /// What importing [incoming] does about its base, checked against the
  /// installed themes. A theme that names itself as base, or whose id already
  /// has dependants and whose base is not a built-in, is offered Flatten like
  /// an ineligible base. A built-in id must be given a new id first, and after
  /// Keep both the caller checks again with the new id.
  ImportBaseOutcome importBaseOutcome(ThemeDocument incoming) {
    final base = incoming.base;
    if (base == null) return ImportBaseOutcome.noBase;
    // A theme that names itself as base is a loop; only Flatten can keep it.
    if (base.id == incoming.id) return ImportBaseOutcome.offerFlatten;
    // Themes already derive from this id (for example after "Delete anyway"
    // left them orphaned): a custom base would make their chain too long.
    if (!isBuiltIn(base.id) && dependantsOf(incoming.id).isNotEmpty) {
      return ImportBaseOutcome.offerFlatten;
    }
    if (lookup(base.id) == null) return ImportBaseOutcome.baseNotInstalled;
    return isEligibleBase(base.id)
        ? ImportBaseOutcome.ok
        : ImportBaseOutcome.offerFlatten;
  }

  /// [incoming] written as a full theme with its resolved values, for the
  /// Flatten offer on an import. [incoming] must not use a built-in id.
  ThemeDocument flattenImport(ThemeDocument incoming) =>
      withTheme(incoming).flatten(incoming.id);

  /// Why replacing the installed custom theme that has [incoming]'s id with
  /// [incoming] must be refused, or null when it may go ahead. A base that is
  /// not installed does not refuse it unless the theme has dependants; it is
  /// flagged afterwards. Throws [ArgumentError] for a built-in id.
  ReplaceRefusal? checkReplace(ThemeDocument incoming) {
    if (isBuiltIn(incoming.id)) {
      throw ArgumentError.value(
        incoming.id,
        'incoming',
        'a built-in is never replaced',
      );
    }
    final base = incoming.base;
    if (base == null) return null;
    final problem = baseProblem(incoming.id, base.id);
    return switch (problem) {
      BaseProblem.loop => ReplaceRefusal.loop,
      BaseProblem.notEligible => ReplaceRefusal.baseNotEligible,
      BaseProblem.dependantsNeedBuiltIn => ReplaceRefusal.dependantsNeedBuiltIn,
      BaseProblem.notInstalled || null => null,
    };
  }

  /// The dependants of [id] written as full themes with their current look,
  /// for "Flatten them first" before the base [id] is deleted. Saving them
  /// and then deleting [id] leaves every resolved map unchanged.
  List<ThemeDocument> flattenedDependants(String id) => [
    for (final doc in dependantsOf(id)) flatten(doc.id),
  ];
}
