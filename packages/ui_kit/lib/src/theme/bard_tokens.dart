import 'package:flutter/material.dart';
import 'package:theme_core/theme_core.dart';

/// The resolved theme tokens as Flutter colours, carried by [ThemeData] so
/// widgets read `BardTokens.of(context)` and never a hard-coded colour
/// (07-apps.md, Resolving a theme: widgets only ever see the resolved map).
@immutable
class BardTokens extends ThemeExtension<BardTokens> {
  /// Wraps [resolved].
  const BardTokens(this.resolved);

  /// The tokens of the current theme and variant.
  final ResolvedTheme resolved;

  /// The tokens in force for [context].
  ///
  /// Throws a [StateError] when the context is not under a theme built by
  /// [buildBardThemeData].
  static BardTokens of(BuildContext context) {
    final tokens = Theme.of(context).extension<BardTokens>();
    if (tokens == null) {
      throw StateError('No BardTokens in the theme; use buildBardThemeData.');
    }
    return tokens;
  }

  /// The colour of the token [name] (a name from `themeTokens`).
  Color color(String name) => toFlutterColor(resolved.tokens[name]!);

  /// Whether the high-contrast variant is in force (2 px chip outlines).
  bool get highContrast => resolved.variant == ThemeVariant.highContrast;

  /// Outline width of result chips (07-apps.md, Chips).
  double get chipOutline => highContrast ? 2 : 1;

  /// Application background.
  Color get desk => color('desk');

  /// Window body.
  Color get window => color('window');

  /// Window title bar.
  Color get windowRaised => color('windowRaised');

  /// Label cells of label/value tables.
  Color get labelCell => color('labelCell');

  /// Divider and table rules.
  Color get rule => color('rule');

  /// The 1 px outer border of every window.
  Color get windowEdge => color('windowEdge');

  /// Main text.
  Color get ink => color('ink');

  /// Secondary text.
  Color get inkMuted => color('inkMuted');

  /// Interactive text and glyphs.
  Color get signal => color('signal');

  /// Fill of selected and primary controls.
  Color get signalFill => color('signalFill');

  /// Text on [signalFill].
  Color get onSignalFill => color('onSignalFill');

  /// Paper documents.
  Color get paper => color('paper');

  /// Text on paper.
  Color get paperInk => color('paperInk');

  /// Alert text on paper.
  Color get paperAlert => color('paperAlert');

  /// Margin text on paper.
  Color get paperInkMuted => color('paperInkMuted');

  /// Rules on paper.
  Color get paperRule => color('paperRule');

  /// Handler-set labels and the Handler console accent.
  Color get supervisor => color('supervisor');

  /// Anomaly accent.
  Color get anomaly => color('anomaly');

  /// Fill of the chip for [kind] and the text colour on it.
  (Color fill, Color on) chip(ChipKind kind) => switch (kind) {
    ChipKind.success => (color('success'), color('onSuccess')),
    ChipKind.partial => (color('partial'), color('onPartial')),
    ChipKind.failure => (color('failure'), color('onFailure')),
    ChipKind.warning => (color('warning'), color('onWarning')),
    ChipKind.locked => (color('locked'), color('onLocked')),
    ChipKind.confirm => (color('confirm'), color('onConfirm')),
  };

  @override
  BardTokens copyWith({ResolvedTheme? resolved}) =>
      BardTokens(resolved ?? this.resolved);

  /// A theme switch is instant; there is nothing to interpolate.
  @override
  BardTokens lerp(ThemeExtension<BardTokens>? other, double t) =>
      other is BardTokens && t >= 0.5 ? other : this;
}

/// The state chips of 07-apps.md (Chips). Each has a token pair, a glyph and
/// a word.
enum ChipKind {
  /// A check succeeded.
  success,

  /// A check partly succeeded.
  partial,

  /// A check failed.
  failure,

  /// A caution.
  warning,

  /// Something is locked.
  locked,

  /// A confirming action.
  confirm,
}

/// A theme colour as a Flutter [Color]; alpha is kept when the token has it.
Color toFlutterColor(ThemeColor c) => Color((c.alpha ?? 0xFF) << 24 | c.rgb);
