import 'dart:math' as math;

/// One theme colour: `#RRGGBB`, or `#RRGGBBAA` for alpha-capable tokens.
///
/// Remembers whether alpha was written, so a value is exported in the format
/// it was stored in (07-apps.md, Colour format).
class ThemeColor {
  /// Opaque colour from a 24-bit [rgb] value.
  const ThemeColor.rgb(this.rgb) : alpha = null;

  /// Colour with an explicit [alpha] byte (0 to 255).
  const ThemeColor.rgba(this.rgb, int this.alpha);

  /// Parses `#RRGGBB` or `#RRGGBBAA` (any case); null for anything else.
  static ThemeColor? tryParse(String text) {
    final match = _pattern.firstMatch(text);
    if (match == null) return null;
    final digits = match.group(1)!;
    final rgb = int.parse(digits.substring(0, 6), radix: 16);
    if (digits.length == 6) return ThemeColor.rgb(rgb);
    return ThemeColor.rgba(rgb, int.parse(digits.substring(6), radix: 16));
  }

  static final _pattern = RegExp(r'^#([0-9a-fA-F]{6}|[0-9a-fA-F]{8})$');

  /// Red, green and blue as 0xRRGGBB.
  final int rgb;

  /// Alpha byte, or null when the colour was written as `#RRGGBB`.
  final int? alpha;

  /// Whether the colour was written with an alpha byte.
  bool get hasAlpha => alpha != null;

  /// Upper-case hex text in the stored format.
  String toHex() {
    final body = rgb.toRadixString(16).padLeft(6, '0').toUpperCase();
    final a = alpha;
    if (a == null) return '#$body';
    return '#$body${a.toRadixString(16).padLeft(2, '0').toUpperCase()}';
  }

  /// This colour drawn over the opaque [surface] (alpha 255 when unset).
  ThemeColor compositeOver(ThemeColor surface) {
    final a = (alpha ?? 255) / 255;
    int mix(int shift) {
      final top = (rgb >> shift) & 0xFF;
      final below = (surface.rgb >> shift) & 0xFF;
      return (top * a + below * (1 - a)).round();
    }

    return ThemeColor.rgb((mix(16) << 16) | (mix(8) << 8) | mix(0));
  }

  /// WCAG 2.x relative luminance of the colour (alpha ignored).
  double get relativeLuminance {
    double channel(int shift) {
      final c = ((rgb >> shift) & 0xFF) / 255;
      return c <= 0.03928
          ? c / 12.92
          : math.pow((c + 0.055) / 1.055, 2.4) * 1.0;
    }

    return 0.2126 * channel(16) + 0.7152 * channel(8) + 0.0722 * channel(0);
  }

  /// WCAG 2.x contrast ratio between this colour and [other], both taken as
  /// opaque. Composite an alpha colour first with [compositeOver].
  double contrastWith(ThemeColor other) {
    final a = relativeLuminance;
    final b = other.relativeLuminance;
    final lighter = math.max(a, b);
    final darker = math.min(a, b);
    return (lighter + 0.05) / (darker + 0.05);
  }

  @override
  bool operator ==(Object other) =>
      other is ThemeColor && other.rgb == rgb && other.alpha == alpha;

  @override
  int get hashCode => Object.hash(rgb, alpha);

  @override
  String toString() => toHex();
}
