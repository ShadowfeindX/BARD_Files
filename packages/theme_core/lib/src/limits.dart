/// Technical safeguards against corrupt or hostile data. They are not theming
/// limits (R, T3: no limits on player theming). Both values are Proposed and
/// open (T3), so callers can pass other numbers.
class ThemeLimits {
  /// Creates limits; the defaults are the Proposed values.
  const ThemeLimits({this.maxImportBytes = 1048576, this.maxChainDepth = 32});

  /// Largest import file in bytes, checked before parsing.
  final int maxImportBytes;

  /// Longest base chain, in links, the resolver follows. A guard against
  /// corrupt data only: the eligible-base rule keeps real chains to two links.
  final int maxChainDepth;
}
