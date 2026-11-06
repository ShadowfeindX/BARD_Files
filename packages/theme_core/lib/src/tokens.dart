/// One entry of the token registry (07-apps.md, Tokens and Token sets).
class ThemeToken {
  /// Creates a registry entry.
  const ThemeToken(
    this.name,
    this.group, {
    this.tokenSet = 1,
    this.alphaCapable = false,
  });

  /// The key used in theme files.
  final String name;

  /// Display group, for editors.
  final String group;

  /// The token set that introduced this token.
  final int tokenSet;

  /// Whether `#RRGGBBAA` is accepted. Only overlay-style tokens are.
  final bool alphaCapable;
}

/// The token set this build writes and fully understands.
const int currentTokenSet = 1;

/// Oldest `schemaVersion` this build reads, and the newest.
const int currentSchemaVersion = 1;

/// App version in which each token set first shipped, for the "added in
/// version X" notice. Empty until a release ships; the notice then names the
/// token set instead.
const Map<int, String> tokenSetShippedIn = {};

/// Every token of every set, in display order. Token set 1 has 42.
const List<ThemeToken> themeTokens = [
  ThemeToken('desk', 'Surfaces'),
  ThemeToken('window', 'Surfaces'),
  ThemeToken('windowRaised', 'Surfaces'),
  ThemeToken('labelCell', 'Surfaces'),
  ThemeToken('rule', 'Lines and text'),
  ThemeToken('windowEdge', 'Lines and text'),
  ThemeToken('ink', 'Lines and text'),
  ThemeToken('inkMuted', 'Lines and text'),
  ThemeToken('signal', 'Interaction'),
  ThemeToken('signalFill', 'Interaction'),
  ThemeToken('onSignalFill', 'Interaction'),
  ThemeToken('paper', 'Documents'),
  ThemeToken('paperInk', 'Documents'),
  ThemeToken('paperAlert', 'Documents'),
  ThemeToken('paperInkMuted', 'Documents'),
  ThemeToken('paperRule', 'Documents'),
  ThemeToken('paperStamp', 'Documents'),
  ThemeToken('paperRedact', 'Documents'),
  ThemeToken('redact', 'Redaction'),
  ThemeToken('lineOk', 'Status'),
  ThemeToken('lineDown', 'Status'),
  ThemeToken('markLow', 'Status'),
  ThemeToken('markMid', 'Status'),
  ThemeToken('markHigh', 'Status'),
  ThemeToken('supervisor', 'Functional hues'),
  ThemeToken('anomaly', 'Functional hues'),
  ThemeToken('success', 'Chips'),
  ThemeToken('onSuccess', 'Chips'),
  ThemeToken('partial', 'Chips'),
  ThemeToken('onPartial', 'Chips'),
  ThemeToken('failure', 'Chips'),
  ThemeToken('onFailure', 'Chips'),
  ThemeToken('warning', 'Chips'),
  ThemeToken('onWarning', 'Chips'),
  ThemeToken('locked', 'Chips'),
  ThemeToken('onLocked', 'Chips'),
  ThemeToken('confirm', 'Chips'),
  ThemeToken('onConfirm', 'Chips'),
  ThemeToken('highlight', 'Effects', alphaCapable: true),
  ThemeToken('hostileTakeover', 'Effects'),
  ThemeToken('onHostileTakeover', 'Effects'),
  ThemeToken('sceneTint', 'Effects', alphaCapable: true),
];

final Map<String, ThemeToken> _byName = {
  for (final token in themeTokens) token.name: token,
};

/// The registry entry named [name], or null when this build does not know it.
ThemeToken? tokenNamed(String name) => _byName[name];

/// Names of the tokens a full theme made for [tokenSet] must contain.
List<String> tokenNamesOfSet(int tokenSet) => [
  for (final token in themeTokens)
    if (token.tokenSet <= tokenSet) token.name,
];

/// The text an "added in version" notice uses for [tokenSet].
String tokenSetVersionLabel(int tokenSet) =>
    tokenSetShippedIn[tokenSet] ?? 'token set $tokenSet';
